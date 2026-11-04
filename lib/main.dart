import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'domain/recommendation.dart';
import 'settings_editor.dart';
import 'preset_store.dart';
import 'library.dart';
import 'exit_guard.dart';
import 'draw_store.dart';
import 'package:url_launcher/url_launcher.dart';

final drawStore = DrawStore();

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: RecommendationHome());
  }
}

List<LottoGame> generateRandomGames(int count) =>
    RecommendationEngine().generate(RecommendationOptions(), count: count);

List<LottoGame> generateConfiguredGames(
  (RecommendationOptions, int, List<DrawResult>) request,
) => RecommendationEngine().generate(
  request.$1,
  count: request.$2,
  draws: request.$3,
);

class RecommendationHome extends StatefulWidget {
  const RecommendationHome({super.key});
  @override
  State<RecommendationHome> createState() => _RecommendationHomeState();
}

class _RecommendationHomeState extends State<RecommendationHome> {
  @override
  void initState() {
    super.initState();
    libraryStore.load().catchError((Object _) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('보관함을 불러오지 못했습니다.')));
      }
    });
    presetStore
        .load()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('저장한 설정을 불러오지 못했습니다.')),
            );
          }
        });
    drawStore.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  int count = 1;
  bool busy = false;
  bool detailed = false;
  RecommendationOptions? draft;
  String? activeId;
  Future<void> choose() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final preset in presetStore.items)
              ListTile(
                leading: Icon(
                  preset.id == presetStore.selectedId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(preset.name),
                onTap: () => Navigator.pop(context, preset.id),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('새 설정'),
            ),
          ],
        ),
      ),
    );
    if (id == null || !mounted) return;
    if (id == 'new') {
      await edit(fresh: true);
      return;
    }
    try {
      await presetStore.select(id);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('설정 선택을 저장하지 못했습니다.')));
      }
    }
  }

  Future<void> edit({bool fresh = false}) async {
    var preset = fresh ? null : presetStore.find(presetStore.selectedId);
    final options = await Navigator.of(context).push<RecommendationOptions>(
      MaterialPageRoute(
        builder: (_) => SettingsEditor(
          initial: fresh ? null : preset?.options ?? draft,
          draws: drawStore.draws,
          presetId: preset?.id,
          onSaved: (saved) => preset = saved,
        ),
      ),
    );
    if (options != null && mounted) {
      draft = options;
      activeId = preset?.id;
      await generate();
    }
    if (mounted) setState(() {});
  }

  Future<void> generate({bool selected = false}) async {
    setState(() => busy = true);
    try {
      final preset = presetStore.find(presetStore.selectedId);
      final options = detailed ? (selected ? preset?.options : draft) : null;
      if (selected) activeId = preset?.id;
      final games = options == null
          ? await compute(generateRandomGames, count)
          : await compute(generateConfiguredGames, (
              options,
              count,
              List.of(drawStore.draws),
            ));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecommendationResults(
            initialGames: games,
            options: options,
            presetId: detailed ? activeId : null,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is GenerationException
                  ? error.message
                  : '번호 생성에 실패했습니다. 다시 시도하십시오.',
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
    appBar: AppBar(
      title: const Text('추천'),
      actions: [
        IconButton(
          tooltip: '보관함',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const LibraryPage())),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('몇 게임을 만들까요?', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(
                  label: Text('$n'),
                  selected: count == n,
                  onSelected: busy ? null : (_) => setState(() => count = n),
                ),
            ],
          ),
          const SizedBox(height: 32),
          if (!detailed)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('완전 랜덤', style: TextStyle(fontSize: 20)),
                    SizedBox(height: 8),
                    Text('조건 없이 서로 다른 번호 6개를 생성합니다.'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(drawStore.status),
          TextButton(
            onPressed: () async {
              await launchUrl(
                Uri.parse('https://www.dhlottery.co.kr/'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('출처 : 동행복권'),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('완전 랜덤'),
                selected: !detailed,
                onSelected: busy
                    ? null
                    : (_) => setState(() => detailed = false),
              ),
              ChoiceChip(
                label: const Text('상세 설정'),
                selected: detailed,
                onSelected: busy
                    ? null
                    : (_) => setState(() => detailed = true),
              ),
            ],
          ),
          if (detailed)
            ListTile(
              title: Text(
                presetStore.items.isEmpty
                    ? '저장한 설정이 없습니다'
                    : presetStore.find(presetStore.selectedId)?.name ?? '설정 선택',
              ),
              trailing: const Icon(Icons.expand_more),
              onTap: presetStore.items.isEmpty ? null : choose,
            ),
          if (detailed && presetStore.items.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        busy || presetStore.find(presetStore.selectedId) == null
                        ? null
                        : edit,
                    child: const Text('설정 수정'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        busy || presetStore.find(presetStore.selectedId) == null
                        ? null
                        : () => generate(selected: true),
                    child: const Text('번호 생성'),
                  ),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: busy
                  ? null
                  : detailed
                  ? edit
                  : generate,
              child: Text(
                busy
                    ? '생성 중입니다'
                    : detailed
                    ? '설정 만들기'
                    : '번호 생성',
              ),
            ),
        ],
      ),
    ),
  );
}

