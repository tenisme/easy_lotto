import 'dart:convert';
import 'package:flutter/material.dart';
import 'local_storage.dart';

/// Numeric-aware names: 설정2 precedes 설정10 without converting long IDs.
int naturalCompare(String a, String b) {
  final pattern = RegExp(r'\d+|\D+');
  final aa = pattern.allMatches(a).map((m) => m.group(0)!).toList();
  final bb = pattern.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < aa.length && i < bb.length; i++) {
    final an = BigInt.tryParse(aa[i]), bn = BigInt.tryParse(bb[i]);
    final c = an != null && bn != null
        ? an.compareTo(bn)
        : aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  return aa.length.compareTo(bb.length);
}

int nameCompare(String a, String b) {
  final aa = a.trimLeft(), bb = b.trimLeft();
  int rank(String s) {
    if (s.isEmpty) return 5;
    final n = s.runes.first, first = String.fromCharCode(n);
    if (RegExp(r'^[\p{P}\p{S}]', unicode: true).hasMatch(first)) return 0;
    if (RegExp(r'^\p{N}', unicode: true).hasMatch(first)) return 1;
    if ((n >= 0xac00 && n <= 0xd7a3) ||
        (n >= 0x1100 && n <= 0x11ff) ||
        (n >= 0x3130 && n <= 0x318f) ||
        (n >= 0xa960 && n <= 0xa97f) ||
        (n >= 0xd7b0 && n <= 0xd7ff)) {
      return 2;
    }
    if ((n >= 65 && n <= 90) || (n >= 97 && n <= 122)) return 3;
    return 4;
  }

  final category = rank(aa).compareTo(rank(bb));
  return category != 0
      ? category
      : naturalCompare(aa.toLowerCase(), bb.toLowerCase());
}

class CollectionOrder<T> extends StatefulWidget {
  const CollectionOrder({
    super.key,
    required this.storageKey,
    required this.items,
    required this.id,
    required this.builder,
    this.name,
    this.inlineBuilder,
    this.belowSort,
  });
  final String storageKey;
  final List<T> items;
  final String Function(T) id;
  final String Function(T)? name;
  final Widget Function(T) builder;
  final Widget Function(T, Widget?)? inlineBuilder;
  final Widget? belowSort;
  @override
  State<CollectionOrder<T>> createState() => _CollectionOrderState<T>();
}

class _CollectionOrderState<T> extends State<CollectionOrder<T>> {
  String mode = 'newest';
  List<String> order = [];
  bool saving = false, ready = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = (await LocalStorage.getInstance()).getString(
        widget.storageKey,
      );
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        mode = j['mode'] as String;
        order = (j['order'] as List).cast<String>();
      }
    } catch (_) {
      /* A damaged ordering preference must not hide user data. */
    }
    if (!['newest', 'oldest', 'name', 'nameReverse', 'manual'].contains(mode) ||
        (widget.name == null && (mode == 'name' || mode == 'nameReverse'))) {
      mode = 'newest';
    }
    if (mounted) setState(() => ready = true);
  }

  List<T> sorted() {
    final items = [...widget.items];
    if ((mode == 'name' || mode == 'nameReverse') && widget.name != null) {
      items.sort((a, b) {
        final result = nameCompare(widget.name!(a), widget.name!(b));
        final comparison = result == 0
            ? naturalCompare(widget.id(a), widget.id(b))
            : result;
        return mode == 'nameReverse' ? -comparison : comparison;
      });
    } else if (mode == 'manual') {
      final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
      final original = {
        for (var i = 0; i < items.length; i++) widget.id(items[i]): i,
      };
      items.sort(
        (a, b) => (rank[widget.id(a)] ?? order.length + original[widget.id(a)]!)
            .compareTo(
              rank[widget.id(b)] ?? order.length + original[widget.id(b)]!,
            ),
      );
    } else if (mode == 'newest') {
      if (items.every((item) => BigInt.tryParse(widget.id(item)) != null)) {
        items.sort((a, b) => naturalCompare(widget.id(b), widget.id(a)));
        return items;
      }
      return items.reversed.toList();
    } else if (mode == 'oldest' &&
        items.every((item) => BigInt.tryParse(widget.id(item)) != null)) {
      items.sort((a, b) => naturalCompare(widget.id(a), widget.id(b)));
    }
    return items;
  }

  Future<void> persist(String nextMode, List<String> nextOrder) async {
    setState(() => saving = true);
    try {
      final saved = await (await LocalStorage.getInstance()).setString(
        widget.storageKey,
        jsonEncode({'mode': nextMode, 'order': nextOrder}),
      );
      if (!saved) throw StateError('정렬 설정 저장 실패');
      if (mounted) {
        setState(() {
          mode = nextMode;
          order = nextOrder;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('정렬 설정을 저장하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = sorted();
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(mode),
          initialValue: mode,
          decoration: const InputDecoration(labelText: '정렬'),
          items: [
            const DropdownMenuItem(value: 'newest', child: Text('최신 등록 순')),
            const DropdownMenuItem(value: 'oldest', child: Text('오래된 등록 순')),
            if (widget.name != null)
              const DropdownMenuItem(value: 'name', child: Text('이름 순')),
            if (widget.name != null)
              const DropdownMenuItem(
                value: 'nameReverse',
                child: Text('이름 역순'),
              ),
            const DropdownMenuItem(value: 'manual', child: Text('사용자 지정 순서')),
          ],
          onChanged: saving || !ready
              ? null
              : (v) => persist(
                  v!,
                  order.isEmpty ? items.map(widget.id).toList() : order,
                ),
        ),
        const SizedBox(height: 16),
        if (widget.belowSort != null) widget.belowSort!,
        if (mode == 'manual') const Text('화살표로 순서를 변경합니다.'),
        for (var i = 0; i < items.length; i++)
          if (widget.inlineBuilder != null)
            widget.inlineBuilder!(
              items[i],
              mode == 'manual' ? controls(items, i) : null,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: widget.builder(items[i])),
                if (mode == 'manual') controls(items, i),
              ],
            ),
      ],
    );
  }

  Widget controls(List<T> items, int index) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final direction in [-1, 1])
        Tooltip(
          message: direction < 0 ? '항목 위로 이동' : '항목 아래로 이동',
          child: Semantics(
            button: true,
            enabled:
                !saving &&
                index + direction >= 0 &&
                index + direction < items.length,
            child: InkResponse(
              onTap:
                  saving ||
                      index + direction < 0 ||
                      index + direction >= items.length
                  ? null
                  : () {
                      final ids = items.map(widget.id).toList(),
                          id = ids.removeAt(index);
                      ids.insert(index + direction, id);
                      persist(mode, ids);
                    },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Align(
                  alignment: Alignment(direction < 0 ? 0.5 : -0.5, 0),
                  child: Icon(
                    direction < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 24,
                    color:
                        saving ||
                            index + direction < 0 ||
                            index + direction >= items.length
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
