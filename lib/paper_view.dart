import 'word_wrap_text.dart';
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
import 'selection_tiles.dart';
import 'style_reset_dialog.dart';

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
  PaperDesign design = PaperDesign.colorBasic;
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
              child: const WordWrapText('확인', textAlign: TextAlign.center),
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
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('스타일 초기화'),
              onTap: () => Navigator.pop(context, 'reset'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'reset') {
      var resetNumbers = false;
      final preferences = await showDialog<DisplayPreferences>(
        context: context,
        builder: (_) => StyleResetDialog(
          paperId: paper.id,
          onResetNumbers: (value) => resetNumbers = value,
        ),
      );
      if (!mounted) return;
      covered = false;
      if (preferences != null && resetNumbers) {
        setState(() => design = preferences.resolve(paper.id, random));
      }
      await wake(keepOn);
      return;
    }
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
                  child: const WordWrapText(
                    '확대 초기화',
                    textAlign: TextAlign.center,
                  ),
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
                child: const WordWrapText(
                  '스타일 변경',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: ready ? edit : null,
                child: const WordWrapText(
                  '용지 내용 편집',
                  textAlign: TextAlign.center,
                ),
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
  PaperDesign base = PaperDesign.colorBasic;
  bool baseRandom = false,
      overwrite = false,
      localTouched = false,
      saving = false,
      loadFailed = false;
  int? localChoice;
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
          mode = p.mode == DesignMode.random ? DesignMode.basic : p.mode;
          base = p.defaultDesign;
          baseRandom = p.isDefaultRandom;
          overwrite = p.overwriteOverrides || p.mode == DesignMode.random;
          localChoice = p.randomPapers.contains(widget.paperId)
              ? -1
              : p.overrides[widget.paperId]?.index;
          localTouched = false;
          loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadFailed = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('디자인 설정을 불러오지 못했습니다.')));
      }
    }
  }

  DisplayPreferences current() {
    final local = {...original!.overrides},
        random = {...original!.randomPapers};
    if (localTouched) {
      if (localChoice == -1) {
        random.add(widget.paperId);
      } else {
        random.remove(widget.paperId);
        local[widget.paperId] = PaperDesign.values[localChoice!];
      }
    }
    return DisplayPreferences(
      mode: mode,
      defaultDesign: base,
      defaultRandom: baseRandom,
      overwriteOverrides: overwrite,
      overrides: local,
      randomPapers: random,
      beforeRandomMode: original!.beforeRandomMode,
      backgrounds: original!.backgrounds,
      defaultBackground: original!.defaultBackground,
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

  Widget heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );
  Widget choices({required bool global}) => RadioGroup<int>(
    groupValue: global
        ? (baseRandom ? -1 : base.index)
        : (localChoice ?? (baseRandom ? -1 : base.index)),
    onChanged: (v) {
      if (!saving) {
        setState(() {
          if (global) {
            baseRandom = v == -1;
            if (v != -1) base = PaperDesign.values[v!];
          } else {
            localChoice = v;
            localTouched = true;
          }
        });
      }
    },
    child: Column(
      children: [
        for (final value in [
          ...List.generate(PaperDesign.values.length, (i) => i),
          -1,
        ])
          RadioListTile<int>(
            enabled: !saving,
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: const VisualDensity(vertical: -4),
            value: value,
            title: Text(value == -1 ? '열 때마다 랜덤' : designNames[value]),
          ),
      ],
    ),
  );
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
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: const WordWrapText('변경 완료'),
                ),
              ),
            ),
      body: loadFailed
          ? Center(
              child: TextButton(
                onPressed: load,
                child: const WordWrapText('다시 불러오기'),
              ),
            )
          : original == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                heading('디자인 적용 방식'),
                const SizedBox(height: 12),
                RadioGroup<DesignMode>(
                  groupValue: mode,
                  onChanged: (v) {
                    if (!saving) setState(() => mode = v!);
                  },
                  child: Column(
                    children: [
                      for (final scope in [
                        DesignMode.basic,
                        DesignMode.perPaper,
                      ])
                        RadioListTile<DesignMode>(
                          enabled: !saving,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: const VisualDensity(vertical: -4),
                          value: scope,
                          title: Text(
                            scope == DesignMode.basic ? '기본 디자인' : '용지별 디자인',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (mode == DesignMode.basic) ...[
                  heading('기본 디자인 선택'),
                  const Text('기본 디자인은 모든 용지에 기본적으로 적용됩니다'),
                  const SizedBox(height: 16),
                  const Text(
                    '용지별 디자인 덮어쓰기 여부',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectionTiles(
                    labels: const ['유지하기', '덮어쓰기'],
                    columns: 2,
                    selected: overwrite ? 1 : 0,
                    onChanged: saving
                        ? null
                        : (i) => setState(() => overwrite = i == 1),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '용지별 디자인 설정을 유지한 채로 나머지 용지의 기본 디자인을 변경합니다.',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "용지별 디자인 설정과 상관 없이 선택한 디자인으로 전부 덮어씁니다. 단, 이전 디자인 정보는 저장되어 있으므로 '유지하기'를 선택하면 다시 이전에 저장했던 용지별 디자인으로 돌아갑니다.",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  choices(global: true),
                ] else ...[
                  heading('용지별 디자인 선택'),
                  const Text(
                    '이 용지에만 적용되는 디자인을 선택합니다. 개별 지정이 없는 용지는 기본 디자인을 사용합니다.',
                  ),
                  if (overwrite)
                    const Text(
                      "현재 전체 덮어쓰기가 적용 중입니다. 개별 설정은 기본 디자인의 '유지하기'를 선택하면 표시됩니다.",
                    ),
                  const SizedBox(height: 12),
                  choices(global: false),
                ],
                const SizedBox(height: 24),
                heading('번호 칸 디자인 예시'),
                const SizedBox(height: 12),
                for (final design in PaperDesign.values) ...[
                  Text(designNames[design.index]),
                  GameDisplay(
                    label: 'A',
                    numbers: const [3, 11, 17, 24, 32, 42],
                    design: design,
                  ),
                ],
              ],
            ),
    ),
  );
}

bool _sameDisplay(DisplayPreferences a, DisplayPreferences b) =>
    (a.mode == DesignMode.random ? DesignMode.basic : a.mode) ==
        (b.mode == DesignMode.random ? DesignMode.basic : b.mode) &&
    a.defaultDesign == b.defaultDesign &&
    a.isDefaultRandom == b.isDefaultRandom &&
    (a.overwriteOverrides || a.mode == DesignMode.random) ==
        (b.overwriteOverrides || b.mode == DesignMode.random) &&
    mapEquals(a.overrides, b.overrides) &&
    setEquals(a.randomPapers, b.randomPapers) &&
    a.defaultBackground == b.defaultBackground &&
    mapEquals(a.backgrounds, b.backgrounds);
