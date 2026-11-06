import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'banner_scaffold.dart';
import 'local_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'display_preferences.dart';
import 'domain/recommendation.dart';
import 'paper_store.dart';
import 'paper_flow.dart';
import 'exit_guard.dart';

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
      final prefs = await LocalStorage.getInstance();
      if (!mounted) return;
      setState(() {
        design = preferences.resolve(paper.id, random);
        keepOn = prefs.getBool('keepScreenOn.v1') ?? false;
        ready = true;
      });
      await wake(
        keepOn &&
            !covered &&
            (WidgetsBinding.instance.lifecycleState == null ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed),
      );
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
  Widget build(BuildContext context) => BannerScaffold(
    appBar: AppBar(title: Text(paper.title)),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: ready ? style : null,
                child: const Text('스타일 변경'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: ready ? edit : null,
                child: const Text('용지 내용 편집'),
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
                  onChanged: (v) async {
                    try {
                      await (await LocalStorage.getInstance()).setBool(
                        'keepScreenOn.v1',
                        v,
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('화면 켜기 설정을 저장하지 못했습니다.')),
                      );
                      return;
                    }
                    if (!context.mounted) return;
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
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(design == PaperDesign.cards ? 16 : 4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '게임 $label',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(
                    design == PaperDesign.cards ? 6 : 30,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
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
  DesignMode normalMode = DesignMode.basic;
  bool randomAll = true;
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
          normalMode = p.mode == DesignMode.random
              ? p.beforeRandomMode
              : p.mode;
          randomAll =
              p.mode == DesignMode.random ||
              !p.randomPapers.contains(widget.paperId);
          if (p.randomPapers.contains(widget.paperId) &&
              p.mode != DesignMode.random) {
            mode = DesignMode.random;
          }
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

  DisplayPreferences current() {
    final overrides = {...original!.overrides};
    if (paperDesign == null) {
      overrides.remove(widget.paperId);
    } else {
      overrides[widget.paperId] = paperDesign!;
    }
    final randomPapers = {...original!.randomPapers};
    if (mode == DesignMode.random && !randomAll) {
      randomPapers.add(widget.paperId);
    } else if (mode != DesignMode.random) {
      randomPapers.remove(widget.paperId);
    }
    return DisplayPreferences(
      mode: mode == DesignMode.random && !randomAll ? normalMode : mode,
      defaultDesign: base,
      overrides: overrides,
      randomPapers: randomPapers,
      beforeRandomMode: normalMode,
    );
  }

  Future<void> save() async {
    final next = current();
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

  Future<void> details() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('스타일 상세 설정')),
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: const Text('배경 이미지 변경'),
              onTap: () => Navigator.pop(context, 'background'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('번호 칸 디자인 변경'),
              onTap: () => Navigator.pop(context, 'numbers'),
            ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('업데이트 예정입니다'),
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ExitGuard(
    needsConfirmation: original != null && !_sameDisplay(current(), original!),
    message: '저장하지 않은 스타일 변경 사항이 있습니다. 저장하지 않고 이동하시겠습니까?',
    child: BannerScaffold(
      appBar: AppBar(title: const Text('스타일 변경')),
      bottomNavigationBar: original == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : details,
                        child: const Text('스타일 상세 설정'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : save,
                        child: const Text('변경 완료'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                const Text('앱 테마를 따릅니다. 여기서는 번호 표시 형태와 간격을 변경합니다.'),
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
                            : (_) => setState(() {
                                mode = m;
                                if (m != DesignMode.random) normalMode = m;
                              }),
                      ),
                  ],
                ),
                const Text('랜덤을 사용해도 이전 디자인 설정은 유지됩니다.'),
                if (mode == DesignMode.random)
                  RadioGroup<bool>(
                    groupValue: randomAll,
                    onChanged: saving
                        ? (_) {}
                        : (value) => setState(() => randomAll = value!),
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          value: true,
                          title: Text('전체 용지에 적용'),
                        ),
                        RadioListTile<bool>(
                          value: false,
                          title: Text('현재 용지에만 적용'),
                        ),
                      ],
                    ),
                  ),
                DropdownButtonFormField<PaperDesign>(
                  key: ValueKey('base-$base'),
                  initialValue: base,
                  decoration: const InputDecoration(
                    labelText: '기본 디자인 · 모든 용지 공통',
                  ),
                  items: [
                    for (final s in PaperDesign.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(designNames[s.index]),
                      ),
                  ],
                  onChanged: saving || mode != DesignMode.basic
                      ? null
                      : (v) => setState(() => base = v!),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('override-$paperDesign'),
                  initialValue: paperDesign?.index ?? -1,
                  decoration: InputDecoration(
                    labelText: '이 용지의 디자인',
                    helperText: '이 용지에만 적용됩니다. 개별 지정이 없는 용지는 기본 디자인을 사용합니다.',
                  ),
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
                          () => paperDesign = v == -1
                              ? null
                              : PaperDesign.values[v!],
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
              ],
            ),
    ),
  );
}

bool _sameDisplay(DisplayPreferences a, DisplayPreferences b) =>
    a.mode == b.mode &&
    a.defaultDesign == b.defaultDesign &&
    mapEquals(a.overrides, b.overrides) &&
    setEquals(a.randomPapers, b.randomPapers) &&
    (a.mode != DesignMode.random || a.beforeRandomMode == b.beforeRandomMode);