class RecommendationResults extends StatefulWidget {
  const RecommendationResults({
    super.key,
    required this.initialGames,
    this.options,
    this.presetId,
  });
  final List<LottoGame> initialGames;
  final RecommendationOptions? options;
  final String? presetId;
  @override
  State<RecommendationResults> createState() => _RecommendationResultsState();
}

class _RecommendationResultsState extends State<RecommendationResults> {
  bool get unsavedResults => games.any((g) => !libraryStore.contains(g));
  bool get temporary => options != null && presetStore.find(presetId) == null;
  Future<void> persist(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보관함 저장에 실패했습니다. 다시 시도하십시오.')),
        );
      }
    }
  }

  late List<LottoGame> games = widget.initialGames;
  bool busy = false;
  late RecommendationOptions? options = widget.options;
  late String? presetId = widget.presetId;
  Future<void> edit() async {
    final next = await Navigator.of(context).push<RecommendationOptions>(
      MaterialPageRoute(
        builder: (_) => SettingsEditor(
          initial: options,
          draws: drawStore.draws,
          presetId: presetId,
          onSaved: (saved) {
            if (mounted) setState(() => presetId = saved.id);
          },
        ),
      ),
    );
    if (next != null && mounted) await regenerate(next);
  }

  Future<void> regenerate([RecommendationOptions? edited]) async {
    final confirmed =
        !unsavedResults ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('새 번호를 생성하시겠습니까?'),
                content: const Text(
                  '새 번호를 생성하면 저장하지 않은 현재 결과는 사라집니다. 저장할 번호가 있다면 결과로 돌아가 저장한 후 다시 시도하십시오.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('기존 결과로 돌아가기'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('새 번호 생성'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!confirmed || !mounted) return;
    setState(() => busy = true);
    try {
      final configuration = edited ?? options;
      final next = configuration == null
          ? await compute(generateRandomGames, games.length)
          : await compute(generateConfiguredGames, (
              configuration,
              games.length,
              List.of(drawStore.draws),
            ));
      if (mounted) {
        setState(() {
          games = next;
          options = configuration;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is GenerationException
                  ? error.message
                  : '번호 생성에 실패했습니다. 기존 결과를 유지합니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: libraryStore,
    builder: (context, _) => ExitGuard(
      needsConfirmation: unsavedResults || temporary,
      stay: '결과로 돌아가기',
      message: unsavedResults
          ? '이 화면을 나가면 저장하지 않은 결과${temporary ? '와 임시 설정은' : '는'} 사라집니다. 저장하고 싶은 번호가 있다면 결과로 돌아가 저장 후 이동해 주세요.'
          : '현재 설정이 저장되지 않았습니다. 이 화면을 나가면 임시 설정은 사라집니다.',
      child: Scaffold(
        appBar: AppBar(title: const Text('추천 결과')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${options == null ? '완전 랜덤' : presetStore.find(presetId)?.name ?? '임시 설정'} · ${games.length}게임',
              ),
              if (options != null) ...[
                if (presetStore.find(presetId) == null)
                  const Text('저장되지 않은 설정입니다.'),
                if (presetStore.find(presetId) != null &&
                    !sameOptions(options!, presetStore.find(presetId)!.options))
                  const Text('생성 후 설정이 변경되었습니다.'),
                TextButton(
                  onPressed: busy ? null : edit,
                  child: const Text('설정 수정'),
                ),
              ],
              for (var i = 0; i < games.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('게임 ${i + 1}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final n in games[i].numbers)
                              Expanded(
                                child: Column(
                                  children: [
                                    CircleAvatar(child: Text('$n')),
                                    IconButton(
                                      tooltip: '$n 내 번호 저장',
                                      isSelected: libraryStore.numbers.contains(
                                        n,
                                      ),
                                      selectedIcon: const Icon(Icons.favorite),
                                      icon: const Icon(Icons.favorite_border),
                                      onPressed: () => persist(
                                        () => libraryStore.toggleNumber(n),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed: libraryStore.contains(games[i])
                              ? null
                              : () => persist(
                                  () =>
                                      libraryStore.saveGame(games[i], options),
                                ),
                          child: Text(
                            libraryStore.contains(games[i])
                                ? '저장된 조합'
                                : '조합 저장',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : regenerate,
                child: Text(busy ? '생성 중입니다' : '다시 생성'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
