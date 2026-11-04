import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final a = LottoGame([1, 2, 3, 4, 5, 6]);
  final b = LottoGame([7, 8, 9, 10, 11, 12]);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    paperStore.items = [];
    libraryStore.games = [];
  });
  test(
    'paper keeps independent numbers, order and default title after restart',
    () async {
      final library = LibraryStore();
      await library.saveGame(a, null);
      final store = PaperStore();
      final paper = await store.save('', [a, b]);
      expect(paper.title, '복권 용지 1');
      expect(identical(paper.games.first, a), isFalse);
      await library.removeGame(a);
      await store.save('수정', [b, a], id: paper.id);
      final restored = PaperStore();
      await restored.load();
      expect(restored.items.single.games, [b, a]);
      expect(restored.items.single.title, '수정');
      expect(restored.items.single.id, paper.id);
      expect((await store.save('', [a])).title, '복권 용지 1');
    },
  );
  test(
    'rejects empty and oversized papers without changing saved state',
    () async {
      final store = PaperStore();
      await store.save('', [a]);
      await expectLater(store.save('', []), throwsArgumentError);
      await expectLater(store.save('', List.filled(6, a)), throwsArgumentError);
      expect(store.items.length, 1);
      await store.save('', [b]);
      expect(store.items.length, 2);
    },
  );
  testWidgets('result selection defaults to all and cannot continue empty', (
    tester,
  ) async {
    List<LottoGame>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await selectGames(context, [a, b]);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((c) => c.value == true),
      isTrue,
    );
    await tester.tap(find.text(a.numbers.join(' · ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(b.numbers.join(' · ')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text(b.numbers.join(' · ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(result, [b]);
  });
  testWidgets('paper editor reorders games before committing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PaperEditor(initialGames: [a, b])),
    );
    await tester.tap(find.byTooltip('위로 이동').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('용지 저장'));
    await tester.tap(find.text('용지 저장'));
    await tester.pumpAndSettle();
    expect(paperStore.items.single.games, [b, a]);
  });
  testWidgets('paper editor saves without saving source combination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => PaperEditor(initialGames: [a]),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('용지 저장'));
    await tester.pumpAndSettle();
    expect(paperStore.items.single.games, [a]);
    expect(libraryStore.games, isEmpty);
    expect(find.byType(PaperEditor), findsNothing);
  });
}
