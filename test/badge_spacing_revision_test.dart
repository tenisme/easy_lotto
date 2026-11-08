import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/collection_order.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/favorite_number_dialog.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/number_display.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/preset_store.dart';

void main() {
  final game = LottoGame([1, 2, 3, 4, 5, 6]);
  setUp(() {
    LocalStorage.testValues = {};
    libraryStore.numbers = {};
    libraryStore.games = [];
    paperStore.items = [];
    presetStore.items = [];
  });
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder savedList() => find
      .descendant(
        of: find.byKey(const PageStorageKey('number-combination-list')),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> library(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 번호·조합'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, int n) async {
    final allChoices = find.byWidgetPredicate(
      (w) => w is SelectableNumber && w.number == n,
    );
    final choice = find.byType(FavoriteNumberDialog).evaluate().isEmpty
        ? allChoices
        : find.descendant(
            of: find.byType(FavoriteNumberDialog),
            matching: allChoices,
          );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'six-number area occupies 85 percent portrait and 65 percent landscape',
    (tester) async {
      for (final size in [const Size(700, 1200), const Size(1200, 700)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NumberGrid(numbers: game.numbers),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = tester.getRect(find.byType(NumberTile).first),
            last = tester.getRect(find.byType(NumberTile).last);
        final fraction = size.width > size.height ? .65 : .85;
        expect(last.right - first.left, closeTo(size.width * fraction, .01));
        expect((first.left + last.right) / 2, size.width / 2);
        expect(
          tester.getRect(find.byType(NumberTile).at(1)).left - first.right,
          greaterThan(8),
        );
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'favorite badge has white heart, emphasis border and larger size in both themes',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Center(
                child: SelectableNumber(
                  number: 11,
                  selected: true,
                  favorite: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final badge = tester.widget<Container>(
          find.byKey(const ValueKey('favorite-badge-11')),
        );
        final decoration = badge.decoration! as BoxDecoration;
        expect((decoration.border! as Border).top.color, decoration.color);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
          Colors.white,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('favorite-badge-11'))).width,
          closeTo(
            numberSide(tester.element(find.byType(SelectableNumber)), 18) * .46,
            .01,
          ),
        );
        expect(
          1.05 / (decoration.color!.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'number dialog uses five columns, nine landscape columns and fewer with zoom',
    (tester) async {
      for (final config in [
        (const Size(420, 900), 1.0, 5),
        (const Size(1000, 500), 1.0, 9),
        (const Size(420, 900), 3.0, 2),
      ]) {
        tester.view.physicalSize = config.$1;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: config.$1,
                textScaler: TextScaler.linear(config.$2),
              ),
              child: const Scaffold(body: FavoriteNumberDialog(saved: {})),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final y = tester.getCenter(find.byType(SelectableNumber).first).dy;
        final firstRow = find
            .byType(SelectableNumber)
            .evaluate()
            .where(
              (e) =>
                  (tester.getCenter(find.byElementPredicate((x) => x == e)).dy -
                          y)
                      .abs() <
                  .1,
            )
            .length;
        expect(firstRow, config.$3);
        expect(find.byType(SelectableNumber), findsNWidgets(45));
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'number add confirms once, preserves old numbers and survives reload',
    (tester) async {
      viewport(tester, const Size(420, 900));
      libraryStore.numbers = {11};
      await library(tester);
      await tester.tap(find.widgetWithText(FilledButton, '번호 추가'));
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteNumberDialog), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, '확인');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await choose(tester, 11);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await choose(tester, 1);
      await choose(tester, 2);
      expect(libraryStore.numbers, {11});
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(libraryStore.numbers, {1, 2, 11});
      await libraryStore.load();
      expect(libraryStore.numbers, {1, 2, 11});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('batch deletion confirms and never changes paper snapshots', (
    tester,
  ) async {
    viewport(tester, const Size(420, 900));
    await libraryStore.saveGame(game, null);
    final paper = await paperStore.save('원본 용지', [game]);
    await library(tester);
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      150,
      scrollable: savedList(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final delete = find.widgetWithText(OutlinedButton, '선택한 조합 삭제');
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(libraryStore.games.length, 1);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(libraryStore.games, isEmpty);
    expect(paperStore.items.single.games, paper.games);
    await libraryStore.load();
    expect(libraryStore.games, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'footer stays fixed while list scrolls and has three columns in landscape',
    (tester) async {
      viewport(tester, const Size(1000, 500));
      libraryStore.games = [
        for (var i = 0; i < 20; i++)
          SavedGame(LottoGame([1, 2, 3, 4, 5, i + 6]), null),
      ];
      await library(tester);
      final add = find.widgetWithText(FilledButton, '조합 직접 추가'),
          delete = find.widgetWithText(OutlinedButton, '선택한 조합 삭제'),
          paper = find.widgetWithText(OutlinedButton, '선택 조합으로 복권 용지 만들기');
      final original = tester.getRect(add);
      expect(tester.getCenter(add).dy, tester.getCenter(delete).dy);
      expect(tester.getCenter(add).dy, tester.getCenter(paper).dy);
      await tester.drag(savedList(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(add), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full combination can remove any number and replace it with a heart-marked favorite',
    (tester) async {
      viewport(tester, const Size(420, 900));
      libraryStore.numbers = {11};
      await tester.pumpWidget(
        MaterialApp(home: GameComposer(initialGame: game)),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, '내 번호'), findsNothing);
      expect(find.byKey(const ValueKey('favorite-badge-11')), findsOneWidget);
      await choose(tester, 1);
      await choose(tester, 11);
      final preview = find.byType(SelectedNumberPreview);
      expect(tester.widget<SelectedNumberPreview>(preview).numbers, [
        2,
        3,
        4,
        5,
        6,
        11,
      ]);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(preview).dy,
        greaterThan(tester.getBottomLeft(find.text('선택한 조합')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection preview keeps the first slot stable when numbers change',
    (tester) async {
      viewport(tester, const Size(700, 1000));
      Future<void> show(List<int> numbers) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SelectedNumberPreview(numbers: numbers)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show([3]);
      final x = tester.getCenter(find.byType(NumberTile).first).dx;
      await show([3, 11, 24]);
      expect(tester.getCenter(find.byType(NumberTile).first).dx, x);
      final left = tester.getRect(find.byType(NumberTile).first).left;
      expect(left, closeTo(700 * .075, .01));
    },
  );

  testWidgets('manual-order hint has equal top and bottom spacing', (
    tester,
  ) async {
    await (await LocalStorage.getInstance()).setString(
      'spacing.order',
      '{"mode":"manual","order":["a"]}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionOrder<String>(
            storageKey: 'spacing.order',
            items: const ['a'],
            id: (s) => s,
            builder: (_) => const SizedBox(height: 48),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hint = find.text('화살표로 순서를 변경합니다.');
    final column = find.ancestor(of: hint, matching: find.byType(Column)).first;
    final children = tester.widget<Column>(column).children,
        index = children.indexWhere(
          (w) => w is Text && w.data == '화살표로 순서를 변경합니다.',
        );
    expect((children[index - 1] as SizedBox).height, 16);
    expect((children[index + 1] as SizedBox).height, 16);
  });

  testWidgets(
    'large text keeps composer, popup and fixed footer within narrow screens',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(900, 420)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        Widget app(Widget child) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(3)),
            child: child,
          ),
        );
        await tester.pumpWidget(app(GameComposer(initialGame: game)));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(SelectedNumberPreview),
          300,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(const LibraryPage()));
        await tester.pumpAndSettle();
        final tab = find.text('내 번호·조합');
        await tester.ensureVisible(tab);
        await tester.pumpAndSettle();
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.text('조합 직접 추가'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          app(const Scaffold(body: FavoriteNumberDialog(saved: {}))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  test(
    'batch number updates are idempotent and reject invalid batches atomically',
    () async {
      await libraryStore.addNumbers({1, 11});
      await libraryStore.addNumbers({11, 45});
      expect(libraryStore.numbers, {1, 11, 45});
      await expectLater(libraryStore.addNumbers({2, 46}), throwsArgumentError);
      expect(libraryStore.numbers, {1, 11, 45});
      await libraryStore.saveGame(game, null);
      await libraryStore.saveGame(LottoGame([7, 8, 9, 10, 11, 12]), null);
      await libraryStore.removeGames({game});
      expect(libraryStore.games.length, 1);
      await libraryStore.load();
      expect(libraryStore.games.length, 1);
    },
  );
}
