import 'dart:convert';
import 'package:flutter/material.dart';
import 'banner_scaffold.dart';
import 'local_storage.dart';
import 'domain/recommendation.dart';
import 'preset_store.dart';
import 'paper_store.dart';
import 'paper_flow.dart';
import 'paper_view.dart';
import 'settings_editor.dart';
import 'collection_order.dart';
import 'number_display.dart';
import 'favorite_number_dialog.dart';

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
  Future<void> addNumbers(Set<int> values) => _change((ns, _) {
    if (values.any((n) => n < 1 || n > 45)) throw ArgumentError('번호 범위 오류');
    ns.addAll(values);
  });
  Future<void> removeGames(Set<LottoGame> values) =>
      _change((_, gs) => gs.removeWhere((g) => values.contains(g.game)));
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

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  bool favoritesExpanded = true,
      expansionReady = false,
      savingExpansion = false;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    loadExpansion();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> loadExpansion() async {
    try {
      final value = (await LocalStorage.getInstance()).getBool(
        'library.favoritesExpanded.v1',
      );
      if (mounted) setState(() => favoritesExpanded = value ?? true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('번호 영역 표시 설정을 불러오지 못했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => expansionReady = true);
    }
  }

  Future<void> toggleExpansion() async {
    if (!expansionReady || savingExpansion) return;
    setState(() => savingExpansion = true);
    try {
      final next = !favoritesExpanded;
      final saved = await (await LocalStorage.getInstance()).setBool(
        'library.favoritesExpanded.v1',
        next,
      );
      if (!saved) throw StateError('표시 설정 저장 실패');
      if (mounted) setState(() => favoritesExpanded = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('번호 영역 표시 설정을 저장하지 못했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => savingExpansion = false);
    }
  }

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

  Future<bool> action(Future<void> Function() task) async {
    if (!mounted || changing) return false;
    setState(() => changing = true);
    try {
      await task();
      return true;
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
      return false;
    } finally {
      if (mounted) setState(() => changing = false);
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
              child: const Text('취소', textAlign: TextAlign.center),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', textAlign: TextAlign.center),
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
    if (mounted && next != null) {
      await action(() => libraryStore.editGame(old, next));
    }
    if (mounted) {
      setState(
        () => selectedGames.removeWhere((g) => !libraryStore.contains(g)),
      );
    }
  }

  Future<void> addFavoriteNumbers() async {
    final values = await pickFavoriteNumbers(context, libraryStore.numbers);
    if (!mounted || values == null || values.isEmpty) return;
    await action(() => libraryStore.addNumbers(values));
  }

  Future<void> deleteSelectedGames() async {
    final values = {...selectedGames};
    if (values.isEmpty ||
        !await confirm('선택한 조합 ${values.length}개를 삭제하시겠습니까?')) {
      return;
    }
    if (!mounted) return;
    if (await action(() => libraryStore.removeGames(values))) {
      if (mounted) setState(() => selectedGames.removeAll(values));
    }
  }

  Widget favorites() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '내 번호',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${libraryStore.numbers.length}/45개'),
        trailing: Icon(
          favoritesExpanded ? Icons.expand_less : Icons.expand_more,
        ),
        onTap: expansionReady && !savingExpansion ? toggleExpansion : null,
      ),
      if (favoritesExpanded) ...[
        if (libraryStore.numbers.isEmpty) const Text('저장한 번호가 없습니다.'),
        NumberPickerGrid(
          numbers: libraryStore.numbers.toList()..sort(),
          selected: selectedNumbers,
          onToggle: (n) => setState(() {
            if (!selectedNumbers.add(n)) selectedNumbers.remove(n);
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: changing || selectedNumbers.isEmpty
                    ? null
                    : () async {
                        final values = {...selectedNumbers};
                        if (await confirm('선택한 번호를 삭제하시겠습니까?')) {
                          if (await action(
                                () => libraryStore.removeNumbers(values),
                              ) &&
                              mounted) {
                            setState(() => selectedNumbers.removeAll(values));
                          }
                        }
                      },
                child: const Text('선택 번호 삭제', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: changing ? null : addFavoriteNumbers,
                child: const Text('번호 추가', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget combinationActions(double maxHeight) {
    final add = FilledButton(
      onPressed: changing ? null : editGame,
      child: const Text('조합 직접 추가', textAlign: TextAlign.center),
    );
    final delete = OutlinedButton(
      onPressed: changing || selectedGames.isEmpty ? null : deleteSelectedGames,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      child: const Text('선택한 조합 삭제', textAlign: TextAlign.center),
    );
    final paper = OutlinedButton(
      onPressed: changing || selectedGames.isEmpty || selectedGames.length > 5
          ? null
          : () => saveResultsToPaper(context, selectedGames.toList(), draws),
      child: const Text('선택 조합으로 복권 용지 만들기', textAlign: TextAlign.center),
    );
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: MediaQuery.orientationOf(context) == Orientation.landscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: add),
                      const SizedBox(width: 8),
                      Expanded(child: delete),
                      const SizedBox(width: 8),
                      Expanded(child: paper),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: add),
                          const SizedBox(width: 8),
                          Expanded(child: delete),
                        ],
                      ),
                      const SizedBox(height: 8),
                      paper,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String sourceName(SavedGame saved) => saved.source == 'manual'
      ? '직접 입력'
      : saved.options == null
      ? '완전 랜덤'
      : '상세 규칙';

  Widget gameCard(SavedGame saved, Widget? arrows) => Card(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  sourceName(saved),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            ?arrows,
            Semantics(
              label: '${sourceName(saved)} 조합 선택',
              child: Checkbox(
                key: ValueKey('saved-game-${saved.game.numbers.join("-")}'),
                value: selectedGames.contains(saved.game),
                onChanged: changing
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          selectedGames.add(saved.game);
                        } else {
                          selectedGames.remove(saved.game);
                        }
                      }),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: changing ? null : () => editGame(saved.game),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: NumberGrid(numbers: saved.game.numbers, fontSize: 18),
          ),
        ),
      ],
    ),
  );

  Widget paperCard(LotteryPaper p, Widget? arrows) => Card(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PaperEditor(paper: p, draws: draws),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${p.games.length}게임',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?arrows,
            IconButton(
              padding: EdgeInsets.zero,
              tooltip: '용지 삭제',
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              onPressed: changing
                  ? null
                  : () async {
                      if (await confirm('이 복권 용지를 삭제하시겠습니까?')) {
                        await action(() => paperStore.delete(p.id));
                      }
                    },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PaperView(paper: p, draws: draws),
                ),
              ),
              child: const Text('번호 크게 보기', textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    ),
  );

  Widget presetCard(Preset p, Widget? arrows) => Row(
    children: [
      Expanded(
        child: InkWell(
          onTap: () => editPreset(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            child: Text(p.name, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
      ?arrows,
      PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        onSelected: (value) async {
          if (value == 'copy') {
            await action(() async {
              await presetStore.save(p.options);
            });
          }
          if (value == 'delete' && await confirm('이 설정을 삭제하시겠습니까?')) {
            await action(() => presetStore.delete(p.id));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'copy', child: Text('복제')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => BannerScaffold(
    appBar: AppBar(
      title: const Text('보관함'),
      bottom: TabBar(
        controller: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: '복권 용지'),
          Tab(text: '내 번호·조합'),
          Tab(text: '저장한 설정'),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: Listenable.merge([libraryStore, paperStore, presetStore]),
      builder: (context, _) => TabBarView(
        controller: tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PaperEditor(draws: draws),
                  ),
                ),
                child: const Text('새 복권 용지', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              CollectionOrder<LotteryPaper>(
                storageKey: 'order.papers.v1',
                items: paperStore.items,
                id: (p) => p.id,
                name: (p) => p.title,
                belowSort: const Text(
                  '용지 이름을 누르면 내용을 수정할 수 있습니다.',
                  textAlign: TextAlign.center,
                ),
                builder: (p) => paperCard(p, null),
                inlineBuilder: paperCard,
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const PageStorageKey('number-combination-list'),
                    padding: const EdgeInsets.all(12),
                    children: [
                      favorites(),
                      const Divider(height: 24),
                      const SizedBox(height: 12),
                      const Text(
                        '저장한 조합',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CollectionOrder<SavedGame>(
                        storageKey: 'order.games.v1',
                        items: libraryStore.games,
                        id: (g) => g.game.numbers.join(','),
                        belowSort: const Text(
                          '조합을 누르면 번호를 수정할 수 있습니다.',
                          textAlign: TextAlign.center,
                        ),
                        builder: (g) => gameCard(g, null),
                        inlineBuilder: gameCard,
                      ),
                      if (libraryStore.games.isEmpty)
                        const Text('저장한 조합이 없습니다.'),
                    ],
                  ),
                ),
                combinationActions(constraints.maxHeight * .45),
              ],
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FilledButton(
                onPressed: editPreset,
                child: const Text('새 설정', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              CollectionOrder<Preset>(
                storageKey: 'order.presets.v1',
                items: presetStore.items,
                id: (p) => p.id,
                name: (p) => p.name,
                builder: (p) => presetCard(p, null),
                inlineBuilder: presetCard,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
