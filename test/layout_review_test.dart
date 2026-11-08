import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/app_theme.dart';
import 'package:easy_lotto/collection_order.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/number_display.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/preset_store.dart';

void main() {
  final game = LottoGame([1, 11, 21, 31, 41, 45]);
  setUp(() {
    LocalStorage.testValues = {};
    libraryStore.numbers = {};
    libraryStore.games = [];
    paperStore.items = [];
    presetStore.items = [];
    presetStore.selectedId = null;
  });

  test(
    'four styles, new color default, legacy two-to-one mapping and persistence',
    () async {
      expect(PaperDesign.values.length, 4);
      expect(
        (await DisplayPreferences.load()).defaultDesign,
        PaperDesign.colorBasic,
      );
      for (final legacy in ['basic', 'spacious', 'cards']) {
        await (await LocalStorage.getInstance()).setString(
          'display.v1',
          jsonEncode({
            'mode': 'perPaper',
            'default': legacy,
            'overrides': {'a': legacy},
            'randomPapers': ['b'],
          }),
        );
        final prefs = await DisplayPreferences.load();
        expect(
          prefs.defaultDesign,
          legacy == 'cards' ? PaperDesign.cards : PaperDesign.basic,
        );
        expect(prefs.overrides['a'], prefs.defaultDesign);
        expect(prefs.randomPapers, {'b'});
        await prefs.save();
        expect(
          (await LocalStorage.getInstance()).getString('display.v1'),
          isNot(contains('spacious')),
        );
      }
    },
  );

  test('official color boundaries are exact', () {
    const colors = [0xffe08f00, 0xff0063cc, 0xffd8314f, 0xff6e7382, 0xff2c9e44];
    for (var n = 1; n <= 45; n++) {
      expect(lottoColor(n), Color(colors[(n - 1) ~/ 10]));
    }
  });

  testWidgets(
    'circle is square and digits centered regardless of digit count',
    (tester) async {
      for (final scale in [1.0, 2.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: NumberGrid(numbers: game.numbers),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tiles = find.byType(NumberTile);
        final first = tester.getSize(tiles.first);
        for (final tile in tiles.evaluate()) {
          final finder = find.byElementPredicate((e) => e == tile);
          expect(tester.getSize(finder), first);
          expect(first.width, first.height);
          final text = find.descendant(of: finder, matching: find.byType(Text));
          expect(
            (tester.getCenter(text) - tester.getCenter(finder)).distance,
            lessThan(0.1),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'rows are six, four-two, three-three or two-two-two and centered',
    (tester) async {
      Future<void> show(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: NumberGrid(numbers: game.numbers),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(700);
      final side = numberSide(tester.element(find.byType(NumberGrid)), 24);
      final cases = <double, List<int>>{
        6 * side + 5 * 8 + 10: [6],
        5 * side + 4 * 8: [4, 2],
        3 * side + 2 * 8 + 1: [3, 3],
        2 * side + 8 + 1: [2, 2, 2],
      };
      for (final entry in cases.entries) {
        await show(entry.key);
        final byY = <double, List<Offset>>{};
        for (var i = 0; i < 6; i++) {
          final center = tester.getCenter(find.byType(NumberTile).at(i));
          byY.putIfAbsent(center.dy, () => []).add(center);
        }
        expect(byY.values.map((r) => r.length).toList(), entry.value);
        final gridCenter = tester.getCenter(find.byType(NumberGrid)).dx;
        for (final row in byY.values) {
          expect((row.first.dx + row.last.dx) / 2, closeTo(gridCenter, 0.1));
        }
      }
    },
  );

  testWidgets(
    'extreme scale uses six single rows without horizontal scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(4)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GameDisplay(
                  label: 'A',
                  numbers: game.numbers,
                  design: PaperDesign.colorBasic,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final byY = <double, int>{};
      for (var i = 0; i < 6; i++) {
        final y = tester.getCenter(find.byType(NumberTile).at(i)).dy;
        byY[y] = (byY[y] ?? 0) + 1;
      }
      expect(byY.values.toList(), [1, 1, 1, 1, 1, 1]);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'style menu opens number editor while background stays placeholder',
    (tester) async {
      await (await LocalStorage.getInstance()).setBool(
        'largeViewIntro.v1',
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PaperView(
            paper: LotteryPaper('p', '용지', [game]),
            setAwake: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('스타일 변경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('번호 칸 디자인 변경'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSettings), findsOneWidget);
      expect(find.text('스타일 상세 설정'), findsNothing);
      expect(find.text('간격 넓게'), findsNothing);
      expect(
        tester
            .widgetList<RadioListTile<PaperDesign>>(
              find.byType(RadioListTile<PaperDesign>),
            )
            .length,
        4,
      );
    },
  );

  testWidgets('style description wraps without ellipsis under large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: DesignSettings(paperId: 'p'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<RadioGroup<DesignMode>>(find.byType(RadioGroup<DesignMode>))
        .onChanged(DesignMode.perPaper);
    await tester.pumpAndSettle();
    final description = find.text(
      '이 용지에만 적용되는 디자인을 선택합니다. 개별 지정이 없는 용지는 기본 디자인을 사용합니다.',
    );
    await tester.scrollUntilVisible(description, 250);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(description);
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoom tool is temporary and resets after reopening', (
    tester,
  ) async {
    await (await LocalStorage.getInstance()).setBool('largeViewIntro.v1', true);
    final paper = LotteryPaper('p', '용지', [game]);
    Widget view() => MaterialApp(
      home: PaperView(paper: paper, setAwake: (_) async {}),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    final original = tester.getSize(find.byType(NumberTile).first);
    await tester.tap(find.byTooltip('확대 테스트'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const ValueKey('text-zoom'))).onChanged!(
      3,
    );
    tester.widget<Slider>(find.byKey(const ValueKey('width-zoom'))).onChanged!(
      2,
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(NumberTile).first).width,
      greaterThan(original.width),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(NumberTile).first), original);
  });

  testWidgets('theme cancel keeps original mode and storage', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('앱 테마 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeMiniPreview), findsNWidgets(3));
    await tester.scrollUntilVisible(find.text('밝게'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('밝게'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppThemeSettings), findsNothing);
    expect((await LocalStorage.getInstance()).getString('appTheme.v1'), isNull);
  });

  testWidgets('merged library colors, selection and edit remain independent', (
    tester,
  ) async {
    libraryStore.numbers = {1, 11, 21, 31, 41};
    libraryStore.games = [SavedGame(game, null)];
    await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text).toList(),
      ['복권 용지', '내 번호·조합', '저장한 설정'],
    );
    await tester.tap(find.text('내 번호·조합'));
    await tester.pumpAndSettle();
    expect(find.byType(NumberTile), findsNWidgets(11));
    expect(
      tester
          .widgetList<NumberTile>(find.byType(NumberTile))
          .every((n) => n.colored && !n.card),
      isTrue,
    );
    await tester.tap(find.byType(NumberTile).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '1 번호 선택',
            ),
          )
          .properties
          .selected,
      true,
    );
    await tester.ensureVisible(find.text('이 조합 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 조합 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(GameComposer), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    await tester.ensureVisible(find.byType(NumberGrid));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(NumberGrid),
            matching: find.byType(NumberTile),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameComposer), findsOneWidget);
  });

  testWidgets('ordering arrows use one horizontal row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionOrder<String>(
            storageKey: 'order.test',
            items: const ['a', 'b'],
            id: (s) => s,
            builder: (s) => Text(s),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!('manual');
    await tester.pumpAndSettle();
    final up = find.byTooltip('항목 위로 이동').first,
        down = find.byTooltip('항목 아래로 이동').first;
    expect(tester.getCenter(up).dy, tester.getCenter(down).dy);
    expect(tester.getSize(up).height, greaterThanOrEqualTo(48));
  });

  testWidgets('editing existing paper uses edited-content save label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PaperEditor(paper: LotteryPaper('p', '용지', [game]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('편집한 내용 저장'), findsOneWidget);
    expect(find.text('복권 용지 저장'), findsNothing);
  });
}
