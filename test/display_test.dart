import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/domain/recommendation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final paper = LotteryPaper('p', '복권 용지 1', [
    LottoGame([3, 11, 17, 24, 32, 42]),
  ]);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    paperStore.items = [];
  });
  test(
    'global, override fallback and random retain previous selections',
    () async {
      final p = DisplayPreferences(
        mode: DesignMode.random,
        defaultDesign: PaperDesign.spacious,
        overrides: {'p': PaperDesign.cards},
      );
      await p.save();
      final restored = await DisplayPreferences.load();
      expect(restored.defaultDesign, PaperDesign.spacious);
      expect(restored.overrides['p'], PaperDesign.cards);
      final per = DisplayPreferences(
        mode: DesignMode.perPaper,
        defaultDesign: restored.defaultDesign,
        overrides: restored.overrides,
      );
      expect(per.resolve('p', Random(1)), PaperDesign.cards);
      expect(per.resolve('other', Random(1)), PaperDesign.spacious);
      final rng = Random(3);
      expect(
        {for (var i = 0; i < 30; i++) restored.resolve('p', rng)}.length,
        3,
      );
    },
  );
  testWidgets(
    'intro appears over paper view only on first acknowledged visit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaperView(paper: paper, setAwake: (_) async {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GameDisplay, skipOffstage: false), findsOneWidget);
      expect(
        find.text('이 화면에서는 저장한 복권 용지를 실제 종이 복권에 편하게 옮겨 적을 수 있습니다.'),
        findsOneWidget,
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: PaperView(paper: paper, setAwake: (_) async {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('random stays stable on rebuild and wakelock releases on exit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'largeViewIntro.v1': true});
    await DisplayPreferences(mode: DesignMode.random).save();
    final calls = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PaperView(
          paper: paper,
          setAwake: (v) async {
            calls.add(v);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final design = tester.widget<GameDisplay>(find.byType(GameDisplay)).design;
    await tester.tap(find.text('화면 계속 켜기'));
    await tester.pumpAndSettle();
    expect(calls.last, isTrue);
    expect(tester.widget<GameDisplay>(find.byType(GameDisplay)).design, design);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls.last, isFalse);
  });
  testWidgets('all designs fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final design in PaperDesign.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GameDisplay(
                  label: 'A',
                  numbers: paper.games.single.numbers,
                  design: design,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('random mode disables editors without disabling mode switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DesignSettings(paperId: 'p')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('열 때마다 랜덤'));
    await tester.pumpAndSettle();
    final dropdowns = tester.widgetList<DropdownButtonFormField<PaperDesign>>(
      find.byType(DropdownButtonFormField<PaperDesign>),
    );
    expect(dropdowns.single.onChanged, isNull);
    await tester.tap(find.text('기본 디자인').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<PaperDesign>>(
            find.byType(DropdownButtonFormField<PaperDesign>),
          )
          .onChanged,
      isNotNull,
    );
  });
}
