import 'dart:io';
import 'package:easy_lotto/domain/recommendation.dart';

void main() {
  final engine = RecommendationEngine();
  void check(bool condition) {
    if (!condition) throw StateError('Engine verification failed');
  }

  final games = engine.generate(
    RecommendationOptions(
      fixed: [1, 2, 3, 4, 5],
      excluded: [for (var n = 11; n <= 45; n++) n],
    ),
    count: 5,
  );
  check(games.toSet().length == 5);
  check(games.every((g) => g.numbers.last >= 6 && g.numbers.last <= 10));
  check(
    engine
            .generate(
              RecommendationOptions(
                fixed: [1, 2, 8, 9, 20, 40],
                groupCount: 2,
                groupLengths: [2, 2],
                oddCount: 2,
                lowCount: 5,
                minSum: 80,
                maxSum: 80,
              ),
            )
            .length ==
        1,
  );
  try {
    engine.generate(RecommendationOptions(fixed: [1, 2, 3, 4, 5, 6]), count: 2);
    throw StateError('Expected insufficient games');
  } on GenerationException catch (e) {
    check(e.availableGames == 1);
  }
  final draw = DrawResult(5, LottoGame([1, 2, 3, 4, 5, 6]), 7);
  check(
    engine
            .generate(
              RecommendationOptions(
                fixed: [1, 2, 3, 4, 5, 8],
                missingRounds: 1,
                missingCount: 1,
              ),
              draws: [draw],
            )
            .length ==
        1,
  );
  try {
    engine.generate(
      RecommendationOptions(fixed: [7], excludePrevious: true),
      draws: [draw],
    );
    throw StateError('Expected bonus conflict');
  } on GenerationException catch (e) {
    check(e.code == 'fixed_excluded');
  }
  stdout.writeln('Engine smoke checks passed');
  for (final options in [
    RecommendationOptions(),
    RecommendationOptions(oddCount: 3, lowCount: 3),
  ]) {
    final watch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      engine.generate(options, count: 5);
    }
    watch.stop();
    stdout.writeln('100 five-game requests: ${watch.elapsedMilliseconds} ms');
  }
}
