import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/domain/recommendation.dart';

void main() {
  test('ordinary five-game generation is valid and unique', () {
    for (var seed = 0; seed < 30; seed++) {
      final games = RecommendationEngine(
        random: Random(seed),
      ).generate(RecommendationOptions(oddCount: 3, lowCount: 3), count: 5);
      expect(games.toSet().length, 5);
      for (final game in games) {
        expect(game.numbers.where((n) => n.isOdd).length, 3);
        expect(game.numbers.where((n) => n <= 22).length, 3);
      }
    }
  });
  final engine = RecommendationEngine(random: Random(42));
  test('game normalizes numbers and rejects duplicates', () {
    expect(LottoGame([6, 5, 4, 3, 2, 1]).numbers, [1, 2, 3, 4, 5, 6]);
    expect(() => LottoGame([1, 1, 2, 3, 4, 5]), throwsArgumentError);
  });
  test('all eligible games are returned without duplicates', () {
    final games = engine.generate(
      RecommendationOptions(
        fixed: [1, 2, 3, 4, 5],
        excluded: [for (var n = 11; n <= 45; n++) n],
      ),
      count: 5,
    );
    expect(games.toSet().length, 5);
    expect(games.map((g) => g.numbers.last).toSet(), {6, 7, 8, 9, 10});
  });
  test('maximal consecutive runs and combined constraints', () {
    final options = RecommendationOptions(
      fixed: [1, 2, 8, 9, 20, 40],
      groupCount: 2,
      groupLengths: [2, 2],
      oddCount: 2,
      lowCount: 5,
      minSum: 80,
      maxSum: 80,
    );
    expect(engine.generate(options).single.numbers, [1, 2, 8, 9, 20, 40]);
    expect(
      () => engine.generate(
        RecommendationOptions(fixed: [1, 2, 3, 8, 20, 40], groupCount: 2),
      ),
      throwsA(isA<GenerationException>()),
    );
  });
  test('bonus scope changes previous-number exclusion', () {
    final draw = DrawResult(5, LottoGame([16, 24, 29, 40, 41, 42]), 3);
    expect(
      () => engine.generate(
        RecommendationOptions(fixed: [3], excludePrevious: true),
        draws: [draw],
      ),
      throwsA(isA<GenerationException>()),
    );
    expect(
      engine
          .generate(
            RecommendationOptions(
              fixed: [1, 2, 3, 4, 5, 6],
              excludePrevious: true,
              previousIncludesBonus: false,
            ),
            draws: [draw],
          )
          .length,
      1,
    );
  });
  test('missing count uses consecutive history', () {
    final draws = [
      DrawResult(5, LottoGame([1, 2, 3, 4, 5, 6]), 7),
    ];
    expect(
      engine
          .generate(
            RecommendationOptions(
              fixed: [1, 2, 3, 4, 5, 8],
              missingCount: 1,
              missingRounds: 1,
            ),
            draws: draws,
          )
          .length,
      1,
    );
    expect(
      () => engine.generate(
        RecommendationOptions(missingCount: 1, missingRounds: 2),
        draws: draws,
      ),
      throwsA(isA<GenerationException>()),
    );
  });
  test('impossible unique-game count reports exact availability', () {
    expect(
      () => engine.generate(
        RecommendationOptions(fixed: [1, 2, 3, 4, 5, 6]),
        count: 2,
      ),
      throwsA(
        isA<GenerationException>().having(
          (e) => e.availableGames,
          'available',
          1,
        ),
      ),
    );
  });
}
