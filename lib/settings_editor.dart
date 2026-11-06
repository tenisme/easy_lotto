import 'package:flutter/material.dart';
import 'banner_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'local_storage.dart';
import 'domain/recommendation.dart';
import 'preset_store.dart';
import 'exit_guard.dart';
import 'library.dart';

void _validateGeneration(
  (RecommendationOptions, List<DrawResult>, int) request,
) {
  RecommendationEngine().generate(
    request.$1,
    draws: request.$2,
    count: request.$3,
  );
}

/// Edits a temporary preset; returning an option does not persist it.
class SettingsEditor extends StatefulWidget {
  const SettingsEditor({
    super.key,
    this.initial,
    this.draws = const [],
    this.presetId,
    this.onSaved,
    this.completeOnly = false,
    this.generationCount = 1,
  });
  final RecommendationOptions? initial;
  final List<DrawResult> draws;
  final String? presetId;
  final ValueChanged<Preset>? onSaved;
  final bool completeOnly;
  final int generationCount;
  @override
  State<SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<SettingsEditor> {
  late String? presetId = widget.presetId;
  bool saving = false;
  RecommendationOptions currentOptions() => RecommendationOptions(
    fixed: fixed,
    excluded: excluded,
    oddCount: odd,
    lowCount: low,
    minSum: sum.start.round(),
    maxSum: sum.end.round(),
    groupCount: groups,
    excludePrevious: previous,
    previousIncludesBonus: previousBonus,
    missingCount: missing,
    missingRounds: missingRounds,
    missingIncludesBonus: missingBonus,
    groupLengths: groups == 1
        ? oneLengths
        : groups == 2
        ? twoLengths
        : null,
  );
  Future<bool> save({bool rename = false, bool confirmOverwrite = true}) async {
    String? name;
    if (confirmOverwrite &&
        !rename &&
        presetId != null &&
        !sameOptions(currentOptions(), presetStore.find(presetId)!.options)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('변경한 설정을 저장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니요', textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('네', textAlign: TextAlign.center),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return false;
    }
    if (presetId == null || rename) {
      final controller = TextEditingController(
        text: presetStore.find(presetId)?.name ?? presetStore.defaultName(),
      );
      name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(rename ? '이름 변경' : '설정 저장'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '설정 이름'),
              ),
              const Text('이름은 나중에 변경할 수 있습니다.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('저장', textAlign: TextAlign.center),
            ),
          ],
        ),
      );
      // Dialog transition may still reference the controller during dismissal.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      if (name == null || !mounted) return false;
    }
    setState(() => saving = true);
    try {
      final preset = await presetStore.save(
        rename ? presetStore.find(presetId)!.options : currentOptions(),
        id: presetId,
        name: name,
      );
      if (!mounted) return false;
      setState(() => presetId = preset.id);
      widget.onSaved?.call(preset);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정을 저장했습니다.')));
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ArgumentError
                  ? error.message.toString()
                  : '설정 저장에 실패했습니다. 다시 시도하십시오.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  late Set<int> fixed;
  late Set<int> excluded;
  int? odd, low, groups;
  bool previous = false, previousBonus = true, missingBonus = true;
  int? missing;
  int missingRounds = 5;
  Set<int> customRounds = {};
  List<int>? oneLengths, twoLengths;
  RangeValues sum = const RangeValues(21, 255);
  @override
  void initState() {
    super.initState();
    load(widget.initial ?? RecommendationOptions());
    loadPeriods();
  }

  Future<void> loadPeriods() async {
    try {
      final raw = (await LocalStorage.getInstance()).getString(
        'missingPeriods.v1',
      );
      if (raw != null && mounted) {
        setState(
          () => customRounds = (jsonDecode(raw) as List)
              .cast<int>()
              .where((n) => n > 0)
              .toSet(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장한 기준 기간을 불러오지 못했습니다.')));
      }
    }
  }

  Future<void> savePeriod(int n, {bool remove = false}) async {
    final next = {...customRounds};
    if (remove) {
      next.remove(n);
    } else {
      next.add(n);
    }
    try {
      await (await LocalStorage.getInstance()).setString(
        'missingPeriods.v1',
        jsonEncode(next.toList()..sort()),
      );
      if (mounted) {
        setState(() {
          customRounds = next;
          if (!remove) missingRounds = n;
          if (remove && missingRounds == n) missingRounds = 5;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기준 기간을 저장하지 못했습니다.')));
      }
    }
  }

  int get availablePeriods {
    final rounds = widget.draws.map((d) => d.round).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (rounds.isEmpty) return 0;
    var count = 1;
    while (count < rounds.length && rounds[count] == rounds.first - count) {
      count++;
    }
    return count;
  }

  Future<void> enterPeriod() async {
    final controller = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final n = int.tryParse(controller.text);
          final valid = n != null && n >= 1 && n <= availablePeriods;
          return AlertDialog(
            title: const Text('미출현 기준 기간 직접 입력'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '최근 회차 수',
                helperText: '1~$availablePeriods회',
                errorText: controller.text.isNotEmpty && !valid
                    ? '사용 가능한 범위의 정수를 입력하십시오.'
                    : null,
              ),
              onChanged: (_) => update(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', textAlign: TextAlign.center),
              ),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(context, n) : null,
                child: const Text('확인', textAlign: TextAlign.center),
              ),
            ],
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (mounted && n != null) await savePeriod(n);
  }

  Future<void> complete() async {
    if (widget.completeOnly) {
      final stored =
          presetStore.find(presetId)?.options ??
          widget.initial ??
          RecommendationOptions();
      if (!sameOptions(currentOptions(), stored)) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('저장하고 나가시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('저장하지 않음', textAlign: TextAlign.center),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('저장하고 나가기', textAlign: TextAlign.center),
              ),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        if (choice && !await save(confirmOverwrite: false)) return;
      }
    } else {
      setState(() => saving = true);
      try {
        await compute(_validateGeneration, (
          currentOptions(),
          widget.draws,
          widget.generationCount,
        ));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is GenerationException
                    ? e.message
                    : '조건을 확인하지 못했습니다. 다시 시도하십시오.',
              ),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
    if (mounted) Navigator.pop(context, currentOptions());
  }

  void load(RecommendationOptions o) {
    fixed = o.fixed.toSet();
    excluded = o.excluded.toSet();
    odd = o.oddCount;
    low = o.lowCount;
    groups = o.groupCount;
    previous = o.excludePrevious;
    previousBonus = o.previousIncludesBonus;
    missing = o.missingCount;
    missingRounds = o.missingRounds;
    missingBonus = o.missingIncludesBonus;
    oneLengths = o.groupCount == 1 ? o.groupLengths : null;
    twoLengths = o.groupCount == 2 ? o.groupLengths : null;
    sum = RangeValues(o.minSum.toDouble(), o.maxSum.toDouble());
  }

  Future<void> pickNumbers(bool isFixed) async {
    bool favoritesOnly = false;
    final selected = {...(isFixed ? fixed : excluded)};
    final blocked = isFixed ? excluded : fixed;
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(isFixed ? '고정수 선택' : '제외수 선택'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () =>
                        update(() => favoritesOnly = !favoritesOnly),
                    child: Text(
                      favoritesOnly ? '전체 번호 보기' : '내 번호에서 선택',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var n = 1; n <= 45; n++)
                        if (!favoritesOnly || libraryStore.numbers.contains(n))
                          FilterChip(
                            showCheckmark: false,
                            label: Text('$n'),
                            selected: selected.contains(n),
                            onSelected:
                                blocked.contains(n) ||
                                    (!selected.contains(n) &&
                                        selected.length >= (isFixed ? 6 : 39))
                                ? null
                                : (value) => update(() {
                                    if (value) {
                                      selected.add(n);
                                    } else {
                                      selected.remove(n);
                                    }
                                  }),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('적용', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isFixed) {
          fixed = result;
        } else {
          excluded = result;
        }
      });
    }
  }

  Widget countField(
    String label,
    int? value,
    ValueChanged<int?> changed, {
    int max = 6,
  }) => DropdownButtonFormField<int>(
    key: ValueKey('$label-$value'),
    initialValue: value ?? -1,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: -1, child: Text('제한 없음')),
      for (var n = 0; n <= max; n++)
        DropdownMenuItem(value: n, child: Text('$n개')),
    ],
    onChanged: (v) => setState(() => changed(v == -1 ? null : v)),
  );
  @override
  Widget build(BuildContext context) => ExitGuard(
    needsConfirmation: !sameOptions(
      currentOptions(),
      presetStore.find(presetId)?.options ??
          widget.initial ??
          RecommendationOptions(),
    ),
    message: '저장하지 않은 설정 변경 사항이 있습니다. 저장하지 않고 이동하시겠습니까?',
    child: BannerScaffold(
      appBar: AppBar(
        title: const Text('상세 규칙'),
        actions: [
          if (presetId != null)
            TextButton(
              onPressed: saving ? null : () => save(rename: true),
              child: const Text('이름 변경', textAlign: TextAlign.center),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : save,
                  child: const Text('설정 저장', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : complete,
                  child: Text(
                    widget.completeOnly ? '설정 완료' : '번호 생성',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: saving,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('설정을 저장하지 않고 번호를 생성할 수 있습니다.'),
              ListTile(
                title: const Text('고정수'),
                subtitle: Text(
                  fixed.isEmpty ? '선택 없음' : (fixed.toList()..sort()).join(', '),
                ),
                trailing: const Icon(Icons.edit),
                onTap: () => pickNumbers(true),
              ),
              ListTile(
                title: const Text('제외수'),
                subtitle: Text(
                  excluded.isEmpty
                      ? '선택 없음'
                      : (excluded.toList()..sort()).join(', '),
                ),
                trailing: const Icon(Icons.edit),
                onTap: () => pickNumbers(false),
              ),
              countField('홀수 개수', odd, (v) => odd = v),
              countField('낮은 수 개수 (1~22)', low, (v) => low = v),
              const SizedBox(height: 24),
              Text('총합 범위: ${sum.start.round()}~${sum.end.round()}'),
              RangeSlider(
                values: sum,
                min: 21,
                max: 255,
                divisions: 234,
                labels: RangeLabels(
                  '${sum.start.round()}',
                  '${sum.end.round()}',
                ),
                onChanged: (v) => setState(() => sum = v),
              ),
              const Text('연속수'),
              Wrap(
                spacing: 4,
                children: [
                  for (final g in <int?>[0, 1, 2, 3, null])
                    ChoiceChip(
                      label: Text(
                        g == null
                            ? '제한 없음'
                            : g == 0
                            ? '제외'
                            : '$g묶음',
                      ),
                      selected: groups == g,
                      onSelected: (_) => setState(() => groups = g),
                    ),
                ],
              ),
              if (groups == 1 || groups == 2)
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'lengths-$groups-${groups == 1 ? oneLengths : twoLengths}',
                  ),
                  initialValue:
                      (groups == 1 ? oneLengths : twoLengths)?.join('+') ??
                      'any',
                  decoration: const InputDecoration(labelText: '연속 묶음 구성'),
                  items: [
                    const DropdownMenuItem(value: 'any', child: Text('제한 없음')),
                    for (final s
                        in groups == 1
                            ? ['2', '3', '4', '5', '6']
                            : ['2+2', '2+3', '2+4', '3+3'])
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() {
                    final lengths = v == null || v == 'any'
                        ? null
                        : v.split('+').map(int.parse).toList();
                    if (groups == 1) {
                      oneLengths = lengths;
                    } else {
                      twoLengths = lengths;
                    }
                  }),
                ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('직전 회차 번호 제외'),
                value: previous,
                onChanged: widget.draws.isEmpty
                    ? null
                    : (v) => setState(() => previous = v),
              ),
              if (previous)
                SwitchListTile(
                  title: const Text('보너스 포함 7개 제외'),
                  value: previousBonus,
                  onChanged: (v) => setState(() => previousBonus = v),
                ),
              if (widget.draws.length >= 5) ...[
                DropdownButtonFormField<int>(
                  initialValue: missing ?? 0,
                  decoration: const InputDecoration(labelText: '미출현 번호 포함 수'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('사용 안 함')),
                    for (var n = 1; n <= 6; n++)
                      DropdownMenuItem(value: n, child: Text('$n개')),
                  ],
                  onChanged: (v) => setState(() => missing = v == 0 ? null : v),
                ),
                const Text('미출현 기준 기간'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in [1, 5, 10])
                      ChoiceChip(
                        label: Text('최근 $n회'),
                        selected: missingRounds == n,
                        onSelected: n > availablePeriods
                            ? null
                            : (_) => setState(() => missingRounds = n),
                      ),
                    for (final n in ({
                      ...customRounds,
                      if (![1, 5, 10].contains(missingRounds)) missingRounds,
                    }.toList()..sort()))
                      if (![1, 5, 10].contains(n))
                        InputChip(
                          label: Text('최근 $n회'),
                          selected: missingRounds == n,
                          onPressed: n > availablePeriods
                              ? null
                              : () => setState(() => missingRounds = n),
                          onDeleted: () => savePeriod(n, remove: true),
                        ),
                    ActionChip(
                      label: const Text('직접 입력'),
                      onPressed: enterPeriod,
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('보너스 포함 7개로 출현 판정'),
                  value: missingBonus,
                  onChanged: (v) => setState(() => missingBonus = v),
                ),
              ] else
                const Text('미출현 규칙은 최근 5회 데이터 저장 후 사용할 수 있습니다.'),
              TextButton(
                onPressed: () => setState(() => load(RecommendationOptions())),
                child: const Text('모든 설정 초기화', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
