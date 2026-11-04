import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/recommendation.dart';

DrawResult? parseDraw(String body, int round) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  final list = (data['data'] as Map<String, dynamic>)['list'] as List;
  if (list.isEmpty) return null;
  final row = list.single as Map<String, dynamic>;
  if (row['ltEpsd'] != round) throw const FormatException('회차 불일치');
  return DrawResult(
    round,
    LottoGame([for (var i = 1; i <= 6; i++) row['tm${i}WnNo'] as int]),
    row['bnsWnNo'] as int,
  );
}

DrawResult _decode(Map<String, dynamic> row) => DrawResult(
  row['round'] as int,
  LottoGame((row['numbers'] as List).cast<int>()),
  row['bonus'] as int,
);
String _encode(DrawResult d) =>
    jsonEncode({'round': d.round, 'numbers': d.main.numbers, 'bonus': d.bonus});

List<DrawResult> parseSnapshot(String body) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  if (data['schemaVersion'] != 1) throw const FormatException('지원하지 않는 데이터 형식');
  final draws =
      (data['draws'] as List)
          .map((r) => _decode(r as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.round.compareTo(b.round));
  if (draws.isEmpty || draws.last.round != data['latestRound']) {
    throw const FormatException('마지막 회차 불일치');
  }
  for (var i = 0; i < draws.length; i++) {
    if (draws[i].round != i + 1) throw const FormatException('회차 누락 또는 중복');
  }
  return draws.reversed.toList();
}

class DrawStore {
  DrawStore({
    http.Client? client,
    DateTime Function()? now,
    Future<String> Function()? snapshot,
  }) : _client = client,
       _now = now ?? DateTime.now,
       _snapshot =
           snapshot ?? (() => rootBundle.loadString('assets/draws.json'));
  final http.Client? _client;
  final DateTime Function() _now;
  final Future<String> Function() _snapshot;
  final List<DrawResult> draws = [];
  Future<void>? _loading;
  String status = '추첨 데이터를 확인하고 있습니다.';
  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);
  void _replace(Iterable<DrawResult> values) {
    draws
      ..clear()
      ..addAll(values);
    draws.sort((a, b) => b.round.compareTo(a.round));
  }

  Future<void> _load() async {
    try {
      _replace(parseSnapshot(await _snapshot()));
      final prefs = await SharedPreferences.getInstance();
      final merged = {for (final d in draws) d.round: d};
      try {
        final cached = (prefs.getStringList('draws.v1') ?? [])
            .map((s) => _decode(jsonDecode(s) as Map<String, dynamic>))
            .toList();
        for (final d in cached) {
          merged.putIfAbsent(d.round, () => d);
        }
      } catch (_) {
        /* Recover corrupt cache from the validated bundle. */
      }
      _replace(merged.values);
      if (!await prefs.setStringList('draws.v1', draws.map(_encode).toList())) {
        throw const FormatException('저장 실패');
      }
      final week =
          _now().toUtc().difference(DateTime.utc(2002, 12, 7, 15)).inDays ~/ 7;
      if (prefs.getInt('drawCheckWeek.v1') != week) {
        await prefs.setInt('drawCheckWeek.v1', week);
        final client = _client ?? http.Client();
        try {
          final latestExpected = week + 1;
          for (var round = 1; round <= latestExpected; round++) {
            if (merged.containsKey(round)) continue;
            final response = await client
                .get(
                  Uri.https(
                    'www.dhlottery.co.kr',
                    '/lt645/selectPstLt645Info.do',
                    {'srchDir': 'center', 'srchLtEpsd': '$round'},
                  ),
                )
                .timeout(const Duration(seconds: 15));
            if (response.statusCode != 200) {
              throw const FormatException('조회 실패');
            }
            final draw = parseDraw(response.body, round);
            if (draw == null) break;
            final next = {...merged, round: draw};
            if (!await prefs.setStringList(
              'draws.v1',
              next.values.map(_encode).toList(),
            )) {
              throw const FormatException('저장 실패');
            }
            merged[round] = draw;
            _replace(merged.values);
          }
        } finally {
          if (_client == null) client.close();
        }
      }
      status = '${draws.first.round}회 기준 · ${draws.length}회 저장';
    } catch (_) {
      status = draws.isEmpty
          ? '데이터 조회에 실패했습니다.'
          : '${draws.first.round}회 기준 · 마지막 정상 데이터 사용';
    }
  }
}
