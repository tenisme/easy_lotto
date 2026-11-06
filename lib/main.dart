import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'domain/recommendation.dart';
import 'settings_editor.dart';
import 'preset_store.dart';
import 'library.dart';
import 'paper_store.dart';
import 'paper_flow.dart';
import 'exit_guard.dart';
import 'draw_store.dart';
import 'local_storage.dart';
import 'app_theme.dart';
import 'banner_scaffold.dart';
import 'draw_source.dart';
import 'number_display.dart';

final drawStore = DrawStore();

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final theme = AppThemeController();
  @override
  void initState() {
    super.initState();
    theme.load();
  }

  @override
  void dispose() {
    theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppThemeScope(
    controller: theme,
    child: ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff386b56)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff386b56),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: theme.mode,
        home: const RecommendationHome(),
      ),
    ),
  );
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
  int tab = 0;
  @override
  void initState() {
    super.initState();
    paperStore.load().catchError((Object _) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('복권 용지를 불러오지 못했습니다.')));
      }
    });
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
              child: const Text('새 설정', textAlign: TextAlign.center),
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
          generationCount: count,
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
  Widget build(BuildContext context) => BannerScaffold(
    showBanner: tab != 1,
    appBar: tab != 0
        ? null
        : AppBar(
            title: const Text('추천'),
            actions: [
              IconButton(
                tooltip: '보관함',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => setState(() => tab = 1),
              ),
            ],
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '추천'),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: '보관함',
        ),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
      ],
    ),
    body: tab == 1
        ? LibraryPage(
            draws: drawStore.draws,
            generationCount: count,
            onGenerate: (options, id) async {
              setState(() {
                tab = 0;
                detailed = true;
                draft = options;
                activeId = id;
              });
              await generate();
            },
          )
        : tab == 2
        ? SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('더보기', style: TextStyle(fontSize: 24)),
                DrawSource(
                  round: drawStore.draws.firstOrNull?.round,
                  status: drawStore.status,
                ),
                const AppThemePicker(),
                const ListTile(
                  title: Text('로또 번호 추천 안내'),
                  subtitle: Text(
                    '본 앱은 다양한 번호 선택 조건을 활용할 수 있는 편의를 제공하지만, 이러한 조건들과 과거의 추첨 결과 등은 당첨을 예측하거나 보장하지 않음을 유의하여 주시기 바랍니다.',
                  ),
                ),
                const ListTile(
                  title: Text('저장 안내'),
                  subtitle: Text(
                    '저장한 번호 및 설정 등은 앱 내부 저장소에 저장됩니다. 앱 삭제 시 데이터가 사라짐에 유의하여 주십시오. 추후 내보내기 및 가져오기, 클라우드 연동·동기화 기능을 업데이트할 예정입니다.',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await (await LocalStorage.getInstance()).setBool(
                        'resultLossNotice.v1',
                        false,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('결과 이탈 안내를 다시 표시합니다.')),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('안내 설정을 변경하지 못했습니다.')),
                        );
                      }
                    }
                  },
                  child: const Text(
                    '결과 이탈 안내 다시 켜기',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          )
        : SafeArea(
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
                        onSelected: busy
                            ? null
                            : (_) => setState(() => count = n),
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
                DrawSource(
                  round: drawStore.draws.firstOrNull?.round,
                  status: drawStore.status,
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
                      label: const Text('상세 규칙'),
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
                          : presetStore.find(presetStore.selectedId)?.name ??
                                '설정 선택',
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
                              busy ||
                                  presetStore.find(presetStore.selectedId) ==
                                      null
                              ? null
                              : edit,
                          child: const Text(
                            '설정 수정',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              busy ||
                                  presetStore.find(presetStore.selectedId) ==
                                      null
                              ? null
                              : () => generate(selected: true),
                          child: const Text(
                            '번호 생성',
                            textAlign: TextAlign.center,
                          ),
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
                      textAlign: TextAlign.center,
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
  late final selectedGames = widget.initialGames.toSet();
  final savedFromResults = <LottoGame>{};
  Future<void> otherSettings() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in presetStore.items)
              ListTile(
                title: Text(p.name),
                trailing: const Text('이 설정으로 생성'),
                onTap: () => Navigator.pop(context, p.id),
              ),
          ],
        ),
      ),
    );
    final preset = presetStore.find(id);
    if (mounted && preset != null) await regenerate(preset.options, preset.id);
  }

  bool get unsavedResults => games.any(
    (g) =>
        !libraryStore.contains(g) &&
        !paperStore.items.any((p) => p.games.contains(g)),
  );
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
          generationCount: games.length,
          onSaved: (saved) {
            if (mounted) setState(() => presetId = saved.id);
          },
        ),
      ),
    );
    if (next != null && mounted) await regenerate(next);
  }

  Future<void> regenerate([
    RecommendationOptions? edited,
    String? replacementId,
  ]) async {
    final confirmed =
        !unsavedResults ||
        await confirmResultLoss(
          context,
          message:
              '새 번호를 생성하면 저장하지 않은 현재 결과는 사라집니다. 저장할 번호가 있다면 결과로 돌아가 저장한 후 다시 시도하십시오.',
          stay: '기존 결과로 돌아가기',
          leave: '새 번호 생성',
        );
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
          savedFromResults.clear();
          selectedGames
            ..clear()
            ..addAll(next);
          options = configuration;
          if (replacementId != null) presetId = replacementId;
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
    listenable: Listenable.merge([libraryStore, paperStore]),
    builder: (context, _) => ExitGuard(
      needsConfirmation: unsavedResults || temporary,
      stay: '결과로 돌아가기',
      suppressionKey: temporary ? null : 'resultLossNotice.v1',
      message: unsavedResults
          ? '이 화면을 나가면 저장하지 않은 결과${temporary ? '와 임시 설정은' : '는'} 사라집니다. 저장하고 싶은 번호가 있다면 결과로 돌아가 저장 후 이동해 주세요.'
          : '현재 설정이 저장되지 않았습니다. 이 화면을 나가면 임시 설정은 사라집니다.',
      child: BannerScaffold(
        appBar: AppBar(title: const Text('추천 결과')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${options == null ? '완전 랜덤' : presetStore.find(presetId)?.name ?? '임시 설정'} · ${games.length}게임',
              ),
              TextButton(
                onPressed: busy || presetStore.items.length < 2
                    ? null
                    : otherSettings,
                child: const Text('다른 설정 선택', textAlign: TextAlign.center),
              ),
              if (options != null) ...[
                if (presetStore.find(presetId) == null)
                  const Text('저장되지 않은 설정입니다.'),
                if (presetStore.find(presetId) != null &&
                    !sameOptions(options!, presetStore.find(presetId)!.options))
                  const Text('생성 후 설정이 변경되었습니다.'),
                TextButton(
                  onPressed: busy ? null : edit,
                  child: const Text('설정 수정', textAlign: TextAlign.center),
                ),
              ],
              for (var i = 0; i < games.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('게임 ${i + 1}')),
                            if (savedFromResults.contains(games[i]))
                              const Text('저장됨')
                            else if (games.length > 1)
                              Checkbox(
                                key: ValueKey('select-game-$i'),
                                value: selectedGames.contains(games[i]),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                        if (v == true) {
                                          selectedGames.add(games[i]);
                                        } else {
                                          selectedGames.remove(games[i]);
                                        }
                                      }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        NumberGrid(
                          numbers: games[i].numbers,
                          fontSize: 18,
                          below: (n) => IconButton(
                            tooltip: '$n 내 번호 저장',
                            isSelected: libraryStore.numbers.contains(n),
                            selectedIcon: const Icon(Icons.favorite),
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () =>
                                persist(() => libraryStore.toggleNumber(n)),
                          ),
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
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : regenerate,
                child: Text(
                  busy ? '생성 중입니다' : '다시 생성',
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton(
                onPressed: busy || selectedGames.isEmpty
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final selection = games
                            .where(selectedGames.contains)
                            .toList();
                        try {
                          final saved = await saveResultsToPaper(
                            context,
                            selection,
                            drawStore.draws,
                          );
                          if (mounted && saved) {
                            setState(() {
                              savedFromResults.addAll(selection);
                              selectedGames.removeAll(selection);
                            });
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text(
                  '선택한 게임 복권 용지에 저장',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
