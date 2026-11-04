import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/settings_editor.dart';
import 'package:easy_lotto/preset_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/local_storage.dart';

void main() {
  testWidgets('bottom navigation opens all four library categories', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '보관함'));
    await tester.pumpAndSettle();
    expect(find.text('내 번호'), findsOneWidget);
    expect(find.text('저장한 설정'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, '더보기'));
    await tester.pumpAndSettle();
    expect(find.text('번호 추천 방식 안내'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, '추천'));
    await tester.pumpAndSettle();
    expect(find.text('몇 게임을 만들까요?'), findsOneWidget);
  });
  testWidgets('switching result settings can be cancelled before replacement', (
    tester,
  ) async {
    final first = await presetStore.save(RecommendationOptions(), name: '기존');
    await presetStore.save(RecommendationOptions(oddCount: 3), name: '다른');
    await tester.pumpWidget(
      MaterialApp(
        home: RecommendationResults(
          initialGames: [
            LottoGame([1, 2, 3, 4, 5, 6]),
          ],
          options: first.options,
          presetId: first.id,
        ),
      ),
    );
    await tester.tap(find.text('다른 설정 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다른'));
    await tester.pumpAndSettle();
    expect(find.text('새 번호를 생성하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('기존 결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('기존 · 1게임'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    presetStore.items = [];
    presetStore.selectedId = null;
    libraryStore.numbers = {};
    libraryStore.games = [];
    paperStore.items = [];
    LocalStorage.testValues = {};
  });
  testWidgets('dirty editor back warns and cancel keeps draft', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsEditor()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1묶음'));
    await tester.tap(find.text('1묶음'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 이동'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하지 않고 이동'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsNothing);
  });
  testWidgets('result saves hearts and combinations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecommendationResults(
          initialGames: [
            LottoGame([1, 2, 3, 4, 5, 6]),
          ],
        ),
      ),
    );
    await tester.tap(find.byTooltip('3 내 번호 저장'));
    await tester.pumpAndSettle();
    expect(libraryStore.numbers, {3});
    await tester.tap(find.text('조합 저장'));
    await tester.pumpAndSettle();
    expect(libraryStore.games.length, 1);
    expect(find.text('저장된 조합'), findsOneWidget);
  });
  testWidgets('result warns on back until its game is saved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RecommendationResults(
                  initialGames: [
                    LottoGame([1, 2, 3, 4, 5, 6]),
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 이동'), findsOneWidget);
    await tester.tap(find.text('결과로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('조합 저장'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(RecommendationResults), findsNothing);
    expect(libraryStore.games.length, 1);
  });
  testWidgets(
    'generating a dirty draft returns options without abandonment dialog',
    (tester) async {
      RecommendationOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<RecommendationOptions>(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsEditor()),
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('번호 생성'));
      await tester.pumpAndSettle();
      expect(result?.groupCount, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('save stays in editor and restores preset on home', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.text('상세 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsOneWidget);
    expect(presetStore.items.single.name, '설정1');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('설정1'), findsOneWidget);
    expect(find.text('설정 수정'), findsOneWidget);
    expect(find.text('번호 생성'), findsOneWidget);
  });
  testWidgets('detailed mode opens a temporary settings editor', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.text('상세 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 만들기'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsOneWidget);
    expect(find.text('고정수'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('설정 만들기'), findsOneWidget);
  });
  testWidgets('consecutive controls hide and restore lengths', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsEditor(
          initial: RecommendationOptions(groupCount: 1, groupLengths: [4]),
        ),
      ),
    );
    await tester.ensureVisible(find.text('1묶음'));
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('3묶음'));
    await tester.pumpAndSettle();
    expect(find.text('연속 묶음 구성'), findsNothing);
    await tester.tap(find.text('1묶음'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
  });
  testWidgets('home supports choosing five games', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '5')).selected,
      isTrue,
    );
    expect(find.text('번호 생성'), findsOneWidget);
  });
  testWidgets('regeneration can be cancelled without losing results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecommendationResults(
          initialGames: [
            LottoGame([1, 2, 3, 4, 5, 6]),
          ],
        ),
      ),
    );
    await tester.tap(find.text('다시 생성'));
    await tester.pumpAndSettle();
    expect(find.text('새 번호를 생성하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('기존 결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
