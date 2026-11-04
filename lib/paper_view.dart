import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'display_preferences.dart';
import 'domain/recommendation.dart';
import 'paper_store.dart';
import 'paper_flow.dart';

class PaperView extends StatefulWidget {
  const PaperView({
    super.key,
    required this.paper,
    this.draws = const [],
    this.setAwake,
  });
  final LotteryPaper paper;
  final List<DrawResult> draws;
  final Future<void> Function(bool)? setAwake;
  @override
  State<PaperView> createState() => _PaperViewState();
}

class _PaperViewState extends State<PaperView> with WidgetsBindingObserver {
  final random = Random();
  PaperDesign design = PaperDesign.basic;
  bool ready = false, keepOn = false;
  bool covered = false;
  LotteryPaper get paper =>
      paperStore.items.where((p) => p.id == widget.paper.id).firstOrNull ??
      widget.paper;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => initialize());
  }

  Future<void> initialize() async {
    try {
      final preferences = await DisplayPreferences.load();
      if (!mounted) return;
      setState(() {
        design = preferences.resolve(paper.id, random);
        ready = true;
      });
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || prefs.getBool('largeViewIntro.v1') == true) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            '번호 크게 보기',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('이 화면에서는 저장한 복권 용지를 실제 종이 복권에 편하게 옮겨 적을 수 있습니다.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (confirmed == true) await prefs.setBool('largeViewIntro.v1', true);
    } catch (_) {
      if (mounted) {
        setState(() => ready = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보기 설정을 불러오지 못해 기본 디자인을 사용합니다.')),
        );
      }
    }
  }

  Future<void> wake(bool enabled) async {
    try {
      if (widget.setAwake != null) {
        await widget.setAwake!(enabled);
      } else {
        await WakelockPlus.toggle(enable: enabled);
      }
    } catch (_) {
      if (mounted && enabled) {
        setState(() => keepOn = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('화면 계속 켜기를 적용하지 못했습니다.')));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    wake(state == AppLifecycleState.resumed && keepOn && !covered);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    wake(false);
    super.dispose();
  }

  Future<void> style() async {
    covered = true;
    await wake(false);
    if (!mounted) return;
    final preferences = await Navigator.push<DisplayPreferences>(
      context,
      MaterialPageRoute(builder: (_) => DesignSettings(paperId: paper.id)),
    );
    if (!mounted) return;
    covered = false;
    if (preferences != null) {
      setState(() => design = preferences.resolve(paper.id, random));
    }
    await wake(keepOn);
  }

  Future<void> edit() async {
    covered = true;
    await wake(false);
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaperEditor(paper: paper, draws: widget.draws),
      ),
    );
    if (!mounted) return;
    covered = false;
    setState(() {});
    await wake(keepOn);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(paper.title)),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: ready ? style : null,
                child: const Text('보기 스타일'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: ready ? edit : null,
                child: const Text('용지 편집'),
              ),
            ),
          ],
        ),
      ),
    ),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('화면 계속 켜기'),
                  value: keepOn,
                  onChanged: (v) {
                    setState(() => keepOn = v);
                    wake(v);
                  },
                ),
                for (var i = 0; i < paper.games.length; i++)
                  GameDisplay(
                    label: String.fromCharCode(65 + i),
                    numbers: paper.games[i].numbers,
                    design: design,
                  ),
              ],
            ),
          ),
  );
}

class GameDisplay extends StatelessWidget {
  const GameDisplay({
    super.key,
    required this.label,
    required this.numbers,
    required this.design,
  });
  final String label;
  final List<int> numbers;
  final PaperDesign design;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(
      vertical: design == PaperDesign.spacious ? 18 : 6,
    ),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black54),
      borderRadius: BorderRadius.circular(design == PaperDesign.cards ? 16 : 4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '게임 $label',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: design == PaperDesign.spacious ? 16 : 4,
          runSpacing: 10,
          children: [
            for (final n in numbers)
              Container(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: design == PaperDesign.cards
                      ? Colors.grey.shade200
                      : Colors.white,
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(
                    design == PaperDesign.cards ? 6 : 30,
                  ),
                ),
                child: Text(
                  '$n',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class DesignSettings extends StatefulWidget {
  const DesignSettings({super.key, required this.paperId});
  final String paperId;
  @override
  State<DesignSettings> createState() => _DesignSettingsState();
}

class _DesignSettingsState extends State<DesignSettings> {
  DisplayPreferences? original;
  DesignMode mode = DesignMode.basic;
  PaperDesign base = PaperDesign.basic;
  PaperDesign? paperDesign;
  bool saving = false;
  bool loadFailed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await DisplayPreferences.load();
      if (mounted) {
        setState(() {
          original = p;
          mode = p.mode;
          base = p.defaultDesign;
          paperDesign = p.overrides[widget.paperId];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('디자인 설정을 불러오지 못했습니다.')));
      }
      if (mounted) setState(() => loadFailed = true);
    }
  }

  Future<void> save() async {
    final overrides = {...original!.overrides};
    if (paperDesign == null) {
      overrides.remove(widget.paperId);
    } else {
      overrides[widget.paperId] = paperDesign!;
    }
    final next = DisplayPreferences(
      mode: mode,
      defaultDesign: base,
      overrides: overrides,
    );
    setState(() => saving = true);
    try {
      await next.save();
      if (mounted) Navigator.pop(context, next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('디자인 저장에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('보기 스타일')),
    body: loadFailed
        ? Center(
            child: TextButton(
              onPressed: () {
                setState(() => loadFailed = false);
                load();
              },
              child: const Text('다시 불러오기'),
            ),
          )
        : original == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('적용 방식'),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in DesignMode.values)
                    ChoiceChip(
                      label: Text(['기본 디자인', '용지별 디자인', '열 때마다 랜덤'][m.index]),
                      selected: mode == m,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => mode = m),
                    ),
                ],
              ),
              const Text('랜덤을 사용해도 이전 디자인 설정은 유지됩니다.'),
              DropdownButtonFormField<PaperDesign>(
                key: ValueKey('base-$base'),
                initialValue: base,
                decoration: const InputDecoration(labelText: '기본 디자인'),
                items: [
                  for (final s in PaperDesign.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(designNames[s.index]),
                    ),
                ],
                onChanged: saving || mode == DesignMode.random
                    ? null
                    : (v) => setState(() => base = v!),
              ),
              DropdownButtonFormField<int>(
                key: ValueKey('override-$paperDesign'),
                initialValue: paperDesign?.index ?? -1,
                decoration: const InputDecoration(labelText: '이 용지의 디자인'),
                items: [
                  const DropdownMenuItem(value: -1, child: Text('기본 디자인 사용')),
                  for (final s in PaperDesign.values)
                    DropdownMenuItem(
                      value: s.index,
                      child: Text(designNames[s.index]),
                    ),
                ],
                onChanged: saving || mode != DesignMode.perPaper
                    ? null
                    : (v) => setState(
                        () =>
                            paperDesign = v == -1 ? null : PaperDesign.values[v!],
                      ),
              ),
              for (final s in PaperDesign.values) ...[
                Text(designNames[s.index]),
                GameDisplay(
                  label: 'A',
                  numbers: const [3, 11, 17, 24, 32, 42],
                  design: s,
                ),
              ],
              FilledButton(
                onPressed: saving ? null : save,
                child: const Text('저장'),
              ),
            ],
          ),
  );
}
