import 'dart:math';

/// Immutable, normalized six-number game.
class LottoGame {
  LottoGame(Iterable<int> values)
    : numbers = List.unmodifiable(values.toList()..sort()) {
    if (numbers.length != 6 ||
        numbers.toSet().length != 6 ||
        numbers.any((n) => n < 1 || n > 45)) {
      throw ArgumentError('번호는 1~45의 서로 다른 숫자 6개여야 합니다.');
    }
  }
  final List<int> numbers;
  @override
  bool operator ==(Object other) =>
      other is LottoGame && numbers.join(',') == other.numbers.join(',');
  @override
  int get hashCode => Object.hashAll(numbers);
}

class DrawResult {
  DrawResult(this.round, this.main, this.bonus) {
    if (round < 1 || bonus < 1 || bonus > 45 || main.numbers.contains(bonus)) {
      throw ArgumentError('회차 또는 보너스 번호가 올바르지 않습니다.');
    }
  }
  final int round;
  final LottoGame main;
  final int bonus;
  Set<int> numbers(bool includeBonus) => {
    ...main.numbers,
    if (includeBonus) bonus,
  };
}

class RecommendationOptions {
  RecommendationOptions({
    Iterable<int> fixed = const [],
    Iterable<int> excluded = const [],
    this.oddCount,
    this.lowCount,
    this.minSum = 21,
    this.maxSum = 255,
    this.groupCount,
    Iterable<int>? groupLengths,
    this.excludePrevious = false,
    this.previousIncludesBonus = true,
    this.missingCount,
    this.missingRounds = 5,
    this.missingIncludesBonus = true,
  }) : fixed = List.unmodifiable(fixed),
       excluded = List.unmodifiable(excluded),
       groupLengths = groupLengths == null
           ? null
           : List.unmodifiable(groupLengths.toList()..sort());
  final List<int> fixed, excluded;
  final int? oddCount, lowCount, groupCount, missingCount;
  final int minSum, maxSum, missingRounds;
  final List<int>? groupLengths;
  final bool excludePrevious, previousIncludesBonus, missingIncludesBonus;
}

class GenerationException implements Exception {
  GenerationException(this.code, this.message, {this.availableGames});
  final String code, message;
  final int? availableGames;
  @override
  String toString() => message;
}

/// Uniform random proposals, with complete reservoir search for tight constraints.
/// Run in a worker isolate when connected to Flutter; broad searches can be costly.
class RecommendationEngine {
  RecommendationEngine({Random? random}) : _random = random ?? Random();
  final Random _random;

