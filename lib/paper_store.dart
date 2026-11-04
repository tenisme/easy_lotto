import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/recommendation.dart';

class LotteryPaper {
  LotteryPaper(this.id, this.title, Iterable<LottoGame> games)
    : games = List.unmodifiable(games.map((g) => LottoGame(g.numbers))) {
    if (this.games.isEmpty || this.games.length > 5) {
      throw ArgumentError('용지는 1~5게임이어야 합니다.');
    }
  }
  final String id, title;
  final List<LottoGame> games;
}

class PaperStore extends ChangeNotifier {
  List<LotteryPaper> items = [];
  Future<void>? _pending;
  Future<void> load() async {
    final body = (await SharedPreferences.getInstance()).getString('papers.v1');
    final loaded = body == null
        ? <LotteryPaper>[]
        : (jsonDecode(body) as List)
              .map(
                (p) => LotteryPaper(
                  p['id'] as String,
                  p['title'] as String,
                  (p['games'] as List).map(
                    (ns) => LottoGame((ns as List).cast<int>()),
                  ),
                ),
              )
              .toList();
    items = loaded;
    notifyListeners();
  }

  String defaultName() {
    var n = 1;
    while (items.any((p) => p.title == '복권 용지 $n')) {
      n++;
    }
    return '복권 용지 $n';
  }

  Future<LotteryPaper> save(
    String title,
    List<LottoGame> games, {
    String? id,
  }) async {
    late LotteryPaper saved;
    Future<void> perform() async {
      saved = LotteryPaper(
        id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title.trim().isEmpty ? defaultName() : title.trim(),
        games,
      );
      final next = [
        for (final p in items)
          if (p.id != saved.id) p,
        saved,
      ];
      if (!await (await SharedPreferences.getInstance()).setString(
        'papers.v1',
        jsonEncode([
          for (final p in next)
            {
              'id': p.id,
              'title': p.title,
              'games': [for (final g in p.games) g.numbers],
            },
        ]),
      )) {
        throw StateError('용지 저장 실패');
      }
      items = next;
      notifyListeners();
    }

    final task = _pending == null
        ? perform()
        : _pending!.then((_) => perform());
    final tail = task.catchError((Object _) {});
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    await task;
    return saved;
  }
}

final paperStore = PaperStore();
