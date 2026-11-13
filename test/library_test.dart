import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/paper_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'editing and duplicate rejection leave paper snapshots intact',
    () async {
      final store = LibraryStore();
      final papers = PaperStore();
      final a = LottoGame([1, 2, 3, 4, 5, 6]);
      final b = LottoGame([7, 8, 9, 10, 11, 12]);
      await store.saveGame(a, null);
      final p = await papers.save('', [a]);
      await store.editGame(a, b);
      expect(store.games.single.source, 'manual');
      expect(papers.items.single.games.single, a);
      await expectLater(store.editGame(null, b), throwsArgumentError);
      await store.toggleNumber(3);
      await store.toggleNumber(4);
      await store.removeNumbers({3});
      final restored = LibraryStore();
      await restored.load();
      expect(restored.numbers, {4});
      expect(restored.games.single.game, b);
      await papers.delete(p.id);
      final reload = PaperStore();
      await reload.load();
      expect(reload.items, isEmpty);
    },
  );
  test('queued toggles and duplicate games persist across restart', () async {
    final store = LibraryStore();
    final game = LottoGame([1, 2, 3, 4, 5, 6]);
    await Future.wait([
      store.toggleNumber(3),
      store.toggleNumber(4),
      store.toggleNumber(3),
      store.saveGame(game, RecommendationOptions(oddCount: 3)),
      store.saveGame(game, null),
    ]);
    final restored = LibraryStore();
    await restored.load();
    expect(restored.numbers, {4});
    expect(restored.games.length, 1);
    expect(restored.games.single.options!.oddCount, 3);
    await restored.removeGame(game);
    final again = LibraryStore();
    await again.load();
    expect(again.games, isEmpty);
    expect(again.numbers, {4});
  });
}