  List<LottoGame> generate(
    RecommendationOptions o, {
    int count = 1,
    List<DrawResult> draws = const [],
    Set<LottoGame> excludedGames = const {},
  }) {
    Never fail(String code, String message) =>
        throw GenerationException(code, message);
    bool validNumbers(List<int> ns) =>
        ns.toSet().length == ns.length && ns.every((n) => n >= 1 && n <= 45);
    if (count < 1 ||
        count > 5 ||
        !validNumbers(o.fixed) ||
        !validNumbers(o.excluded) ||
        o.fixed.length > 6 ||
        o.excluded.length > 39 ||
        [o.oddCount, o.lowCount].any((n) => n != null && (n < 0 || n > 6)) ||
        o.minSum < 21 ||
        o.maxSum > 255 ||
        o.minSum > o.maxSum ||
        (o.groupCount != null && (o.groupCount! < 0 || o.groupCount! > 3)) ||
        (o.missingCount != null &&
            (o.missingCount! < 1 ||
                o.missingCount! > 6 ||
                o.missingRounds < 1 ||
                o.missingRounds > 100))) {
      fail('invalid_input', '옵션의 입력 범위를 확인하십시오.');
    }
    final lengths = o.groupLengths;
    if ((o.groupCount == 1 || o.groupCount == 2) &&
        lengths != null &&
        (lengths.length != o.groupCount ||
            lengths.any((n) => n < 2 || n > 6) ||
            lengths.fold<int>(0, (a, b) => a + b) > 6)) {
      fail('invalid_groups', '연속 묶음 길이를 확인하십시오.');
    }
    final history = draws.toList()..sort((a, b) => b.round.compareTo(a.round));
    final required = o.missingCount != null
        ? o.missingRounds
        : (o.excludePrevious ? 1 : 0);
    if (history.length < required) fail('missing_data', '필요한 추첨 데이터가 부족합니다.');
    for (var i = 1; i < required; i++) {
      if (history[i - 1].round - history[i].round != 1) {
        fail('missing_data', '최근 회차 데이터에 중복 또는 누락이 있습니다.');
      }
    }
    final excluded = o.excluded.toSet();
    if (o.excludePrevious) {
      excluded.addAll(history.first.numbers(o.previousIncludesBonus));
    }
    if (o.fixed.any(excluded.contains)) {
      fail('fixed_excluded', '고정수가 제외 조건과 충돌합니다.');
    }
    final missing = {for (var n = 1; n <= 45; n++) n};
    if (o.missingCount != null) {
      for (final draw in history.take(required)) {
        missing.removeAll(draw.numbers(o.missingIncludesBonus));
      }
    }
    final candidates = [
      for (var n = 1; n <= 45; n++)
        if (!excluded.contains(n) && !o.fixed.contains(n)) n,
    ];
    final needed = 6 - o.fixed.length;
    if (candidates.length < needed) {
      fail('insufficient_numbers', '번호를 완성할 후보가 부족합니다.');
    }
    final chosen = <int>[];
    final reservoir = <LottoGame>[];
    var total = 0;
    bool accepts(List<int> ns) {
      if (o.oddCount != null && ns.where((n) => n.isOdd).length != o.oddCount) {
        return false;
      }
      if (o.lowCount != null && ns.where((n) => n <= 22).length != o.lowCount) {
        return false;
      }
      final sum = ns.fold<int>(0, (a, b) => a + b);
      if (sum < o.minSum || sum > o.maxSum) return false;
      if (o.missingCount != null &&
          ns.where(missing.contains).length != o.missingCount) {
        return false;
      }
      if (o.groupCount != null) {
        final groups = <int>[];
        var run = 1;
        for (var i = 1; i <= ns.length; i++) {
          if (i < ns.length && ns[i] == ns[i - 1] + 1) {
            run++;
          } else {
            if (run >= 2) groups.add(run);
            run = 1;
          }
        }
        groups.sort();
        if (groups.length != o.groupCount) return false;
        if ((o.groupCount == 1 || o.groupCount == 2) &&
            lengths != null &&
            groups.join(',') != lengths.join(',')) {
          return false;
        }
      }
      return true;
    }

    // Bounded rejection sampling is fast for ordinary settings. Each shuffle
    // proposes a uniformly selected subset; repeated games are discarded.
    final quick = <LottoGame>{};
    final shuffled = candidates.toList();
    for (var attempt = 0; attempt < 1000; attempt++) {
      shuffled.shuffle(_random);
      final ns = [...o.fixed, ...shuffled.take(needed)]..sort();
      if (!accepts(ns)) continue;
      final game = LottoGame(ns);
      if (!excludedGames.contains(game)) quick.add(game);
      if (quick.length == count) return List.unmodifiable(quick);
    }
    // Start afresh: exhausting proposals is not evidence of impossibility.
    void visit(int start) {
      if (chosen.length == needed) {
        final ns = [...o.fixed, ...chosen]..sort();
        if (!accepts(ns)) return;
        final game = LottoGame(ns);
        if (excludedGames.contains(game)) return;
        total++;
        if (reservoir.length < count) {
          reservoir.add(game);
        } else {
          final index = _random.nextInt(total);
          if (index < count) reservoir[index] = game;
        }
        return;
      }
      final remaining = needed - chosen.length;
      for (var i = start; i <= candidates.length - remaining; i++) {
        chosen.add(candidates[i]);
        visit(i + 1);
        chosen.removeLast();
      }
    }

    visit(0);
    if (total < count) {
      throw GenerationException(
        'insufficient_games',
        '조건을 만족하는 고유 게임은 $total개입니다.',
        availableGames: total,
      );
    }
    reservoir.shuffle(_random);
    return List.unmodifiable(reservoir);
  }
}
