import 'dart:convert';
import 'dart:math';
import 'local_storage.dart';

enum PaperDesign { colorBasic, colorCards, basic, cards }

enum DesignMode { basic, perPaper, random }

const designNames = ['컬러 기본', '컬러 카드', '흑백 기본', '흑백 카드'];

PaperDesign decodeDesign(String name) =>
    name == 'spacious' ? PaperDesign.basic : PaperDesign.values.byName(name);

class DisplayPreferences {
  DisplayPreferences({
    this.mode = DesignMode.basic,
    this.defaultDesign = PaperDesign.colorBasic,
    Map<String, PaperDesign> overrides = const {},
    Set<String> randomPapers = const {},
    this.beforeRandomMode = DesignMode.basic,
  }) : overrides = Map.unmodifiable(overrides),
       randomPapers = Set.unmodifiable(randomPapers);
  final DesignMode mode;
  final PaperDesign defaultDesign;
  final Map<String, PaperDesign> overrides;
  final Set<String> randomPapers;
  final DesignMode beforeRandomMode;
  PaperDesign resolve(String paperId, Random random) {
    if (mode == DesignMode.random || randomPapers.contains(paperId)) {
      return PaperDesign.values[random.nextInt(PaperDesign.values.length)];
    }
    return switch (mode) {
      DesignMode.basic => defaultDesign,
      DesignMode.perPaper => overrides[paperId] ?? defaultDesign,
      DesignMode.random =>
        PaperDesign.values[random.nextInt(PaperDesign.values.length)],
    };
  }

  static Future<DisplayPreferences> load() async {
    final raw = (await LocalStorage.getInstance()).getString('display.v1');
    if (raw == null) return DisplayPreferences();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return DisplayPreferences(
      mode: DesignMode.values.byName(j['mode'] as String),
      defaultDesign: decodeDesign(j['default'] as String),
      overrides: (j['overrides'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, decodeDesign(v as String)),
      ),
      randomPapers: ((j['randomPapers'] as List?) ?? []).cast<String>().toSet(),
      beforeRandomMode:
          DesignMode.values
              .where(
                (m) =>
                    m != DesignMode.random && m.name == j['beforeRandomMode'],
              )
              .firstOrNull ??
          DesignMode.basic,
    );
  }

  Future<void> save() async {
    if (!await (await LocalStorage.getInstance()).setString(
      'display.v1',
      jsonEncode({
        'mode': mode.name,
        'default': defaultDesign.name,
        'overrides': overrides.map((k, v) => MapEntry(k, v.name)),
        'randomPapers': randomPapers.toList(),
        'beforeRandomMode': beforeRandomMode.name,
      }),
    )) {
      throw StateError('디자인 저장 실패');
    }
  }
}
