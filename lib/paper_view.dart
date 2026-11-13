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
import 'number_display.dart';

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
  double textZoom = 1, widthZoom = 1;
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
          content: const Text(
            '이 화면은 저장한 복권 번호를 실제 종이 복권에 옮겨 적기 편하도록 만들어진 화면입니다.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인', textAlign: TextAlign.center),
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('스타일 변경')),
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
    if (!mounted) return;
    if (choice != 'numbers') {
      covered = false;
      await wake(keepOn);
      if (choice == 'background' && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('업데이트 예정입니다'),
              duration: Duration(seconds: 3),
            ),
          );
      }
      return;
    }
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

  Future<void> zoom() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('임시 확대 테스트'),
                const Text('이 화면에만 적용됩니다. 기기의 실제 확대 설정을 변경하지 않습니다.'),
                Text('글자 확대 ${(textZoom * 100).round()}%'),
                Slider(
                  key: const ValueKey('text-zoom'),
                  value: textZoom,
                  min: 1,
                  max: 3,
                  divisions: 8,
                  onChanged: (v) {
                    setState(() => textZoom = v);
                    update(() {});
                  },
                ),
                Text('표시 폭 ${(100 / widthZoom).round()}%'),
                Slider(
                  key: const ValueKey('width-zoom'),
                  value: widthZoom,
                  min: 1,
                  max: 2,
                  divisions: 4,
                  onChanged: (v) {
                    setState(() => widthZoom = v);
                    update(() {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      textZoom = 1;
                      widthZoom = 1;
                    });
                    update(() {});
                  },
                  child: const Text('확대 초기화', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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
    appBar: AppBar(
      title: Text(paper.title),
      actions: [
        IconButton(
          tooltip: '확대 테스트',
          onPressed: ready ? zoom : null,
          icon: const Icon(Icons.zoom_in),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: ready ? style : null,
                child: const Text('스타일 변경', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: ready ? edit : null,
                child: const Text('용지 내용 편집', textAlign: TextAlign.center),
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
                  LayoutBuilder(
                    builder: (context, constraints) => Center(
                      child: SizedBox(
                        width: constraints.maxWidth / widthZoom,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(
                              MediaQuery.textScalerOf(context).scale(20) /
                                  20 *
                                  textZoom,
                            ),
                          ),
                          child: GameDisplay(
                            label: String.fromCharCode(65 + i),
                            numbers: paper.games[i].numbers,
                            design: design,
                          ),
                        ),
                      ),
                    ),
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
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '게임 $label',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        NumberGrid(
          numbers: numbers,
          colored:
              design == PaperDesign.colorBasic ||
              design == PaperDesign.colorCards,
          card: design == PaperDesign.cards || design == PaperDesign.colorCards,
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
  PaperDesign base = PaperDesign.colorBasic;
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

  @override
  Widget build(BuildContext context) => ExitGuard(
    needsConfirmation: original != null && !_sameDisplay(current(), original!),
    message: '저장하지 않은 스타일 변경 사항이 있습니다. 저장하지 않고 이동하시겠습니까?',
    child: BannerScaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('번호 칸 디자인 변경'),
        ),
      ),
      bottomNavigationBar: original == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : save,
                        child: const Text('변경 완료', textAlign: TextAlign.center),
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
                child: const Text('다시 불러오기', textAlign: TextAlign.center),
              ),
            )
          : original == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '디자인 적용 방식',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                RadioGroup<DesignMode>(
                  groupValue: mode,
                  onChanged: (m) {
                    if (!saving) {
                      setState(() {
                        mode = m!;
                        if (m != DesignMode.random) normalMode = m;
                      });
                    }
                  },
                  child: Column(
                    children: [
                      for (final m in DesignMode.values)
                        RadioListTile<DesignMode>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: const VisualDensity(vertical: -4),
                          enabled: !saving,
                          value: m,
                          title: Text(
                            ['기본 디자인', '용지별 디자인', '열 때마다 랜덤'][m.index],
                            softWrap: true,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                if (mode == DesignMode.random) ...[
                  const Text(
                    '랜덤 디자인 적용 영역',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<bool>(
                    groupValue: randomAll,
                    onChanged: saving
                        ? (_) {}
                        : (value) => setState(() => randomAll = value!),
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity(vertical: -4),
                          value: true,
                          title: Text('전체 용지에 적용'),
                        ),
                        RadioListTile<bool>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity(vertical: -4),
                          value: false,
                          title: Text('현재 용지에만 적용'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (mode == DesignMode.basic) ...[
                  const Text(
                    '기본 디자인 선택',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text('기본 디자인은 모든 용지에 기본적으로 적용됩니다'),
                  const SizedBox(height: 12),
                  RadioGroup<PaperDesign>(
                    groupValue: base,
                    onChanged: (v) {
                      if (!saving && mode == DesignMode.basic) {
                        setState(() => base = v!);
                      }
                    },
                    child: Column(
                      children: [
                        for (final s in PaperDesign.values)
                          RadioListTile<PaperDesign>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(vertical: -4),
                            enabled: !saving && mode == DesignMode.basic,
                            value: s,
                            title: Text(designNames[s.index], softWrap: true),
                          ),
                      ],
                    ),
                  ),
                ],
                if (mode == DesignMode.perPaper) ...[
                  const Text(
                    '용지별 디자인 선택',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '이 용지에만 적용되는 디자인을 선택합니다. 개별 지정이 없는 용지는 기본 디자인을 사용합니다.',
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<int>(
                    groupValue: paperDesign?.index ?? -1,
                    onChanged: (v) {
                      if (!saving && mode == DesignMode.perPaper) {
                        setState(
                          () => paperDesign = v == -1
                              ? null
                              : PaperDesign.values[v!],
                        );
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<int>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: const VisualDensity(vertical: -4),
                          enabled: !saving && mode == DesignMode.perPaper,
                          value: -1,
                          title: const Text('기본 디자인 사용'),
                        ),
                        for (final s in PaperDesign.values)
                          RadioListTile<int>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(vertical: -4),
                            enabled: !saving && mode == DesignMode.perPaper,
                            value: s.index,
                            title: Text(designNames[s.index], softWrap: true),
                          ),
                      ],
                    ),
                  ),
                ],
                if (mode == DesignMode.random && !randomAll)
                  const Text('전체 랜덤이 해제됩니다. 다른 용지는 기존 설정으로 돌아갑니다.'),
                const SizedBox(height: 24),
                const Text(
                  '번호 칸 디자인 예시',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
