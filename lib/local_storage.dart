import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/recommendation.dart';
import 'preset_store.dart';

/// SQLite-backed compatibility boundary while UI stores retain their contracts.
/// Only UI preferences remain JSON documents; number collections use child rows.
class LocalStorage {
  LocalStorage._(this._db, this._values);
  final Database? _db;
  @visibleForTesting
  static Map<String, dynamic>? testValues;
  final Map<String, dynamic> _values;
  static DatabaseFactory factory = databaseFactory;
  static String? pathOverride;
  static Future<Database>? _opening;
  static const legacyKeys = [
    'presets.v1',
    'library.v1',
    'papers.v1',
    'draws.v1',
    'display.v1',
    'drawCheckWeek.v1',
    'largeViewIntro.v1',
  ];
  static Future<void> reset() async {
    testValues = null;
    final pending = _opening;
    _opening = null;
    if (pending != null) {
      try {
        await (await pending).close();
      } catch (_) {}
    }
  }

  static Future<Database> _open() async {
    final path =
        pathOverride ?? '${await factory.getDatabasesPath()}/easy_lotto.db';
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE presets (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, options TEXT NOT NULL, position INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE favorite_numbers (number INTEGER PRIMARY KEY CHECK(number BETWEEN 1 AND 45))',
          );
          await db.execute(
            'CREATE TABLE number_sets (id TEXT PRIMARY KEY, source TEXT NOT NULL, options TEXT, position INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE number_set_items (set_id TEXT NOT NULL REFERENCES number_sets(id) ON DELETE CASCADE, number INTEGER CHECK(number BETWEEN 1 AND 45), PRIMARY KEY(set_id,number))',
          );
          await db.execute(
            'CREATE TABLE lottery_papers (id TEXT PRIMARY KEY, title TEXT NOT NULL, position INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE lottery_paper_games (id TEXT PRIMARY KEY, paper_id TEXT NOT NULL REFERENCES lottery_papers(id) ON DELETE CASCADE, position INTEGER CHECK(position BETWEEN 0 AND 4), UNIQUE(paper_id,position))',
          );
          await db.execute(
            'CREATE TABLE lottery_paper_game_items (game_id TEXT NOT NULL REFERENCES lottery_paper_games(id) ON DELETE CASCADE, number INTEGER CHECK(number BETWEEN 1 AND 45), PRIMARY KEY(game_id,number))',
          );
          await db.execute(
            'CREATE TABLE draw_results (round INTEGER PRIMARY KEY CHECK(round > 0), bonus INTEGER CHECK(bonus BETWEEN 1 AND 45))',
          );
          await db.execute(
            'CREATE TABLE draw_main_numbers (round INTEGER NOT NULL REFERENCES draw_results(round) ON DELETE CASCADE, number INTEGER CHECK(number BETWEEN 1 AND 45), PRIMARY KEY(round,number))',
          );
        },
      ),
    );
    try {
      if ((await db.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['migration.v1'],
      )).isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final old = {
          for (final key in legacyKeys)
            if (prefs.containsKey(key)) key: prefs.get(key),
        };
        await db.transaction((tx) async {
          for (final entry in old.entries) {
            await _write(tx, entry.key, entry.value);
          }
          await tx.insert('metadata', {'key': 'migration.v1', 'value': 'true'});
        });
      }
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static Future<LocalStorage> getInstance() async {
    if (testValues != null) return LocalStorage._(null, testValues!);
    Database db;
    try {
      db = await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
    final values = await db.transaction((tx) => _read(tx));
    return LocalStorage._(db, values);
  }

  String? getString(String key) => _values[key] as String?;
  List<String>? getStringList(String key) =>
      (_values[key] as List?)?.cast<String>();
  int? getInt(String key) => _values[key] as int?;
  bool? getBool(String key) => _values[key] as bool?;
  Future<bool> _set(String key, Object value) async {
    if (_db != null) await _db.transaction((tx) => _write(tx, key, value));
    _values[key] = value;
    return true;
  }

  Future<bool> setString(String key, String value) => _set(key, value);
  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, value);
  Future<bool> setInt(String key, int value) => _set(key, value);
  Future<bool> setBool(String key, bool value) => _set(key, value);

  static Future<void> _numbers(
    DatabaseExecutor tx,
    String table,
    String column,
    Object id,
    dynamic values,
  ) async {
    final game = LottoGame((values as List).cast<int>());
    for (final n in game.numbers) {
      await tx.insert(table, {column: id, 'number': n});
    }
  }

  static Future<void> _write(
    DatabaseExecutor tx,
    String key,
    dynamic value,
  ) async {
    if (key == 'presets.v1') {
      final j = jsonDecode(value as String) as Map<String, dynamic>;
      await tx.delete('presets');
      var position = 0;
      for (final p in j['items'] as List) {
        decodeOptions(p['options'] as Map<String, dynamic>);
        await tx.insert('presets', {
          'id': p['id'],
          'name': p['name'],
          'options': jsonEncode(p['options']),
          'position': position++,
        });
      }
      await tx.insert('metadata', {
        'key': 'selectedPreset',
        'value': jsonEncode(j['selected']),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (key == 'library.v1') {
      final j = jsonDecode(value as String) as Map<String, dynamic>;
      await tx.delete('favorite_numbers');
      await tx.delete('number_sets');
      for (final n in j['numbers'] as List) {
        await tx.insert('favorite_numbers', {'number': n});
      }
      var position = 0;
      for (final g in j['games'] as List) {
        final game = LottoGame((g['numbers'] as List).cast<int>());
        final id = game.numbers.join('-');
        await tx.insert('number_sets', {
          'id': id,
          'source':
              g['source'] ?? (g['options'] == null ? 'random' : 'configured'),
          'options': g['options'] == null ? null : jsonEncode(g['options']),
          'position': position++,
        });
        await _numbers(tx, 'number_set_items', 'set_id', id, game.numbers);
      }
    } else if (key == 'papers.v1') {
      final papers = jsonDecode(value as String) as List;
      await tx.delete('lottery_papers');
      var position = 0;
      for (final p in papers) {
        final games = p['games'] as List;
        if (games.isEmpty || games.length > 5) {
          throw const FormatException('용지 게임 수 오류');
        }
        await tx.insert('lottery_papers', {
          'id': p['id'],
          'title': p['title'],
          'position': position++,
        });
        for (var i = 0; i < games.length; i++) {
          final id = '${p['id']}:$i';
          await tx.insert('lottery_paper_games', {
            'id': id,
            'paper_id': p['id'],
            'position': i,
          });
          await _numbers(
            tx,
            'lottery_paper_game_items',
            'game_id',
            id,
            games[i],
          );
        }
      }
    } else if (key == 'draws.v1') {
      final rounds = <int>{};
      final existing = {
        for (final r in await tx.query('draw_results'))
          r['round'] as int: r['bonus'] as int,
      };
      final existingNumbers = <int, List<int>>{};
      for (final r in await tx.query('draw_main_numbers', orderBy: 'number')) {
        existingNumbers
            .putIfAbsent(r['round'] as int, () => [])
            .add(r['number'] as int);
      }
      for (final raw in value as List) {
        final j = jsonDecode(raw as String) as Map<String, dynamic>;
        final draw = DrawResult(
          j['round'] as int,
          LottoGame((j['numbers'] as List).cast<int>()),
          j['bonus'] as int,
        );
        if (!rounds.add(draw.round)) throw const FormatException('중복 회차');
        if (existing[draw.round] == draw.bonus &&
            listEquals(existingNumbers[draw.round], draw.main.numbers)) {
          continue;
        }
        await tx.delete(
          'draw_results',
          where: 'round = ?',
          whereArgs: [draw.round],
        );
        await tx.insert('draw_results', {
          'round': draw.round,
          'bonus': draw.bonus,
        });
        await _numbers(
          tx,
          'draw_main_numbers',
          'round',
          draw.round,
          draw.main.numbers,
        );
      }
      for (final round in existing.keys.where((r) => !rounds.contains(r))) {
        await tx.delete('draw_results', where: 'round = ?', whereArgs: [round]);
      }
    } else {
      await tx.insert('metadata', {
        'key': key,
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<Map<String, dynamic>> _read(DatabaseExecutor tx) async {
    final values = {
      for (final r in await tx.query('metadata'))
        r['key'] as String: jsonDecode(r['value'] as String),
    };
    Future<List<int>> numbers(String table, String column, Object id) async => [
      for (final r in await tx.query(
        table,
        where: '$column = ?',
        whereArgs: [id],
        orderBy: 'number',
      ))
        r['number'] as int,
    ];
    final presets = await tx.query('presets', orderBy: 'position');
    values['presets.v1'] = jsonEncode({
      'selected': values['selectedPreset'],
      'items': [
        for (final p in presets)
          {
            'id': p['id'],
            'name': p['name'],
            'options': jsonDecode(p['options'] as String),
          },
      ],
    });
    final games = <Map<String, dynamic>>[];
    for (final g in await tx.query('number_sets', orderBy: 'position')) {
      games.add({
        'numbers': await numbers('number_set_items', 'set_id', g['id']!),
        'source': g['source'],
        'options': g['options'] == null
            ? null
            : jsonDecode(g['options'] as String),
      });
    }
    values['library.v1'] = jsonEncode({
      'numbers': [
        for (final r in await tx.query('favorite_numbers', orderBy: 'number'))
          r['number'],
      ],
      'games': games,
    });
    final papers = <Map<String, dynamic>>[];
    for (final p in await tx.query('lottery_papers', orderBy: 'position')) {
      final games = <List<int>>[];
      for (final g in await tx.query(
        'lottery_paper_games',
        where: 'paper_id = ?',
        whereArgs: [p['id']],
        orderBy: 'position',
      )) {
        games.add(
          await numbers('lottery_paper_game_items', 'game_id', g['id']!),
        );
      }
      papers.add({'id': p['id'], 'title': p['title'], 'games': games});
    }
    values['papers.v1'] = jsonEncode(papers);
    values['draws.v1'] = <String>[];
    final allNumbers = <int, List<int>>{};
    for (final r in await tx.query('draw_main_numbers', orderBy: 'number')) {
      allNumbers
          .putIfAbsent(r['round'] as int, () => [])
          .add(r['number'] as int);
    }
    for (final d in await tx.query('draw_results', orderBy: 'round DESC')) {
      (values['draws.v1'] as List<String>).add(
        jsonEncode({
          'round': d['round'],
          'bonus': d['bonus'],
          'numbers': allNumbers[d['round']],
        }),
      );
    }
    return values;
  }
}
