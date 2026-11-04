import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'domain/recommendation.dart';
import 'paper_store.dart';
import 'library.dart';
import 'settings_editor.dart';
import 'exit_guard.dart';
import 'preset_store.dart';

Future<List<LottoGame>?> selectGames(
  BuildContext context,
  List<LottoGame> games,
) async {
  final selected = games.toSet();
  return showDialog<List<LottoGame>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('용지에 담을 게임 선택'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in games)
                CheckboxListTile(
                  title: Text(g.numbers.join(' · ')),
                  value: selected.contains(g),
                  onChanged: (v) => update(() {
                    if (v == true) {
                      selected.add(g);
                    } else {
                      selected.remove(g);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: selected.isEmpty || selected.length > 5
                ? null
                : () => Navigator.pop(
                    context,
                    games.where(selected.contains).toList(),
                  ),
            child: const Text('다음'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> saveResultsToPaper(
  BuildContext context,
  List<LottoGame> games,
  List<DrawResult> draws,
) async {
  final selected = await selectGames(context, games);
  if (selected == null || !context.mounted) return false;
  final target = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('새 복권 용지'),
            onTap: () => Navigator.pop(context, 'new'),
          ),
          for (final p in paperStore.items)
            ListTile(
              title: Text(p.title),
              subtitle: Text('${p.games.length}/5게임'),
              enabled: p.games.length + selected.length <= 5,
              onTap: p.games.length + selected.length > 5
                  ? null
                  : () => Navigator.pop(context, p.id),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('빈 칸이 부족한 용지는 선택할 수 없습니다. 게임 수를 줄이거나 새 용지를 만드십시오.'),
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
  });
  final LotteryPaper? paper;
  final List<LottoGame>? initialGames;
  final List<DrawResult> draws;
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
    child: Scaffold(
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
          if (games.length < 5)
            OutlinedButton(
              onPressed: busy ? null : add,
              child: const Text('조합 추가'),
            ),
          FilledButton(
            onPressed: busy || games.isEmpty ? null : save,
            child: const Text('용지 저장'),
          ),
        ],
      ),
    ),
  );
}

LottoGame _generate((RecommendationOptions, List<DrawResult>) request) =>
    RecommendationEngine().generate(request.$1, draws: request.$2).single;

class GameComposer extends StatefulWidget {
  const GameComposer({super.key, this.draws = const []});
  final List<DrawResult> draws;
  @override
  State<GameComposer> createState() => _GameComposerState();
}

class _GameComposerState extends State<GameComposer> {
  final selected = <int>{};
  int mode = 0;
  bool busy = false;
  RecommendationOptions? options;
  Future<void> editOptions() async {
    final next = await Navigator.push<RecommendationOptions>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsEditor(initial: options, draws: widget.draws),
      ),
    );
    if (mounted && next != null) setState(() => options = next);
  }

  Future<void> generate() async {
    if (mode == 3 && options == null) {
      options = await Navigator.push<RecommendationOptions>(
        context,
        MaterialPageRoute(builder: (_) => SettingsEditor(draws: widget.draws)),
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
  Widget build(BuildContext context) => Scaffold(
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
                label: Text(['직접 선택', '내 번호', '완전 랜덤', '상세 설정'][m]),
                selected: mode == m,
                onSelected: busy ? null : (_) => setState(() => mode = m),
              ),
          ],
        ),
        if (mode < 2)
          Wrap(
            spacing: 4,
            children: [
              for (var n = 1; n <= 45; n++)
                if (mode == 0 || libraryStore.numbers.contains(n))
                  FilterChip(
                    label: Text('$n'),
                    selected: selected.contains(n),
                    onSelected:
                        busy || (!selected.contains(n) && selected.length == 6)
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
                  : (id) =>
                        setState(() => options = presetStore.find(id)?.options),
            ),
          TextButton(
            onPressed: busy ? null : editOptions,
            child: const Text('설정 수정'),
          ),
        ],
        if (mode >= 2)
          OutlinedButton(
            onPressed: busy ? null : generate,
            child: Text(selected.isEmpty ? '번호 생성' : '다시 생성'),
          ),
        Text('선택한 조합: ${(selected.toList()..sort()).join(' · ')}'),
        FilledButton(
          onPressed: busy || selected.length != 6
              ? null
              : () => Navigator.pop(context, LottoGame(selected)),
          child: const Text('복권 용지에 추가'),
        ),
      ],
    ),
  );
}
