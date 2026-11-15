import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_storage.dart';
import 'domain/recommendation.dart';

class LotteryPaper {
  LotteryPaper(this.id, this.title, Iterable<LottoGame> games)
    : games = List.unmodifiable(
        games.map((g) => LottoGame(g.numbers, origin: g.origin)),
      ) {
    if (this.games.isEmpty || this.games.length > 5) {
      throw ArgumentError('용지는 1~5게임이어야 합니다.');
    }
  }
  final String id, title;
  final List<LottoGame> games;
  String get sourceSummary {
    final labels = games
        .map((g) => g.origin?.label ?? '기록 없음')
        .toSet()
        .toList();
    return labels.length == 1
        ? labels.single
        : '${labels.first} 외 ${labels.length - 1}개';
  }
}

class PaperStore extends ChangeNotifier {
  List<LotteryPaper> items = [];
  Future<void>? _pending;
  Future<void> load() async {
    final body = (await LocalStorage.getInstance()).getString('papers.v1');
    final loaded = body == null
        ? <LotteryPaper>[]
        : (jsonDecode(body) as List)
              .map(
                (p) => LotteryPaper(p['id'] as String, p['title'] as String, [
                  for (var i = 0; i < (p['games'] as List).length; i++)
                    LottoGame(
                      (p['games'][i] as List).cast<int>(),
                      origin: GameOrigin.fromJson((p['origins'] as List?)?[i]),
                    ),
                ]),
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
      if (!await (await LocalStorage.getInstance()).setString(
        'papers.v1',
        jsonEncode([
          for (final p in next)
            {
              'id': p.id,
              'title': p.title,
              'games': [for (final g in p.games) g.numbers],
              'origins': [for (final g in p.games) g.origin?.toJson()],
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

  Future<void> delete(String id) {
    Future<void> perform() async {
      final next = items.where((p) => p.id != id).toList();
      if (!await (await LocalStorage.getInstance()).setString(
        'papers.v1',
        jsonEncode([
          for (final p in next)
            {
              'id': p.id,
              'title': p.title,
              'games': [for (final g in p.games) g.numbers],
              'origins': [for (final g in p.games) g.origin?.toJson()],
            },
        ]),
      )) {
        throw StateError('용지 삭제 실패');
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
    return task;
  }
}

final paperStore = PaperStore();
