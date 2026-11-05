import 'package:flutter/material.dart';
import 'local_storage.dart';

Future<bool> confirmResultLoss(
  BuildContext context, {
  required String message,
  String stay = '결과로 돌아가기',
  String leave = '저장하지 않고 이동',
  String? suppressionKey = 'resultLossNotice.v1',
}) async {
  try {
    if (suppressionKey != null &&
        (await LocalStorage.getInstance()).getBool(suppressionKey) == true) {
      return true;
    }
  } catch (_) {
    /* Keep the warning when preferences cannot be read. */
  }
  if (!context.mounted) return false;
  var suppress = false;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            if (suppressionKey != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('다시 보지 않기'),
                value: suppress,
                onChanged: (v) => update(() => suppress = v ?? false),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(leave),
          ),
        ],
      ),
    ),
  );
  if (yes == true && suppress && suppressionKey != null) {
    try {
      await (await LocalStorage.getInstance()).setBool(suppressionKey, true);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('안내 표시 설정을 저장하지 못했습니다.')));
      }
    }
  }
  return yes == true;
}

class ExitGuard extends StatefulWidget {
  const ExitGuard({
    super.key,
    required this.needsConfirmation,
    required this.message,
    required this.child,
    this.stay = '돌아가기',
    this.leave = '저장하지 않고 이동',
    this.suppressionKey,
  });
  final bool needsConfirmation;
  final String message, stay, leave;
  final String? suppressionKey;
  final Widget child;
  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  bool allow = false, asking = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: allow || !widget.needsConfirmation,
    onPopInvokedWithResult: (didPop, result) async {
      // An explicit generation result from the editor is not abandonment.
      if (didPop || asking) return;
      if (result != null) {
        setState(() => allow = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(result);
        });
        return;
      }
      asking = true;
      final yes = await confirmResultLoss(
        context,
        message: widget.message,
        stay: widget.stay,
        leave: widget.leave,
        suppressionKey: widget.suppressionKey,
      );
      asking = false;
      if (yes == true && mounted) {
        setState(() => allow = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    },
    child: widget.child,
  );
}
