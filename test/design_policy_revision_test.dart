import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/favorite_number_dialog.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:easy_lotto/style_reset_dialog.dart';
import 'package:easy_lotto/number_display.dart';
import 'package:easy_lotto/word_wrap_text.dart';
import 'package:easy_lotto/selection_tiles.dart';
import 'package:easy_lotto/main.dart';

void main() {
  setUp(() {
    LocalStorage.testValues = {};
    libraryStore.numbers = {};
    libraryStore.games = [];
    paperStore.items = [];
    presetStore.items = [];
  });
  LottoGame game(List<int> ns, GameOrigin origin) =>
      LottoGame(ns, origin: origin);
  final a = game([
    1,
    2,
    3,
    4,
    5,
    6,
  ], const GameOrigin('configured', name: '균형 조합'));
  final b = game([7, 8, 9, 10, 11, 12], const GameOrigin('random'));
  test(
    'legacy basic mode keeps its active random exceptions through a storage round-trip',
    () async {
      await (await LocalStorage.getInstance()).setString(
        'display.v1',
        jsonEncode({
          'mode': 'basic',
          'default': 'basic',
          'overrides': {'a': 'cards'},
          'randomPapers': ['b'],
        }),
      );
      var p = await DisplayPreferences.load();
      expect(p.resolve('a', Random()), PaperDesign.basic);
      expect(p.overrides['a'], PaperDesign.cards);
      final rng = Random(1);
      expect({for (var i = 0; i < 40; i++) p.resolve('b', rng)}.length, 4);
      await p.save();
      p = await DisplayPreferences.load();
      expect(p.resolve('a', Random()), PaperDesign.basic);
      expect(p.overrides['a'], PaperDesign.cards);
      expect({for (var i = 0; i < 40; i++) p.resolve('b', rng)}.length, 4);
    },
  );
  testWidgets(
    'result actions share one row and save the name captured before a preset rename',
    (tester) async {
      final p = await presetStore.save(
        RecommendationOptions(),
        name: '생성 당시 이름',
      );
      await presetStore.save(RecommendationOptions(oddCount: 3), name: '다른 설정');
      await tester.pumpWidget(
        MaterialApp(
          home: RecommendationResults(
            initialGames: [LottoGame(a.numbers)],
            options: p.options,
            presetId: p.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.widgetWithText(OutlinedButton, '다른 설정 선택'),
          edit = find.widgetWithText(OutlinedButton, '설정 수정');
      expect(tester.getCenter(choose).dy, tester.getCenter(edit).dy);
      await presetStore.save(p.options, id: p.id, name: '변경한 이름');
      await tester.scrollUntilVisible(find.text('조합 저장'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('조합 저장'));
      await tester.pumpAndSettle();
      expect(libraryStore.games.single.game.origin!.name, '생성 당시 이름');
    },
  );
  testWidgets(
    'large-text design settings and reset dialog remain scrollable without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget child) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(3),
          ),
          child: child,
        ),
      );
      await tester.pumpWidget(app(const DesignSettings(paperId: 'a')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('번호 칸 디자인 예시'),
        300,
        maxScrolls: 60,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(const Scaffold(body: StyleResetDialog(paperId: 'a'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('management dialog has only plain and selected-favorite states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FavoriteNumberDialog(saved: {11})),
      ),
    );
    await tester.pumpAndSettle();
    SelectableNumber number(int n) => tester.widget<SelectableNumber>(
      find.byWidgetPredicate((w) => w is SelectableNumber && w.number == n),
    );
    expect(number(11).selected, true);
    expect(number(11).favorite, true);
    expect(number(1).selected, false);
    expect(number(1).favorite, false);
    await tester.tap(
      find.byWidgetPredicate((w) => w is SelectableNumber && w.number == 11),
    );
    await tester.pumpAndSettle();
    expect(number(11).selected, false);
    expect(number(11).favorite, false);
    expect(find.byKey(const ValueKey('favorite-badge-11')), findsNothing);
    await tester.tap(
      find.byWidgetPredicate((w) => w is SelectableNumber && w.number == 1),
    );
    await tester.pumpAndSettle();
    expect(number(1).selected, true);
    expect(number(1).favorite, true);
    expect(find.text("터치로 '내 번호'를 추가 및 삭제할 수 있습니다."), findsOneWidget);
  });
  testWidgets(
    'clearing all favorites is saved, while cancellation preserves the set',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      libraryStore.numbers = {11};
      await tester.pumpWidget(const MaterialApp(home: LibraryPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 번호·조합'));
      await tester.pumpAndSettle();
      final manage = find.widgetWithText(FilledButton, '내 번호 추가·삭제');
      await tester.tap(manage);
      await tester.pumpAndSettle();
      final choice = find.descendant(
        of: find.byType(FavoriteNumberDialog),
        matching: find.byWidgetPredicate(
          (w) => w is SelectableNumber && w.number == 11,
        ),
      );
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(libraryStore.numbers, {11});
      await tester.tap(manage);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(libraryStore.numbers, isEmpty);
      await libraryStore.load();
      expect(libraryStore.numbers, isEmpty);
    },
  );
  testWidgets(
    'button labels wrap at words rather than separating the last syllable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 126,
                child: WordWrapText(
                  '선택한 조합 추가',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final p = tester.renderObject<RenderParagraph>(find.text('선택한 조합 추가'));
      expect(p.text.toPlainText(), endsWith('\n추가'));
      expect(p.text.toPlainText(), isNot(contains('추\n가')));
      expect(p.textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'default changes preserve overrides and overwrite only masks them',
    () async {
      final overrides = {'a': PaperDesign.cards, 'b': PaperDesign.basic};
      final forced = DisplayPreferences(
        defaultDesign: PaperDesign.colorCards,
        overrides: overrides,
        randomPapers: {'c'},
        overwriteOverrides: true,
      );
      await forced.save();
      final loaded = await DisplayPreferences.load();
      expect(loaded.resolve('a', Random()), PaperDesign.colorCards);
      expect(loaded.resolve('c', Random()), PaperDesign.colorCards);
      expect(loaded.overrides, overrides);
      expect(loaded.randomPapers, {'c'});
      final keep = DisplayPreferences(
        defaultDesign: loaded.defaultDesign,
        overrides: loaded.overrides,
        randomPapers: loaded.randomPapers,
      );
      expect(keep.resolve('a', Random()), PaperDesign.cards);
      expect(keep.resolve('b', Random()), PaperDesign.basic);
      expect(keep.resolve('other', Random()), PaperDesign.colorCards);
    },
  );
  test(
    'global random respects fixed local styles unless overwrite is selected',
    () {
      final keep = DisplayPreferences(
        defaultRandom: true,
        overrides: {'a': PaperDesign.cards},
      );
      final rng = Random(4);
      expect(keep.resolve('a', rng), PaperDesign.cards);
      expect({for (var i = 0; i < 40; i++) keep.resolve('b', rng)}.length, 4);
      final force = DisplayPreferences(
        defaultRandom: true,
        overwriteOverrides: true,
        overrides: keep.overrides,
      );
      expect({for (var i = 0; i < 40; i++) force.resolve('a', rng)}.length, 4);
    },
  );
  test(
    'individual reset restores inheritance while all reset restores factory style',
    () {
      final p = DisplayPreferences(
        defaultDesign: PaperDesign.colorCards,
        overrides: {'a': PaperDesign.cards, 'b': PaperDesign.basic},
        randomPapers: {'a'},
        defaultBackground: 'base',
        backgrounds: {'a': 'photo', 'b': 'other'},
      );
      final local = p.reset(
        paperId: 'a',
        all: false,
        numbers: true,
        background: false,
      );
      expect(local.overrides, {'b': PaperDesign.basic});
      expect(local.randomPapers, isEmpty);
      expect(local.resolve('a', Random()), PaperDesign.colorCards);
      expect(local.backgrounds, p.backgrounds);
      final all = p.reset(
        paperId: 'a',
        all: true,
        numbers: true,
        background: true,
      );
      expect(all.defaultDesign, PaperDesign.colorBasic);
      expect(all.isDefaultRandom, false);
      expect(all.overwriteOverrides, false);
      expect(all.overrides, isEmpty);
      expect(all.randomPapers, isEmpty);
      expect(all.backgrounds, isEmpty);
      expect(all.defaultBackground, isNull);
      final images = p.reset(
        paperId: 'a',
        all: true,
        numbers: false,
        background: true,
      );
      expect(images.overrides, p.overrides);
      expect(images.randomPapers, p.randomPapers);
      expect(images.backgrounds, isEmpty);
    },
  );
  testWidgets(
    'inherited choice is preselected without creating a local override',
    (tester) async {
      await DisplayPreferences(
        mode: DesignMode.perPaper,
        defaultDesign: PaperDesign.cards,
      ).save();
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'a')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        PaperDesign.cards.index,
      );
      expect(find.text('기본 디자인 사용'), findsNothing);
      await tester.tap(find.text('변경 완료'));
      await tester.pumpAndSettle();
      expect((await DisplayPreferences.load()).overrides, isEmpty);
    },
  );
  testWidgets(
    'overwrite UI persists its choice and maintain restores saved local styles',
    (tester) async {
      await DisplayPreferences(overrides: {'a': PaperDesign.cards}).save();
      Future<void> show() async {
        await tester.pumpWidget(
          const MaterialApp(home: DesignSettings(paperId: 'a')),
        );
        await tester.pumpAndSettle();
      }

      await show();
      expect(
        tester.widget<SelectionTiles>(find.byType(SelectionTiles)).selected,
        0,
      );
      await tester.ensureVisible(find.text('덮어쓰기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('덮어쓰기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경 완료'));
      await tester.pumpAndSettle();
      var prefs = await DisplayPreferences.load();
      expect(prefs.overwriteOverrides, true);
      expect(prefs.overrides['a'], PaperDesign.cards);
      expect(prefs.resolve('a', Random()), PaperDesign.colorBasic);
      await tester.pumpWidget(const SizedBox());
      await show();
      await tester.ensureVisible(find.text('유지하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('유지하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경 완료'));
      await tester.pumpAndSettle();
      prefs = await DisplayPreferences.load();
      expect(prefs.resolve('a', Random()), PaperDesign.cards);
    },
  );
  testWidgets(
    'reset warns about all local settings and cancel never changes styles',
    (tester) async {
      final original = DisplayPreferences(
        defaultDesign: PaperDesign.basic,
        overrides: {'a': PaperDesign.cards, 'b': PaperDesign.colorCards},
      );
      await original.save();
      final paper = await paperStore.save('용지', [a]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<DisplayPreferences>(
                  context: context,
                  builder: (_) => const StyleResetDialog(paperId: 'a'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester
          .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
          .onChanged(true);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '초기화'));
      await tester.pumpAndSettle();
      expect(find.textContaining('모든 용지별 번호 칸 디자인 설정이 초기화'), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
      expect((await DisplayPreferences.load()).overrides, original.overrides);
      await tester.tap(find.widgetWithText(FilledButton, '초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '초기화').last);
      await tester.pumpAndSettle();
      final prefs = await DisplayPreferences.load();
      expect(prefs.overrides, isEmpty);
      expect(prefs.defaultDesign, PaperDesign.colorBasic);
      expect(paperStore.items.single.games, paper.games);
    },
  );
  test(
    'creation names and method labels survive rename, reorder and deletion',
    () async {
      final preset = await presetStore.save(
        RecommendationOptions(),
        name: '균형 조합',
      );
      await libraryStore.saveGame(a, RecommendationOptions());
      await presetStore.save(preset.options, id: preset.id, name: '이름 변경');
      await presetStore.delete(preset.id);
      await libraryStore.load();
      expect(libraryStore.games.single.game.origin!.label, '균형 조합');
      final paper = await paperStore.save('용지', [a, b]);
      expect(paper.sourceSummary, '균형 조합 외 1개');
      await libraryStore.removeGames({a});
      await paperStore.load();
      expect(paperStore.items.single.sourceSummary, '균형 조합 외 1개');
      final moved = await paperStore.save('용지', [b, a], id: paper.id);
      expect(moved.sourceSummary, '완전 랜덤 외 1개');
      expect(
        a,
        LottoGame(a.numbers),
      ); // provenance must not alter duplicate detection.
    },
  );
  test(
    'SQLite v1 upgrades without losing numbers and v2 preserves provenance',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'lotto-origin-upgrade-',
      );
      await LocalStorage.reset();
      LocalStorage.pathOverride = '${dir.path}/data.db';
      try {
        await libraryStore.saveGame(a, RecommendationOptions());
        await paperStore.save('용지', [a, b]);
        await LocalStorage.reset();
        await libraryStore.load();
        await paperStore.load();
        expect(libraryStore.games.single.game.origin!.name, '균형 조합');
        expect(paperStore.items.single.sourceSummary, '균형 조합 외 1개');
        final db = await LocalStorage.factory.openDatabase(
          LocalStorage.pathOverride!,
        );
        await db.execute('ALTER TABLE number_sets DROP COLUMN source_name');
        await db.execute(
          'ALTER TABLE lottery_paper_games DROP COLUMN source_name',
        );
        await db.execute('ALTER TABLE lottery_paper_games DROP COLUMN source');
        await db.execute('PRAGMA user_version = 1');
        await LocalStorage.reset();
        await libraryStore.load();
        await paperStore.load();
        expect(libraryStore.games.single.game, a);
        expect(libraryStore.games.single.game.origin!.label, '상세 규칙');
        expect(paperStore.items.single.games, [a, b]);
        expect(paperStore.items.single.sourceSummary, '기록 없음');
        final newDb = await LocalStorage.factory.openDatabase(
          LocalStorage.pathOverride!,
        );
        expect(
          (await newDb.rawQuery('PRAGMA user_version')).single.values.single,
          2,
        );
      } finally {
        await LocalStorage.reset();
        LocalStorage.pathOverride = ':memory:';
        await dir.delete(recursive: true);
      }
    },
  );
}
