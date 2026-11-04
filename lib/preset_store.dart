import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_storage.dart';
import 'domain/recommendation.dart';

Map<String, Object?> encodeOptions(RecommendationOptions o) => {
  'version': 1,
  'fixed': o.fixed,
  'excluded': o.excluded,
  'odd': o.oddCount,
  'low': o.lowCount,
  'min': o.minSum,
  'max': o.maxSum,
  'groups': o.groupCount,
  'lengths': o.groupLengths,
  'previous': o.excludePrevious,
  'previousBonus': o.previousIncludesBonus,
  'missing': o.missingCount,
  'period': o.missingRounds,
  'missingBonus': o.missingIncludesBonus,
};
RecommendationOptions decodeOptions(Map<String, dynamic> j) {
  if (j['version'] != 1) throw const FormatException('알 수 없는 설정 버전');
  return RecommendationOptions(
    fixed: (j['fixed'] as List).cast<int>(),
    excluded: (j['excluded'] as List).cast<int>(),
    oddCount: j['odd'] as int?,
    lowCount: j['low'] as int?,
    minSum: j['min'] as int,
    maxSum: j['max'] as int,
    groupCount: j['groups'] as int?,
    groupLengths: (j['lengths'] as List?)?.cast<int>(),
    excludePrevious: j['previous'] as bool,
    previousIncludesBonus: j['previousBonus'] as bool,
    missingCount: j['missing'] as int?,
    missingRounds: j['period'] as int,
    missingIncludesBonus: j['missingBonus'] as bool,
  );
}

bool sameOptions(RecommendationOptions a, RecommendationOptions b) =>
    jsonEncode(encodeOptions(a)) == jsonEncode(encodeOptions(b));

class Preset {
  const Preset(this.id, this.name, this.options);
  final String id, name;
  final RecommendationOptions options;
}

class PresetStore extends ChangeNotifier {
  List<Preset> items = [];
  String? selectedId;
  Preset? find(String? id) => items.where((p) => p.id == id).firstOrNull;
  Future<void> load() async {
    final prefs = await LocalStorage.getInstance();
    final body = prefs.getString('presets.v1');
    if (body == null) {
      items = [];
      selectedId = null;
      notifyListeners();
      return;
    }
    final j = jsonDecode(body) as Map<String, dynamic>;
    final loaded = (j['items'] as List)
        .map(
          (v) => Preset(
            v['id'] as String,
            v['name'] as String,
            decodeOptions(v['options'] as Map<String, dynamic>),
          ),
        )
        .toList();
    items = loaded;
    selectedId = find(j['selected'] as String?)?.id;
    notifyListeners();
  }

  String defaultName() {
    var n = 1;
    while (items.any((p) => p.name == '설정$n')) {
      n++;
    }
    return '설정$n';
  }

  Future<void> _write(List<Preset> next, String? selected) async {
    final prefs = await LocalStorage.getInstance();
    if (!await prefs.setString(
      'presets.v1',
      jsonEncode({
        'items': [
          for (final p in next)
            {'id': p.id, 'name': p.name, 'options': encodeOptions(p.options)},
        ],
        'selected': selected,
      }),
    )) {
      throw StateError('설정을 저장하지 못했습니다.');
    }
    items = next;
    selectedId = selected;
    notifyListeners();
  }

  Future<Preset> save(
    RecommendationOptions options, {
    String? id,
    String? name,
  }) async {
    final existing = find(id);
    final actualName = name?.trim();
    final label = actualName == null
        ? existing?.name ?? defaultName()
        : actualName.isEmpty
        ? defaultName()
        : actualName;
    if (items.any((p) => p.id != id && p.name == label)) {
      throw ArgumentError('이미 사용 중인 설정 이름입니다.');
    }
    final preset = Preset(
      existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label,
      options,
    );
    await _write([
      for (final p in items)
        if (p.id != preset.id) p,
      preset,
    ], preset.id);
    return preset;
  }

  Future<void> select(String id) async {
    if (find(id) == null) throw ArgumentError('설정을 찾을 수 없습니다.');
    await _write(items, id);
  }

  Future<void> delete(String id) => _write([
    for (final p in items)
      if (p.id != id) p,
  ], selectedId == id ? null : selectedId);
}

final presetStore = PresetStore();
