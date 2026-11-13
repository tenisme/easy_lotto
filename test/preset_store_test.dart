import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:easy_lotto/domain/recommendation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('deleting selected preset clears restored selection', () async {
    final store = PresetStore();
    final p = await store.save(RecommendationOptions());
    await store.delete(p.id);
    final restored = PresetStore();
    await restored.load();
    expect(restored.items, isEmpty);
    expect(restored.selectedId, isNull);
  });
  test(
    'options survive storage including both draw scopes and group lengths',
    () async {
      final store = PresetStore();
      final options = RecommendationOptions(
        fixed: [3],
        excluded: [5],
        oddCount: 3,
        lowCount: 2,
        minSum: 100,
        maxSum: 200,
        groupCount: 2,
        groupLengths: [2, 3],
        excludePrevious: true,
        previousIncludesBonus: false,
        missingCount: 1,
        missingRounds: 20,
        missingIncludesBonus: false,
      );
      final preset = await store.save(options, name: ' 균형 ');
      final restored = PresetStore();
      await restored.load();
      expect(restored.selectedId, preset.id);
      expect(restored.items.single.name, '균형');
      expect(sameOptions(options, restored.items.single.options), isTrue);
    },
  );
  test(
    'automatic names, duplicate prevention and rename keep identity',
    () async {
      final store = PresetStore();
      final a = await store.save(RecommendationOptions(), name: ' ');
      final b = await store.save(RecommendationOptions());
      expect([a.name, b.name], ['설정1', '설정2']);
      await expectLater(
        store.save(a.options, name: '설정1'),
        throwsArgumentError,
      );
      final renamed = await store.save(a.options, id: a.id, name: '새 이름');
      expect(renamed.id, a.id);
      expect(store.items.length, 2);
      await store.select(b.id);
      final restored = PresetStore();
      await restored.load();
      expect(restored.selectedId, b.id);
    },
  );
}
