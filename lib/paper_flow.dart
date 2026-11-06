import 'package:flutter/material.dart';
import 'banner_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'domain/recommendation.dart';
import 'paper_store.dart';
import 'library.dart';
import 'settings_editor.dart';
import 'exit_guard.dart';
import 'preset_store.dart';

Future<bool> saveResultsToPaper(
  BuildContext context,
  List<LottoGame> games,
  List<DrawResult> draws,
) async {
  final selected = List<LottoGame>.of(games);
  if (selected.isEmpty || selected.length > 5) return false;
  final target = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('복권 용지 선택'),
            trailing: IconButton(
              tooltip: '복권 용지 선택 안내',
              icon: const Icon(Icons.help_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('복권 용지 선택 안내'),
                  content: const Text(
                    '이미 5게임이 채워진 복권 용지는 이 화면에 표시되지 않습니다.\n\n기존 복권 용지에 남는 자리가 없는 경우, 선택한 게임 수를 줄이거나 새 복권 용지를 만들어 주십시오.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('새 복권 용지 만들기'),
            onTap: () => Navigator.pop(context, 'new'),
          ),
          for (final p in paperStore.items.where((p) => p.games.length < 5))
            ListTile(
              title: Text(p.title),
              subtitle: Text('${p.games.length}/5게임'),
              enabled: p.games.length + selected.length <= 5,
              onTap: p.games.length + selected.length > 5
                  ? null
                  : () => Navigator.pop(context, p.id),
            ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return false;
  final existing = paperStore.items.where((p) => p.id == target).firstOrNull;
  return await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaperEditor(
            paper: existing,
            initialGames: [...?existing?.games, ...selected],
            draws: draws,
            fromResults: true,
          ),
        ),
      ) ==
      true;
}

class PaperEditor extends StatefulWidget {
  const PaperEditor({
    super.key,
    this.paper,
    this.initialGames,
    this.draws = const [],
    this.fromResults = false,
  });
  final LotteryPaper? paper;
  final List<LottoGame>? initialGames;
  final List<DrawResult> draws;
  final bool fromResults;
  @override
  State<PaperEditor> createState() => _PaperEditorState();
}

class _PaperEditorState extends State<PaperEditor> {
  late final title = TextEditingController(
    text: widget.paper?.title ?? paperStore.defaultName(),
  );
  late List<LottoGame> games = [...?widget.initialGames ?? widget.paper?.games];
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> add({int? replace}) async {
    final chosen = await showModalBottomSheet<LottoGame>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in libraryStore.games)
              ListTile(
                title: Text(g.game.numbers.join(' · ')),
                onTap: () => Navigator.pop(context, g.game),
              ),
            ListTile(
              title: const Text('조합 추가'),
              onTap: () async {
                final g = await Navigator.push<LottoGame>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameComposer(draws: widget.draws),
                  ),
                );
                if (context.mounted && g != null) Navigator.pop(context, g);
              },
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (replace != null) {
      if (games[replace] == chosen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 게임과 같은 번호 조합으로는 교체할 수 없습니다.')),
        );
        return;
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이 게임을 교체하시겠습니까?'),
          content: Text(
            '현재: ${games[replace].numbers.join(', ')}\n변경: ${chosen.numbers.join(', ')}\n이 용지의 게임만 바뀌며, 저장한 원본 조합은 변경되지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('교체'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      if (replace == null) {
        games.add(chosen);
      } else {
        games[replace] = chosen;
      }
    });
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await paperStore.save(title.text, games, id: widget.paper?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('용지 저장에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExitGuard(
    needsConfirmation:
        title.text != widget.paper?.title ||
        !listEquals(games, widget.paper?.games),
    message: '저장하지 않은 용지 변경 사항이 있습니다. 저장하지 않고 이동하시겠습니까?',
    child: BannerScaffold(
      appBar: AppBar(title: const Text('복권 용지 편집')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '용지 이름'),
          ),
          for (var i = 0; i < games.length; i++)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('게임 ${i + 1}'),
                    subtitle: Text(games[i].numbers.join(' · ')),
                  ),
                  Wrap(
                    children: [
                      if (!widget.fromResults)
                        TextButton(
                          onPressed: busy ? null : () => add(replace: i),
                          child: const Text('교체'),
                        ),
                      IconButton(
                        tooltip: '위로 이동',
                        onPressed: busy || i == 0
                            ? null
                            : () => setState(() {
                                final g = games.removeAt(i);
                                games.insert(i - 1, g);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      if (!widget.fromResults)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => games.removeAt(i)),
                          child: const Text('제거'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (games.length < 5 && !widget.fromResults)
            OutlinedButton(
              onPressed: busy ? null : add,
              child: const Text('조합 추가'),
            ),
          FilledButton(
            onPressed: busy || games.isEmpty ? null : save,
            child: const Text('복권 용지 저장'),
          ),
        ],
      ),
    ),
  );
}

LottoGame _generate((RecommendationOptions, List<DrawResult>) request) =>
    RecommendationEngine().generate(request.$1, draws: request.$2).single;

class GameComposer extends StatefulWidget {
  const GameComposer({
    super.key,
    this.draws = const [],
    this.initialGame,
    this.actionLabel = '복권 용지에 추가',
  });
  final List<DrawResult> draws;
  final LottoGame? initialGame;
  final String actionLabel;
  @override
  State<GameComposer> createState() => _GameComposerState();
}

class _GameComposerState extends State<GameComposer> {
  final selected = <int>{};
  @override
  void initState() {
    super.initState();
    selected.addAll(widget.initialGame?.numbers ?? []);
  }

  int mode = 0;
  bool busy = false;
  RecommendationOptions? options;
  Future<void> editOptions() async {
    final next = await Navigator.push<RecommendationOptions>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsEditor(
          initial: options,
          draws: widget.draws,
          completeOnly: true,
        ),
      ),
    );
    if (mounted && next != null) {
      setState(() => options = next);
      await generate();
    }
  }

  Future<void> generate() async {
    if (mode == 3 && options == null) {
      options = await Navigator.push<RecommendationOptions>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SettingsEditor(draws: widget.draws, completeOnly: true),
        ),
      );
      if (!mounted || options == null) return;
    }
    setState(() => busy = true);
    try {
      final game = await compute(_generate, (
        mode == 2 ? RecommendationOptions() : options!,
        widget.draws,
      ));
      if (mounted) {
        setState(() {
          selected
            ..clear()
            ..addAll(game.numbers);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is GenerationException ? e.message : '번호 생성에 실패했습니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BannerScaffold(
    appBar: AppBar(title: const Text('조합 추가')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          children: [
            for (var m = 0; m < 4; m++)
              ChoiceChip(
                label: Text(['직접 선택', '내 번호', '완전 랜덤', '상세 규칙'][m]),
                selected: mode == m,
                onSelected: busy
                    ? null
                    : (_) async {
                        setState(() => mode = m);
                        if (m == 2) await generate();
                      },
              ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: [
            for (var n = 1; n <= 45; n++)
              if (mode != 1 || libraryStore.numbers.contains(n))
                FilterChip(
                  showCheckmark: false,
                  label: Text('$n'),
                  selected: selected.contains(n),
                  onSelected:
                      busy ||
                          mode >= 2 ||
                          (!selected.contains(n) && selected.length == 6)
                      ? null
                      : (v) => setState(() {
                          if (v) {
                            selected.add(n);
                          } else {
                            selected.remove(n);
                          }
                        }),
                ),
          ],
        ),
        if (mode == 1) const Text('부족한 번호는 직접 선택에서 채울 수 있습니다.'),
        if (mode == 3) ...[
          if (presetStore.items.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '저장한 설정 선택'),
              items: [
                for (final p in presetStore.items)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: busy
                  ? null
                  : (id) async {
                      setState(() => options = presetStore.find(id)?.options);
                      await generate();
                    },
            ),
          TextButton(
            onPressed: busy ? null : editOptions,
            child: const Text('설정 수정'),
          ),
        ],
        Text('선택한 조합: ${(selected.toList()..sort()).join(' · ')}'),
        if (mode >= 2)
          OutlinedButton(
            onPressed: busy ? null : generate,
            child: const Text('다시 생성'),
          ),
        FilledButton(
          onPressed: busy || selected.length != 6
              ? null
              : () => Navigator.pop(context, LottoGame(selected)),
          child: Text(widget.actionLabel),
        ),
      ],
    ),
  );
}
