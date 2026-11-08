import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/collection_order.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/draw_source.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/number_display.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:easy_lotto/selection_tiles.dart';

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
    'name sort prioritizes symbols, numbers, Korean, English, other languages',
    () {
      final names = ['中文', 'z', '가10', '12', '!용지', '가2', '2', 'A', 'é', '😀'];
      names.sort(nameCompare);
      expect(names, ['!용지', '😀', '2', '12', '가2', '가10', 'A', 'z', 'é', '中文']);
      expect(nameCompare('  a', 'A'), 0);
    },
  );

  testWidgets('reverse name sort persists and reverses the complete ordering', (
    tester,
  ) async {
    Widget view() => MaterialApp(
      home: Scaffold(
        body: CollectionOrder<String>(
          storageKey: 'sort.test',
          items: const ['A', '가', '1', '!'],
          id: (s) => s,
          name: (s) => s,
          builder: (s) => Text('항목:$s'),
        ),
      ),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items!
          .map((i) => (i.child as Text).data)
          .toList(),
      ['최신 등록 순', '오래된 등록 순', '이름 순', '이름 역순', '사용자 지정 순서'],
    );
    dropdown.onChanged!('nameReverse');
    await tester.pumpAndSettle();
    final ys = [
      'A',
      '가',
      '1',
      '!',
    ].map((s) => tester.getCenter(find.text('항목:$s')).dy).toList();
    expect(ys, [...ys]..sort());
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'nameReverse',
    );
  });

  testWidgets(
    'favorites expand by default and collapsed state survives reopening',
    (tester) async {
      libraryStore.numbers = {1, 45};
      Future<void> show() async {
        await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('내 번호·조합'));
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.byType(NumberTile), findsNWidgets(2));
      await tester.tap(find.text('내 번호'));
      await tester.pumpAndSettle();
      expect(find.byType(NumberTile), findsNothing);
      expect(
        (await LocalStorage.getInstance()).getBool(
          'library.favoritesExpanded.v1',
        ),
        false,
      );
      await tester.pumpWidget(const SizedBox());
      await show();
      expect(find.byType(NumberTile), findsNothing);
      await tester.tap(find.text('내 번호'));
      await tester.pumpAndSettle();
      expect(find.byType(NumberTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'approved combination card separates checkbox, six balls, and footer actions',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      libraryStore.games = [SavedGame(game, null)];
      await (await LocalStorage.getInstance()).setString(
        'order.games.v1',
        jsonEncode({'mode': 'manual', 'order': []}),
      );
      await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 번호·조합'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(NumberGrid));
      await tester.pumpAndSettle();
      final tiles = find.byType(NumberTile);
      expect(tiles, findsNWidgets(6));
      final y = tester.getCenter(tiles.first).dy;
      for (var i = 1; i < 6; i++) {
        expect(tester.getCenter(tiles.at(i)).dy, y);
      }
      expect(tester.getCenter(find.byType(Checkbox)).dy, lessThan(y));
      expect(
        tester.getCenter(find.byType(Checkbox)).dx,
        greaterThan(tester.getCenter(tiles.last).dx),
      );
      final trash = tester.getCenter(find.byTooltip('조합 삭제'));
      final down = tester.getCenter(find.byIcon(Icons.arrow_downward));
      expect(trash.dy, greaterThan(y));
      expect(down.dy, trash.dy);
      expect(down.dx, lessThan(trash.dx));
      expect(trash.dx - down.dx, lessThan(64));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'design editor shows only the chosen subpanel and bold headings',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'p')),
      );
      await tester.pumpAndSettle();
      expect(find.text('기본 디자인 선택'), findsOneWidget);
      expect(find.byType(RadioGroup<int>), findsNothing);
      expect(find.text('랜덤 디자인 적용 영역'), findsNothing);
      void select(DesignMode mode) => tester
          .widget<RadioGroup<DesignMode>>(find.byType(RadioGroup<DesignMode>))
          .onChanged(mode);
      select(DesignMode.perPaper);
      await tester.pumpAndSettle();
      expect(find.text('기본 디자인 선택'), findsNothing);
      expect(find.byType(RadioGroup<int>), findsOneWidget);
      select(DesignMode.random);
      await tester.pumpAndSettle();
      expect(find.text('용지별 디자인 선택'), findsNothing);
      expect(find.byType(RadioGroup<int>), findsNothing);
      final heading = tester.widget<Text>(find.text('랜덤 디자인 적용 영역'));
      expect(heading.style!.fontWeight, FontWeight.bold);
      expect(heading.style!.fontSize, 20);
      expect(find.byType(RadioGroup<bool>), findsOneWidget);
      await tester.scrollUntilVisible(find.text('번호 칸 디자인 예시'), 150);
      expect(find.text('번호 칸 디자인 예시'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide layouts keep one centered compact number group', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 760,
              child: NumberGrid(numbers: game.numbers),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tiles = find.byType(NumberTile);
    final first = tester.getRect(tiles.first),
        second = tester.getRect(tiles.at(1)),
        last = tester.getRect(tiles.last);
    expect(second.left - first.right, closeTo(8, 0.01));
    expect(
      (first.left + last.right) / 2,
      tester.getCenter(find.byType(NumberGrid)).dx,
    );
    expect(last.right - first.left, closeTo(6 * first.width + 5 * 8, 0.01));
  });

  testWidgets(
    'composer has equal check-free choices and a live sorted colored preview',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GameComposer()));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      final choices = find.descendant(
        of: find.byType(SelectionTiles),
        matching: find.byType(OutlinedButton),
      );
      for (var i = 1; i < 4; i++) {
        expect(tester.getSize(choices.at(i)), tester.getSize(choices.first));
      }
      Future<void> select(int n) async {
        await tester.ensureVisible(find.text('$n').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('$n').first);
        await tester.pumpAndSettle();
      }

      await select(41);
      await select(2);
      final preview = find
          .ancestor(of: find.text('선택한 조합'), matching: find.byType(Wrap))
          .first;
      expect(
        tester
            .widgetList<NumberTile>(
              find.descendant(of: preview, matching: find.byType(NumberTile)),
            )
            .map((n) => n.number)
            .toList(),
        [2, 41],
      );
      await select(41);
      expect(
        tester
            .widgetList<NumberTile>(
              find.descendant(of: preview, matching: find.byType(NumberTile)),
            )
            .map((n) => n.number)
            .toList(),
        [2],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paper editor uses alphabetical labels and colored circular numbers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PaperEditor(paper: LotteryPaper('p', '용지', [game]))),
      );
      await tester.pumpAndSettle();
      expect(find.text('게임 A'), findsOneWidget);
      expect(find.text('게임 1'), findsNothing);
      expect(
        tester
            .widgetList<NumberTile>(find.byType(NumberTile))
            .every((t) => t.colored && !t.card),
        true,
      );
    },
  );

  testWidgets('home has equal generation choices and More has no attribution', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byTooltip('보관함')),
      findsNothing,
    );
    final random = find.widgetWithText(OutlinedButton, '완전 랜덤'),
        detail = find.widgetWithText(OutlinedButton, '상세 규칙');
    expect(tester.getSize(random), tester.getSize(detail));
    await tester.tap(detail);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('번호 생성 방식')).dy,
      lessThan(tester.getCenter(detail).dy),
    );
    expect(
      tester.getCenter(find.text('고정수·제외수 등 원하는 규칙을 설정하여 번호를 생성합니다.')).dy,
      greaterThan(tester.getCenter(detail).dy),
    );
    await tester.ensureVisible(find.byType(DrawSource));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byType(DrawSource)).dy,
      greaterThan(tester.getCenter(find.text('설정 만들기')).dy),
    );
    await tester.tap(find.widgetWithText(NavigationDestination, '더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawSource), findsNothing);
    expect(
      tester.getCenter(find.text('결과 이탈 안내 다시 켜기')).dy,
      lessThan(tester.getCenter(find.text('로또 번호 추천 안내')).dy),
    );
  });
}
