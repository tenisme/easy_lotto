import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'domain/recommendation.dart';
import 'settings_editor.dart';

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

List<LottoGame> generateConfiguredGames((RecommendationOptions, int) request) =>
    RecommendationEngine().generate(request.$1, count: request.$2);

class RecommendationHome extends StatefulWidget {
  const RecommendationHome({super.key});
  @override
  State<RecommendationHome> createState() => _RecommendationHomeState();
}

class _RecommendationHomeState extends State<RecommendationHome> {
  int count = 1;
  bool busy = false;
  bool detailed = false;
  RecommendationOptions? draft;
  Future<void> edit() async {
    final options = await Navigator.of(context).push<RecommendationOptions>(
      MaterialPageRoute(builder: (_) => SettingsEditor(initial: draft)),
    );
    if (options != null && mounted) {
      draft = options;
      await generate();
    }
  }

  Future<void> generate() async {
    setState(() => busy = true);
    try {
      final options = detailed ? draft : null;
      final games = options == null
          ? await compute(generateRandomGames, count)
          : await compute(generateConfiguredGames, (options, count));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RecommendationResults(initialGames: games, options: options),
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
    appBar: AppBar(title: const Text('추천')),
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
  });
  final List<LottoGame> initialGames;
  final RecommendationOptions? options;
  @override
  State<RecommendationResults> createState() => _RecommendationResultsState();
}

class _RecommendationResultsState extends State<RecommendationResults> {
  late List<LottoGame> games = widget.initialGames;
  bool busy = false;
  late RecommendationOptions? options = widget.options;
  Future<void> edit() async {
    final next = await Navigator.of(context).push<RecommendationOptions>(
      MaterialPageRoute(builder: (_) => SettingsEditor(initial: options)),
    );
    if (next != null && mounted) await regenerate(next);
  }

  Future<void> regenerate([RecommendationOptions? edited]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 번호를 생성하시겠습니까?'),
        content: const Text('새 번호를 생성하면 현재 결과는 사라집니다.'),
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final configuration = edited ?? options;
      final next = configuration == null
          ? await compute(generateRandomGames, games.length)
          : await compute(generateConfiguredGames, (
              configuration,
              games.length,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('추천 결과')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${options == null ? '완전 랜덤' : '임시 설정'} · ${games.length}게임'),
          if (options != null) ...[
            const Text('저장되지 않은 설정입니다.'),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in games[i].numbers)
                          CircleAvatar(child: Text('$n')),
                      ],
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
  );
}
