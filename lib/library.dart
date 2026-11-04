import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/recommendation.dart';
import 'preset_store.dart';

class SavedGame {
  SavedGame(this.game, this.options);
  final LottoGame game;
  final RecommendationOptions? options;
}

class LibraryStore extends ChangeNotifier {
  Set<int> numbers = {};
  List<SavedGame> games = [];
  Future<void>? _pending;
  Future<void> load() async {
    final body = (await SharedPreferences.getInstance()).getString(
      'library.v1',
    );
    if (body == null) {
      numbers = {};
      games = [];
      return;
    }
    final j = jsonDecode(body) as Map<String, dynamic>;
    final restoredNumbers = (j['numbers'] as List).cast<int>().toSet();
    if (restoredNumbers.any((n) => n < 1 || n > 45)) {
      throw const FormatException('번호 범위 오류');
    }
    final restoredGames = (j['games'] as List)
        .map(
          (g) => SavedGame(
            LottoGame((g['numbers'] as List).cast<int>()),
            g['options'] == null
                ? null
                : decodeOptions(g['options'] as Map<String, dynamic>),
          ),
        )
        .toList();
    numbers = restoredNumbers;
    games = restoredGames;
    notifyListeners();
  }

  bool contains(LottoGame game) => games.any((g) => g.game == game);
  Future<void> _change(void Function(Set<int>, List<SavedGame>) change) {
    Future<void> perform() async {
      final ns = {...numbers};
      final gs = [...games];
      change(ns, gs);
      final body = jsonEncode({
        'numbers': ns.toList()..sort(),
        'games': [
          for (final g in gs)
            {
              'numbers': g.game.numbers,
              'options': g.options == null ? null : encodeOptions(g.options!),
            },
        ],
      });
      if (!await (await SharedPreferences.getInstance()).setString(
        'library.v1',
        body,
      )) {
        throw StateError('저장 실패');
      }
      numbers = ns;
      games = gs;
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

  Future<void> toggleNumber(int n) => _change((ns, _) {
    if (n < 1 || n > 45) throw ArgumentError('번호 범위 오류');
    if (!ns.add(n)) ns.remove(n);
  });
  Future<void> saveGame(LottoGame game, RecommendationOptions? options) =>
      _change((_, gs) {
        if (!gs.any((g) => g.game == game)) gs.add(SavedGame(game, options));
      });
  Future<void> removeGame(LottoGame game) =>
      _change((_, gs) => gs.removeWhere((g) => g.game == game));
}

final libraryStore = LibraryStore();

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('보관함'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '내 번호'),
            Tab(text: '저장한 조합'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: libraryStore,
        builder: (context, _) => TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: libraryStore.numbers.isEmpty
                  ? const Text('저장한 번호가 없습니다.')
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (final n in (libraryStore.numbers.toList()..sort()))
                          Chip(label: Text('$n')),
                      ],
                    ),
            ),
            libraryStore.games.isEmpty
                ? const Center(child: Text('저장한 조합이 없습니다.'))
                : ListView(
                    children: [
                      for (final saved in libraryStore.games)
                        ListTile(
                          title: Text(saved.game.numbers.join(' · ')),
                          subtitle: Text(
                            saved.options == null ? '완전 랜덤' : '상세 설정',
                          ),
                          trailing: IconButton(
                            tooltip: '조합 삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('조합을 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes != true) return;
                              try {
                                await libraryStore.removeGame(saved.game);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('삭제에 실패했습니다.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
          ],
        ),
      ),
    ),
  );
}
