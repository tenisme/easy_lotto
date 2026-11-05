import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/collection_order.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/exit_guard.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:easy_lotto/settings_editor.dart';

void main() {
  final a = LottoGame([1, 2, 3, 4, 5, 6]);
  final b = LottoGame([11, 12, 13, 14, 15, 16]);
  setUp(() {
    LocalStorage.testValues = {};
    paperStore.items = [];
    libraryStore.games = [];
    libraryStore.numbers = {};
    presetStore.items = [];
    presetStore.selectedId = null;
  });
  testWidgets('complete rules save and leave with only one confirmation', (
    tester,
  ) async {
    final preset = await presetStore.save(
      RecommendationOptions(),
      name: '기존 설정',
    );
    RecommendationOptions? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<RecommendationOptions>(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsEditor(
                    initial: preset.options,
                    presetId: preset.id,
                    completeOnly: true,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1묶음'));
    await tester.tap(find.text('1묶음'));
    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();
    expect(find.text('저장하고 나가시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('저장하고 나가기'));
    await tester.pumpAndSettle();
    expect(result?.groupCount, 1);
    expect(presetStore.find(preset.id)!.options.groupCount, 1);
    expect(find.byType(SettingsEditor), findsNothing);
  });
  testWidgets('identical replacement is rejected before confirmation', (
    tester,
  ) async {
    final paper = await paperStore.save('용지', [a]);
    await libraryStore.saveGame(a, null);
    await tester.pumpWidget(MaterialApp(home: PaperEditor(paper: paper)));
    await tester.tap(find.text('교체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(a.numbers.join(' · ')).last);
    await tester.pumpAndSettle();
    expect(find.text('현재 게임과 같은 번호 조합으로는 교체할 수 없습니다.'), findsOneWidget);
    expect(find.text('이 게임을 교체하시겠습니까?'), findsNothing);
    expect(paperStore.items.single.games, [a]);
  });
  test('numeric names and periods longer than 100 are supported', () {
    expect(naturalCompare('설정2', '설정10'), lessThan(0));
    final draws = [for (var r = 1; r <= 101; r++) DrawResult(r, a, 7)];
    final result = RecommendationEngine(random: Random(1)).generate(
      RecommendationOptions(
        fixed: [1, 2, 3, 4, 5, 8],
        missingCount: 1,
        missingRounds: 101,
      ),
      draws: draws,
    );
    expect(result.single.numbers, [1, 2, 3, 4, 5, 8]);
  });
  testWidgets('wake preference survives reopening but effect stops offscreen', (
    tester,
  ) async {
    await (await LocalStorage.getInstance()).setBool('largeViewIntro.v1', true);
    final calls = <bool>[];
    final paper = LotteryPaper('a', '용지 A', [a]);
    Widget view() => MaterialApp(
      home: PaperView(
        paper: paper,
        setAwake: (v) async {
          calls.add(v);
        },
      ),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    await tester.tap(find.text('화면 계속 켜기'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls.last, false);
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    expect(calls.last, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls.last, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls.last, true);
  });
  testWidgets(
    'per-paper editor cannot modify global base and preserves other overrides',
    (tester) async {
      await DisplayPreferences(
        mode: DesignMode.perPaper,
        defaultDesign: PaperDesign.spacious,
        overrides: {'a': PaperDesign.cards},
      ).save();
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'b')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<PaperDesign>>(
              find.byType(DropdownButtonFormField<PaperDesign>),
            )
            .onChanged,
        isNull,
      );
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged!(PaperDesign.basic.index);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('저장'), 200);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final prefs = await DisplayPreferences.load();
      expect(prefs.resolve('a', Random()), PaperDesign.cards);
      expect(prefs.resolve('b', Random()), PaperDesign.basic);
      expect(prefs.resolve('c', Random()), PaperDesign.spacious);
    },
  );
  testWidgets(
    'saved result games are locked but intentional paper reuse remains allowed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RecommendationResults(initialGames: [a, b])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-game-1')));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('선택한 게임 복권 용지에 저장'), 200);
      await tester.tap(find.text('선택한 게임 복권 용지에 저장'));
      await tester.pumpAndSettle();
      expect(find.text('용지에 담을 게임 선택'), findsNothing);
      await tester.tap(find.text('새 복권 용지 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('교체'), findsNothing);
      expect(find.text('제거'), findsNothing);
      await tester.tap(find.text('복권 용지 저장'));
      await tester.pumpAndSettle();
      expect(paperStore.items.single.games, [a]);
      await tester.scrollUntilVisible(find.text('저장됨'), -200);
      expect(find.text('저장됨'), findsOneWidget);
      expect(find.byKey(const ValueKey('select-game-0')), findsNothing);
      expect(libraryStore.games, isEmpty);
      await paperStore.save('다른 용지', [a]);
      expect(paperStore.items.length, 2);
    },
  );
  testWidgets('single result skips selection and full papers are omitted', (
    tester,
  ) async {
    await paperStore.save('가득 찬 용지', List.filled(5, a));
    await tester.pumpWidget(
      MaterialApp(home: RecommendationResults(initialGames: [b])),
    );
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('선택한 게임 복권 용지에 저장'));
    await tester.pumpAndSettle();
    expect(find.text('복권 용지 선택'), findsOneWidget);
    expect(find.text('가득 찬 용지'), findsNothing);
  });
  testWidgets('impossible options remain in rules editor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsEditor(
          initial: RecommendationOptions(fixed: a.numbers, oddCount: 0),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('번호 생성'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsOneWidget);
    expect(find.textContaining('조건을 만족하는'), findsOneWidget);
  });
  testWidgets('preset overwrite confirmation cancellation preserves original', (
    tester,
  ) async {
    final preset = await presetStore.save(RecommendationOptions(), name: '원본');
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsEditor(initial: preset.options, presetId: preset.id),
      ),
    );
    await tester.ensureVisible(find.text('1묶음'));
    await tester.tap(find.text('1묶음'));
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.text('변경한 설정을 저장하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('아니요'));
    await tester.pumpAndSettle();
    expect(presetStore.find(preset.id)!.options.groupCount, null);
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('네'));
    await tester.pumpAndSettle();
    expect(presetStore.find(preset.id)!.options.groupCount, 1);
    expect(find.byType(SettingsEditor), findsOneWidget);
  });
  testWidgets('custom periods validate and persist in another editor', (
    tester,
  ) async {
    final draws = [for (var r = 1; r <= 30; r++) DrawResult(r, a, 7)];
    await tester.pumpWidget(MaterialApp(home: SettingsEditor(draws: draws)));
    await tester.scrollUntilVisible(find.text('직접 입력'), 250);
    await tester.tap(find.text('직접 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '31');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '확인'))
          .onPressed,
      null,
    );
    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InputChip>(find.widgetWithText(InputChip, '최근 20회'))
          .selected,
      true,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: SettingsEditor(draws: draws)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('최근 20회'), 250);
    expect(find.text('최근 20회'), findsOneWidget);
  });
  testWidgets('warning suppression is limited to result loss', (tester) async {
    await (await LocalStorage.getInstance()).setBool(
      'resultLossNotice.v1',
      true,
    );
    bool? result;
    Widget view(String? key) => MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await confirmResultLoss(
              context,
              message: '소실 안내',
              suppressionKey: key,
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.pumpWidget(view('resultLossNotice.v1'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(view(null));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('소실 안내'), findsOneWidget);
    expect(find.text('다시 보지 않기'), findsNothing);
  });
  testWidgets('manual collection order persists across remount', (
    tester,
  ) async {
    Widget view() => MaterialApp(
      home: Scaffold(
        body: CollectionOrder<String>(
          storageKey: 'test.order',
          items: const ['설정10', '설정2'],
          id: (s) => s,
          name: (s) => s,
          builder: (s) => Text(s),
        ),
      ),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!('manual');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('항목 아래로 이동').first);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('설정10')).dy,
      lessThan(tester.getTopLeft(find.text('설정2')).dy),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('설정10')).dy,
      lessThan(tester.getTopLeft(find.text('설정2')).dy),
    );
  });
}
