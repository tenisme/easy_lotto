import 'dart:convert';
import 'package:flutter/material.dart';
import 'local_storage.dart';
import 'domain/recommendation.dart';
import 'preset_store.dart';
import 'paper_store.dart';
import 'paper_flow.dart';
import 'paper_view.dart';
import 'settings_editor.dart';
import 'collection_order.dart';

class SavedGame {
  SavedGame(this.game, this.options, {String? source})
    : source = source ?? (options == null ? 'random' : 'configured');
  final LottoGame game;
  final RecommendationOptions? options;
  final String source;
}

class LibraryStore extends ChangeNotifier {
  Set<int> numbers = {};
  List<SavedGame> games = [];
  Future<void>? _pending;
  Future<void> load() async {
    final body = (await LocalStorage.getInstance()).getString('library.v1');
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
            source: g['source'] as String?,
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
              'source': g.source,
              'options': g.options == null ? null : encodeOptions(g.options!),
            },
        ],
      });
      if (!await (await LocalStorage.getInstance()).setString(
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
  Future<void> removeNumbers(Set<int> values) =>
      _change((ns, _) => ns.removeAll(values));
  Future<void> editGame(LottoGame? old, LottoGame next) => _change((_, gs) {
    if (gs.any((g) => g.game == next && g.game != old)) {
      throw ArgumentError('이미 저장한 조합입니다.');
    }
    if (old != null) gs.removeWhere((g) => g.game == old);
    gs.add(SavedGame(next, null, source: 'manual'));
  });
}

final libraryStore = LibraryStore();

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    this.draws = const [],
    this.onGenerate,
    this.generationCount = 1,
  });
  final List<DrawResult> draws;
  final int generationCount;
  final Future<void> Function(RecommendationOptions, String?)? onGenerate;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<DrawResult> get draws => widget.draws;
  final selectedNumbers = <int>{};
  final selectedGames = <LottoGame>{};
  bool changing = false;
  Future<void> editPreset([Preset? preset]) async {
    var id = preset?.id;
    final options = await Navigator.push<RecommendationOptions>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsEditor(
          initial: preset?.options,
          presetId: id,
          draws: draws,
          generationCount: widget.generationCount,
          onSaved: (p) => id = p.id,
        ),
      ),
    );
    if (mounted && options != null) await widget.onGenerate?.call(options, id);
  }

  Future<void> action(Future<void> Function() task) async {
    if (changing) return;
    changing = true;
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ArgumentError ? e.message.toString() : '변경 사항을 저장하지 못했습니다.',
            ),
          ),
        );
      }
    } finally {
      changing = false;
    }
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> editGame([LottoGame? old]) async {
    final next = await Navigator.push<LottoGame>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GameComposer(initialGame: old, draws: draws, actionLabel: '조합 저장'),
      ),
    );
    if (next != null) await action(() => libraryStore.editGame(old, next));
    if (mounted) {
      setState(
        () => selectedGames.removeWhere((g) => !libraryStore.contains(g)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('보관함'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: '내 번호'),
            Tab(text: '저장한 조합'),
            Tab(text: '복권 용지'),
            Tab(text: '저장한 설정'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([libraryStore, paperStore, presetStore]),
        builder: (context, _) => TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: libraryStore.numbers.isEmpty
                  ? const Text('저장한 번호가 없습니다.')
                  : Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final n
                                in (libraryStore.numbers.toList()..sort()))
                              FilterChip(
                                showCheckmark: false,
                                label: Text('$n'),
                                selected: selectedNumbers.contains(n),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    selectedNumbers.add(n);
                                  } else {
                                    selectedNumbers.remove(n);
                                  }
                                }),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed: selectedNumbers.isEmpty
                              ? null
                              : () async {
                                  if (await confirm('선택한 번호를 삭제하시겠습니까?')) {
                                    await action(
                                      () => libraryStore.removeNumbers({
                                        ...selectedNumbers,
                                      }),
                                    );
                                    if (mounted) {
                                      setState(() => selectedNumbers.clear());
                                    }
                                  }
                                },
                          child: const Text('선택 번호 삭제'),
                        ),
                      ],
                    ),
            ),
            ListView(
              children: [
                TextButton(onPressed: editGame, child: const Text('조합 직접 추가')),
                if (libraryStore.games.isEmpty) const Text('저장한 조합이 없습니다.'),
                TextButton(
                  onPressed: selectedGames.isEmpty || selectedGames.length > 5
                      ? null
                      : () => saveResultsToPaper(
                          context,
                          selectedGames.toList(),
                          draws,
                        ),
                  child: const Text('선택 조합으로 복권 용지 만들기'),
                ),
                CollectionOrder<SavedGame>(
                  storageKey: 'order.games.v1',
                  items: libraryStore.games,
                  id: (g) => g.game.numbers.join(','),
                  builder: (saved) => ListTile(
                    leading: Checkbox(
                      value: selectedGames.contains(saved.game),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          selectedGames.add(saved.game);
                        } else {
                          selectedGames.remove(saved.game);
                        }
                      }),
                    ),
                    onTap: () => editGame(saved.game),
                    title: Text(saved.game.numbers.join(' · ')),
                    subtitle: Text(
                      saved.source == 'manual'
                          ? '직접 입력'
                          : saved.options == null
                          ? '완전 랜덤'
                          : '상세 규칙',
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
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true) return;
                        try {
                          await libraryStore.removeGame(saved.game);
                          if (mounted) {
                            setState(() => selectedGames.remove(saved.game));
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('삭제에 실패했습니다.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PaperEditor(draws: draws),
                    ),
                  ),
                  child: const Text('새 복권 용지'),
                ),
                CollectionOrder<LotteryPaper>(
                  storageKey: 'order.papers.v1',
                  items: paperStore.items,
                  id: (p) => p.id,
                  name: (p) => p.title,
                  builder: (p) => Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(p.title),
                          subtitle: Text('${p.games.length}게임'),
                          trailing: IconButton(
                            tooltip: '용지 삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await confirm('이 복권 용지를 삭제하시겠습니까?')) {
                                await action(() => paperStore.delete(p.id));
                              }
                            },
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PaperEditor(paper: p, draws: draws),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PaperView(paper: p, draws: draws),
                                ),
                              ),
                              child: const Text('번호 크게 보기'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              children: [
                TextButton(onPressed: editPreset, child: const Text('새 설정')),
                CollectionOrder<Preset>(
                  storageKey: 'order.presets.v1',
                  items: presetStore.items,
                  id: (p) => p.id,
                  name: (p) => p.name,
                  builder: (p) => ListTile(
                    title: Text(p.name),
                    onTap: () => editPreset(p),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'copy') {
                          await action(() async {
                            await presetStore.save(p.options);
                          });
                        }
                        if (value == 'delete' &&
                            await confirm('이 설정을 삭제하시겠습니까?')) {
                          await action(() => presetStore.delete(p.id));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'copy', child: Text('복제')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
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
