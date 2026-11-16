import 'dart:convert';
import 'dart:math';
import 'local_storage.dart';

enum PaperDesign { colorBasic, colorCards, basic, cards }

// random is retained only to decode legacy settings; the UI has two scopes.
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
    this.defaultRandom = false,
    this.overwriteOverrides = false,
    this.legacyBasicScope = false,
    this.defaultBackground,
    Map<String, String> backgrounds = const {},
  }) : overrides = Map.unmodifiable(overrides),
       randomPapers = Set.unmodifiable(randomPapers),
       backgrounds = Map.unmodifiable(backgrounds);
  final DesignMode mode, beforeRandomMode;
  final PaperDesign defaultDesign;
  final Map<String, PaperDesign> overrides;
  final Set<String> randomPapers;
  final bool defaultRandom, overwriteOverrides;
  // Preserve the old basic-mode exception for local random until explicitly edited.
  final bool legacyBasicScope;
  final String? defaultBackground;
  final Map<String, String> backgrounds;
  bool get isDefaultRandom => defaultRandom || mode == DesignMode.random;
  PaperDesign resolve(String id, Random random) {
    PaperDesign base() => isDefaultRandom
        ? PaperDesign.values[random.nextInt(PaperDesign.values.length)]
        : defaultDesign;
    if (legacyBasicScope) {
      return randomPapers.contains(id)
          ? PaperDesign.values[random.nextInt(PaperDesign.values.length)]
          : defaultDesign;
    }
    if (overwriteOverrides || mode == DesignMode.random) return base();
    if (randomPapers.contains(id)) {
      return PaperDesign.values[random.nextInt(PaperDesign.values.length)];
    }
    return overrides[id] ?? base();
  }

  DisplayPreferences reset({
    required String paperId,
    required bool all,
    required bool numbers,
    required bool background,
  }) {
    final local = {...overrides},
        random = {...randomPapers},
        images = {...backgrounds};
    if (numbers) {
      if (all) {
        local.clear();
        random.clear();
      } else {
        local.remove(paperId);
        random.remove(paperId);
      }
    }
    if (background) {
      if (all) {
        images.clear();
      } else {
        images.remove(paperId);
      }
    }
    return DisplayPreferences(
      mode: numbers && all ? DesignMode.basic : mode,
      defaultDesign: numbers && all ? PaperDesign.colorBasic : defaultDesign,
      defaultRandom: numbers && all ? false : defaultRandom,
      overwriteOverrides: numbers && all ? false : overwriteOverrides,
      legacyBasicScope: numbers && all ? false : legacyBasicScope,
      beforeRandomMode: numbers && all ? DesignMode.basic : beforeRandomMode,
      overrides: local,
      randomPapers: random,
      backgrounds: images,
      defaultBackground: background && all ? null : defaultBackground,
    );
  }

  static Future<DisplayPreferences> load() async {
    final raw = (await LocalStorage.getInstance()).getString('display.v1');
    if (raw == null) return DisplayPreferences();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final mode = DesignMode.values.byName(j['mode'] as String);
    return DisplayPreferences(
      mode: mode,
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
      defaultRandom: j['defaultRandom'] as bool? ?? mode == DesignMode.random,
      legacyBasicScope:
          j['legacyBasicScope'] as bool? ??
          ((j['version'] as int? ?? 1) < 2 && mode == DesignMode.basic),
      overwriteOverrides:
          j['overwriteOverrides'] as bool? ??
          (mode != DesignMode.perPaper && (j['overrides'] as Map).isNotEmpty),
      defaultBackground: j['defaultBackground'] as String?,
      backgrounds: ((j['backgrounds'] as Map?) ?? {}).cast<String, String>(),
    );
  }

  Future<void> save() async {
    if (!await (await LocalStorage.getInstance()).setString(
      'display.v1',
      jsonEncode({
        'version': 2,
        'mode': mode.name,
        'default': defaultDesign.name,
        'overrides': overrides.map((k, v) => MapEntry(k, v.name)),
        'randomPapers': randomPapers.toList(),
        'beforeRandomMode': beforeRandomMode.name,
        'defaultRandom': defaultRandom,
        'overwriteOverrides': overwriteOverrides,
        'legacyBasicScope': legacyBasicScope,
        'defaultBackground': defaultBackground,
        'backgrounds': backgrounds,
      }),
    )) {
      throw StateError('디자인 저장 실패');
    }
  }
}
