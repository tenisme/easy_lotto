import 'package:flutter/material.dart';
import 'local_storage.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ThemeMode>(
          key: ValueKey((controller.mode, controller.busy)),
          initialValue: controller.mode,
          decoration: const InputDecoration(labelText: '앱 테마'),
          items: const [
            DropdownMenuItem(value: ThemeMode.light, child: Text('밝게')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('어둡게')),
            DropdownMenuItem(value: ThemeMode.system, child: Text('기기 설정')),
          ],
          onChanged: controller.busy
              ? null
              : (value) async {
                  if (value != null &&
                      !await controller.select(value) &&
                      context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('앱 테마를 저장하지 못했습니다.')),
                    );
                  }
                },
        ),
        if (controller.loadFailed)
          TextButton(
            onPressed: controller.load,
            child: const Text('테마 다시 불러오기'),
          ),
      ],
    );
  }
}
