import 'package:flutter/material.dart';
import 'domain/recommendation.dart';

/// Edits a temporary preset; returning an option does not persist it.
class SettingsEditor extends StatefulWidget {
  const SettingsEditor({super.key, this.initial, this.draws = const []});
  final RecommendationOptions? initial;
  final List<DrawResult> draws;
  @override
  State<SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<SettingsEditor> {
  late Set<int> fixed;
  late Set<int> excluded;
  int? odd, low, groups;
  bool previous = false, previousBonus = true, missingBonus = true;
  int? missing;
  int missingRounds = 5;
  List<int>? oneLengths, twoLengths;
  RangeValues sum = const RangeValues(21, 255);
  @override
  void initState() {
    super.initState();
    load(widget.initial ?? RecommendationOptions());
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
              child: Wrap(
                spacing: 4,
                children: [
                  for (var n = 1; n <= 45; n++)
                    FilterChip(
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('적용'),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('상세 설정')),
    body: SafeArea(
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
            labels: RangeLabels('${sum.start.round()}', '${sum.end.round()}'),
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
                  (groups == 1 ? oneLengths : twoLengths)?.join('+') ?? 'any',
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
            DropdownButtonFormField<int>(
              initialValue: missingRounds,
              decoration: const InputDecoration(labelText: '미출현 기준 기간'),
              items: [
                for (var n = 1; n <= widget.draws.length && n <= 100; n++)
                  DropdownMenuItem(value: n, child: Text('최근 $n회')),
              ],
              onChanged: (v) => setState(() => missingRounds = v!),
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
            child: const Text('모든 설정 초기화'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              RecommendationOptions(
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
              ),
            ),
            child: const Text('번호 생성'),
          ),
        ],
      ),
    ),
  );
}
