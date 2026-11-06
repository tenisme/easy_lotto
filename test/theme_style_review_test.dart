import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/app_theme.dart';
import 'package:easy_lotto/banner_scaffold.dart';
import 'package:easy_lotto/display_preferences.dart';
import 'package:easy_lotto/draw_source.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/exit_guard.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/paper_flow.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_view.dart';
import 'package:easy_lotto/preset_store.dart';

void main() {
  final game = LottoGame([1, 4, 11, 17, 29, 42]);
  setUp(() {
    LocalStorage.testValues = {};
    libraryStore.games = [];
    libraryStore.numbers = {};
    paperStore.items = [];
    presetStore.items = [];
    presetStore.selectedId = null;
  });

  testWidgets('paper help persists until explicitly dismissed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => saveResultsToPaper(context, [game], []),
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('복권 용지 선택 안내'));
    await tester.pumpAndSettle();
    final content = tester.widget<Text>(find.textContaining('이미 5게임이 채워진'));
    expect(
      content.data!.indexOf('이미 5게임'),
      lessThan(content.data!.indexOf('기존 복권 용지')),
    );
    await tester.pump(const Duration(seconds: 15));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('복권 용지 선택'), findsOneWidget);
  });

  for (final action in ['stay', 'leave', 'outside']) {
    testWidgets('suppress persists independently of $action', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmResultLoss(
                    context,
                    message: '결과가 사라집니다.',
                    stay: '계속 보기',
                    leave: '이동',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 보지 않기'));
      await tester.pump();
      if (action == 'outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(action == 'stay' ? '계속 보기' : '이동'));
      }
      await tester.pumpAndSettle();
      expect(result, action == 'leave');
      expect(
        (await LocalStorage.getInstance()).getBool('resultLossNotice.v1'),
        true,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('unchecking suppression leaves warning enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmResultLoss(context, message: '안내'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 보지 않기'));
    await tester.pump();
    await tester.tap(find.text('다시 보지 않기'));
    await tester.pump();
    await tester.tap(find.text('결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(
      (await LocalStorage.getInstance()).getBool('resultLossNotice.v1'),
      isNot(true),
    );
  });

  test('app theme persists independently of paper preferences', () async {
    await DisplayPreferences(defaultDesign: PaperDesign.cards).save();
    final theme = AppThemeController();
    await theme.load();
    expect(theme.mode, ThemeMode.system);
    for (final m in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
      expect(await theme.select(m), true);
      final restored = AppThemeController();
      await restored.load();
      expect(restored.mode, m);
      restored.dispose();
    }
    expect((await DisplayPreferences.load()).defaultDesign, PaperDesign.cards);
    theme.dispose();
  });

  testWidgets('More selects app theme and system tracks device brightness', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(TestAdBanner), findsOneWidget);
    final picker = find.byType(DropdownButtonFormField<ThemeMode>);
    expect(Theme.of(tester.element(picker)).brightness, Brightness.dark);
    tester.widget<DropdownButtonFormField<ThemeMode>>(picker).onChanged!(
      ThemeMode.light,
    );
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(picker)).brightness, Brightness.light);
    tester.widget<DropdownButtonFormField<ThemeMode>>(picker).onChanged!(
      ThemeMode.dark,
    );
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(picker)).brightness, Brightness.dark);
    tester.widget<DropdownButtonFormField<ThemeMode>>(picker).onChanged!(
      ThemeMode.system,
    );
    await tester.pumpAndSettle();
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(picker)).brightness, Brightness.light);
    await tester.tap(find.widgetWithText(NavigationDestination, '보관함'));
    await tester.pumpAndSettle();
    expect(find.byType(TestAdBanner), findsOneWidget);
  });

  test('legacy global random and added per-paper random round-trip', () async {
    await (await LocalStorage.getInstance()).setString(
      'display.v1',
      jsonEncode({
        'mode': 'random',
        'default': 'spacious',
        'overrides': {'a': 'cards'},
      }),
    );
    final legacy = await DisplayPreferences.load();
    expect(legacy.mode, DesignMode.random);
    expect(legacy.randomPapers, isEmpty);
    final prefs = DisplayPreferences(
      mode: DesignMode.perPaper,
      defaultDesign: legacy.defaultDesign,
      overrides: legacy.overrides,
      randomPapers: {'a'},
      beforeRandomMode: DesignMode.perPaper,
    );
    await prefs.save();
    final loaded = await DisplayPreferences.load();
    expect(loaded.resolve('b', Random(1)), PaperDesign.spacious);
    final random = Random(4);
    expect(
      {for (var i = 0; i < 30; i++) loaded.resolve('a', random)}.length,
      3,
    );
    expect(loaded.overrides['a'], PaperDesign.cards);
  });

  testWidgets(
    'current paper random preserves other papers and restores local style',
    (tester) async {
      await DisplayPreferences(
        mode: DesignMode.perPaper,
        defaultDesign: PaperDesign.spacious,
        overrides: {'a': PaperDesign.cards, 'b': PaperDesign.basic},
      ).save();
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'a')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('열 때마다 랜덤'));
      await tester.pump();
      await tester.tap(find.text('현재 용지에만 적용'));
      await tester.pump();
      await tester.tap(find.text('변경 완료'));
      await tester.pumpAndSettle();
      var prefs = await DisplayPreferences.load();
      expect(prefs.mode, DesignMode.perPaper);
      expect(prefs.randomPapers, {'a'});
      expect(prefs.resolve('b', Random()), PaperDesign.basic);
      expect(prefs.resolve('c', Random()), PaperDesign.spacious);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'a')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioListTile<bool>>(
              find.widgetWithText(RadioListTile<bool>, '현재 용지에만 적용'),
            )
            .value,
        false,
      );
      await tester.tap(find.text('용지별 디자인'));
      await tester.pump();
      await tester.tap(find.text('변경 완료'));
      await tester.pumpAndSettle();
      prefs = await DisplayPreferences.load();
      expect(prefs.randomPapers, isEmpty);
      expect(prefs.resolve('a', Random()), PaperDesign.cards);
    },
  );

  testWidgets('global random switching to current restores other papers mode', (
    tester,
  ) async {
    await DisplayPreferences(
      mode: DesignMode.random,
      beforeRandomMode: DesignMode.perPaper,
      defaultDesign: PaperDesign.spacious,
      overrides: {'b': PaperDesign.cards},
    ).save();
    await tester.pumpWidget(
      const MaterialApp(home: DesignSettings(paperId: 'a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('현재 용지에만 적용'));
    await tester.pump();
    await tester.tap(find.text('변경 완료'));
    await tester.pumpAndSettle();
    final prefs = await DisplayPreferences.load();
    expect(prefs.mode, DesignMode.perPaper);
    expect(prefs.randomPapers, {'a'});
    expect(prefs.resolve('b', Random()), PaperDesign.cards);
    expect(prefs.resolve('c', Random()), PaperDesign.spacious);
  });

  for (final label in ['배경 이미지 변경', '번호 칸 디자인 변경']) {
    testWidgets('$label is a three-second placeholder without navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DesignSettings(paperId: 'a')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('스타일 상세 설정'));
      await tester.pumpAndSettle();
      expect(find.text('배경 이미지 변경'), findsOneWidget);
      expect(find.text('번호 칸 디자인 변경'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('업데이트 예정입니다'), findsOneWidget);
      expect(find.byType(DesignSettings), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('업데이트 예정입니다'), findsNothing);
      expect(
        (await LocalStorage.getInstance()).getString('display.v1'),
        isNull,
      );
    });
  }

  testWidgets('source only links attribution and omits stored count', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrawSource(
            round: 1248,
            status: '1248회 기준 · 1248회 저장',
            open: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('1248회 기준'), findsOneWidget);
    expect(find.textContaining('1248회 저장'), findsNothing);
    expect(find.widgetWithText(TextButton, '출처 - 동행복권'), findsOneWidget);
    await tester.tap(find.text('출처 - 동행복권'));
    await tester.pumpAndSettle();
    expect(opened, Uri.parse('https://www.dhlottery.co.kr/'));
  });

  testWidgets(
    'banner sits below safe area, above title and remains behind modal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: Builder(
              builder: (context) => BannerScaffold(
                appBar: AppBar(title: const Text('제목')),
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) =>
                        const AlertDialog(content: Text('모달 안내')),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final banner = find.byType(TestAdBanner);
      expect(tester.getTopLeft(banner).dy, 24);
      expect(tester.getSize(banner).height, 50);
      expect(
        tester.getTopLeft(find.text('제목')).dy,
        greaterThan(tester.getBottomRight(banner).dy),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(banner));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TestAdBanner), findsOneWidget);
    },
  );

  test('three advertising image assets are bundled locally', () async {
    for (final name in ['mint', 'peach', 'blue']) {
      final data = await rootBundle.load('assets/test_ads/$name.png');
      expect(data.getUint8(0), 137);
      expect(data.lengthInBytes, greaterThan(100));
    }
  });

  testWidgets(
    'dark paper numbers use theme colors and fit narrow large-text layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      );
      for (final design in PaperDesign.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BannerScaffold(
                appBar: AppBar(title: const Text('번호 크게 보기')),
                body: SingleChildScrollView(
                  child: GameDisplay(
                    label: 'A',
                    numbers: game.numbers,
                    design: design,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('42')).style!.color,
          theme.colorScheme.onSurface,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
