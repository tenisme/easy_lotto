import 'dart:convert';
import 'dart:math';
import 'local_storage.dart';

enum PaperDesign { basic, spacious, cards }

enum DesignMode { basic, perPaper, random }

const designNames = ['기본', '간격 넓게', '카드형'];

class DisplayPreferences {
  DisplayPreferences({
    this.mode = DesignMode.basic,
    this.defaultDesign = PaperDesign.basic,
    Map<String, PaperDesign> overrides = const {},
  }) : overrides = Map.unmodifiable(overrides);
  final DesignMode mode;
  final PaperDesign defaultDesign;
  final Map<String, PaperDesign> overrides;
  PaperDesign resolve(String paperId, Random random) => switch (mode) {
    DesignMode.basic => defaultDesign,
    DesignMode.perPaper => overrides[paperId] ?? defaultDesign,
    DesignMode.random =>
      PaperDesign.values[random.nextInt(PaperDesign.values.length)],
  };
  static Future<DisplayPreferences> load() async {
    final raw = (await LocalStorage.getInstance()).getString('display.v1');
    if (raw == null) return DisplayPreferences();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return DisplayPreferences(
      mode: DesignMode.values.byName(j['mode'] as String),
      defaultDesign: PaperDesign.values.byName(j['default'] as String),
      overrides: (j['overrides'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, PaperDesign.values.byName(v as String)),
      ),
    );
  }

  Future<void> save() async {
    if (!await (await LocalStorage.getInstance()).setString(
      'display.v1',
      jsonEncode({
        'mode': mode.name,
        'default': defaultDesign.name,
        'overrides': overrides.map((k, v) => MapEntry(k, v.name)),
      }),
    )) {
      throw StateError('디자인 저장 실패');
    }
  }
}
