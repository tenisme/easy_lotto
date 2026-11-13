import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/domain/recommendation.dart';
import 'package:easy_lotto/exit_guard.dart';
import 'package:easy_lotto/library.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:easy_lotto/main.dart';
import 'package:easy_lotto/paper_store.dart';
import 'package:easy_lotto/paper_view.dart';

void main() {
  final game = LottoGame([1, 11, 21, 31, 41, 45]);
  setUp(() {
    LocalStorage.testValues = {};
    paperStore.items = [];
    libraryStore.games = [];
    libraryStore.numbers = {};
  });

  void checkCentered(WidgetTester tester, String label) {
    final text = find.text(label);
    expect(tester.widget<Text>(text).textAlign, TextAlign.center);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.textAlign, TextAlign.center);
    final button = find
        .ancestor(
          of: text,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        )
        .first;
    expect(
      (tester.getCenter(text) - tester.getCenter(button)).distance,
      lessThan(0.5),
    );
    final painter = TextPainter(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: MediaQuery.textScalerOf(tester.element(text)),
    )..layout(maxWidth: paragraph.size.width);
    for (final line in painter.computeLineMetrics()) {
      expect(line.left + line.width / 2, closeTo(painter.width / 2, 0.5));
    }
    painter.dispose();
  }

  testWidgets(
    'large-text paper footer centers every wrapped line without shrinking text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (await LocalStorage.getInstance()).setBool(
        'largeViewIntro.v1',
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: PaperView(
              paper: LotteryPaper('p', '용지', [game]),
              setAwake: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      checkCentered(tester, '스타일 변경');
      checkCentered(tester, '용지 내용 편집');
      final p = tester.renderObject<RenderParagraph>(find.text('용지 내용 편집'));
      expect(p.size.height, greaterThan(50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long result action stays centered at large accessibility size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: RecommendationResults(initialGames: [game]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('선택한 게임 복권 용지에 저장'), 250);
    await tester.pumpAndSettle();
    checkCentered(tester, '선택한 게임 복권 용지에 저장');
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmation action labels also center when wrapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmResultLoss(
                context,
                message: '안내',
                suppressionKey: null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    checkCentered(tester, '결과로 돌아가기');
    checkCentered(tester, '저장하지 않고 이동');
    expect(tester.takeException(), isNull);
  });
}
