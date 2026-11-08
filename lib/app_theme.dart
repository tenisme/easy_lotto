import 'package:flutter/material.dart';
import 'local_storage.dart';
import 'banner_scaffold.dart';

class AppThemeController extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  ThemeMode mode = ThemeMode.system;
  bool busy = false;
  bool loadFailed = false;
  Future<void> load() async {
    try {
      final value = (await LocalStorage.getInstance()).getString('appTheme.v1');
      mode =
          ThemeMode.values.where((m) => m.name == value).firstOrNull ??
          ThemeMode.system;
      loadFailed = false;
    } catch (_) {
      loadFailed = true;
    }
    notifyListeners();
  }

  Future<bool> select(ThemeMode next) async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      if (!await (await LocalStorage.getInstance()).setString(
        'appTheme.v1',
        next.name,
      )) {
        throw StateError('테마 저장 실패');
      }
      mode = next;
      return true;
    } catch (_) {
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()!.notifier!;
}

class AppThemePicker extends StatelessWidget {
  const AppThemePicker({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    return ListTile(
      title: const Text('앱 테마 설정'),
      trailing: const Icon(Icons.chevron_right),
      onTap: controller.busy
          ? null
          : () => Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(builder: (_) => const AppThemeSettings()),
            ),
    );
  }
}

class AppThemeSettings extends StatefulWidget {
  const AppThemeSettings({super.key});
  @override
  State<AppThemeSettings> createState() => _AppThemeSettingsState();
}

class _AppThemeSettingsState extends State<AppThemeSettings> {
  ThemeMode? draft;
  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    final selected = draft ?? controller.mode;
    return BannerScaffold(
      appBar: AppBar(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text('앱 테마 설정')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: controller.busy
                ? null
                : () async {
                    final saved = await controller.select(selected);
                    if (!context.mounted) return;
                    if (saved) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('앱 테마를 저장하지 못했습니다.')),
                      );
                    }
                  },
            child: const Text('저장', textAlign: TextAlign.center),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('테마를 선택한 뒤 저장하면 앱 전체에 적용됩니다.'),
          if (controller.loadFailed)
            TextButton(
              onPressed: controller.load,
              child: const Text('테마 다시 불러오기', textAlign: TextAlign.center),
            ),
          RadioGroup<ThemeMode>(
            groupValue: selected,
            onChanged: (value) {
              if (!controller.busy) setState(() => draft = value);
            },
            child: Column(
              children: [
                for (final mode in [
                  ThemeMode.light,
                  ThemeMode.dark,
                  ThemeMode.system,
                ])
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -4),
                          value: mode,
                          title: Text(themeLabel(mode)),
                          subtitle: controller.mode == mode
                              ? const Text('현재 적용 중')
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: ThemeMiniPreview(mode: mode),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => '밝게',
  ThemeMode.dark => '어둡게',
  ThemeMode.system => '기기 설정',
};

class ThemeMiniPreview extends StatelessWidget {
  const ThemeMiniPreview({super.key, required this.mode});
  final ThemeMode mode;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${themeLabel(mode)} 테마 미리보기',
    image: true,
    child: Row(
      children: [
        if (mode != ThemeMode.dark) Expanded(child: _mini(Brightness.light)),
        if (mode == ThemeMode.system) const SizedBox(width: 8),
        if (mode != ThemeMode.light) Expanded(child: _mini(Brightness.dark)),
      ],
    ),
  );
  Widget _mini(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff386b56),
      brightness: brightness,
    );
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FractionallySizedBox(
            widthFactor: .6,
            child: Container(height: 8, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          FractionallySizedBox(
            widthFactor: .8,
            child: Container(height: 10, color: scheme.primaryContainer),
          ),
        ],
      ),
    );
  }
}
