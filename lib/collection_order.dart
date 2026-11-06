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

class CollectionOrder<T> extends StatefulWidget {
  const CollectionOrder({
    super.key,
    required this.storageKey,
    required this.items,
    required this.id,
    required this.builder,
    this.name,
  });
  final String storageKey;
  final List<T> items;
  final String Function(T) id;
  final String Function(T)? name;
  final Widget Function(T) builder;
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
    if (mounted) setState(() => ready = true);
  }

  List<T> sorted() {
    final items = [...widget.items];
    if (mode == 'name' && widget.name != null) {
      items.sort((a, b) => naturalCompare(widget.name!(a), widget.name!(b)));
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
      await (await LocalStorage.getInstance()).setString(
        widget.storageKey,
        jsonEncode({'mode': nextMode, 'order': nextOrder}),
      );
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
            const DropdownMenuItem(value: 'newest', child: Text('등록순 · 최신 먼저')),
            const DropdownMenuItem(value: 'oldest', child: Text('등록순 · 오래된 순')),
            if (widget.name != null)
              const DropdownMenuItem(value: 'name', child: Text('이름순')),
            const DropdownMenuItem(value: 'manual', child: Text('사용자 지정 순서')),
          ],
          onChanged: saving || !ready
              ? null
              : (v) => persist(
                  v!,
                  order.isEmpty ? items.map(widget.id).toList() : order,
                ),
        ),
        if (mode == 'manual') const Text('화살표로 순서를 변경합니다.'),
        for (var i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: widget.builder(items[i])),
              if (mode == 'manual')
                Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      visualDensity: VisualDensity.standard,
                      tooltip: '항목 위로 이동',
                      onPressed: saving || i == 0
                          ? null
                          : () {
                              final ids = items.map(widget.id).toList();
                              final id = ids.removeAt(i);
                              ids.insert(i - 1, id);
                              persist(mode, ids);
                            },
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      visualDensity: VisualDensity.standard,
                      tooltip: '항목 아래로 이동',
                      onPressed: saving || i == items.length - 1
                          ? null
                          : () {
                              final ids = items.map(widget.id).toList();
                              final id = ids.removeAt(i);
                              ids.insert(i + 1, id);
                              persist(mode, ids);
                            },
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
