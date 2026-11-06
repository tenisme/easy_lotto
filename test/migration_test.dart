import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:easy_lotto/domain/recommendation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final library = jsonEncode({
    'numbers': [3],
    'games': [
      {
        'numbers': [1, 2, 3, 4, 5, 6],
        'options': null,
        'source': 'manual',
      },
    ],
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lotto-migration-');
    LocalStorage.pathOverride = '${directory.path}/test.db';
  });
  tearDown(() async {
    await LocalStorage.reset();
    await directory.delete(recursive: true);
    LocalStorage.pathOverride = ':memory:';
  });
  test(
    'migrates every legacy document atomically and does not reimport on restart',
    () async {
      final preset = jsonEncode({
        'selected': 'p',
        'items': [
          {
            'id': 'p',
            'name': '설정1',
            'options': encodeOptions(RecommendationOptions(oddCount: 3)),
          },
        ],
      });
      final papers = jsonEncode([
        {
          'id': 'paper',
          'title': '복권 용지 1',
          'games': [
            [1, 2, 3, 4, 5, 6],
          ],
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'presets.v1': preset,
        'library.v1': library,
        'papers.v1': papers,
        'draws.v1': [
          jsonEncode({
            'round': 1,
            'numbers': [1, 2, 3, 4, 5, 6],
            'bonus': 7,
          }),
        ],
        'drawCheckWeek.v1': 10,
        'largeViewIntro.v1': true,
        'display.v1':
            '{"mode":"random","default":"cards","overrides":{"paper":"spacious"}}',
      });
      var store = await LocalStorage.getInstance();
      expect(jsonDecode(store.getString('library.v1')!)['numbers'], [3]);
      expect(store.getStringList('draws.v1')!.length, 1);
      expect(store.getBool('largeViewIntro.v1'), isTrue);
      expect(jsonDecode(store.getString('papers.v1')!).single['games'].single, [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      final db = await LocalStorage.factory.openDatabase(
        LocalStorage.pathOverride!,
      );
      expect((await db.query('number_set_items')).length, 6);
      expect((await db.query('lottery_paper_game_items')).length, 6);
      await store.setString('library.v1', '{"numbers":[9],"games":[]}');
      expect((await db.query('number_set_items')), isEmpty);
      expect((await db.query('lottery_paper_game_items')).length, 6);
      await LocalStorage.reset();
      store = await LocalStorage.getInstance();
      expect(jsonDecode(store.getString('library.v1')!)['numbers'], [9]);
      expect(
        (await SharedPreferences.getInstance()).getString('library.v1'),
        library,
      );
      expect(jsonDecode(store.getString('presets.v1')!)['selected'], 'p');
      expect(store.getString('display.v1'), contains('spacious'));
    },
  );
  test(
    'failed migration rolls back and can retry with original preferences intact',
    () async {
      SharedPreferences.setMockInitialValues({
        'library.v1': library,
        'papers.v1': '[{"id":"bad","title":"bad","games":[]}]',
      });
      await expectLater(LocalStorage.getInstance(), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('library.v1'), library);
      await prefs.setString('papers.v1', '[]');
      final store = await LocalStorage.getInstance();
      expect(jsonDecode(store.getString('library.v1')!)['games'].length, 1);
    },
  );
  test('failed replacement restores previous rows', () async {
    SharedPreferences.setMockInitialValues({'library.v1': library});
    final store = await LocalStorage.getInstance();
    await expectLater(
      store.setString(
        'library.v1',
        '{"numbers":[8],"games":[{"numbers":[1,1,2,3,4,5]}]}',
      ),
      throwsArgumentError,
    );
    final restored = await LocalStorage.getInstance();
    expect(jsonDecode(restored.getString('library.v1')!)['numbers'], [3]);
    expect(jsonDecode(restored.getString('library.v1')!)['games'].length, 1);
  });
}
