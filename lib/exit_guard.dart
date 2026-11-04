import 'package:flutter/material.dart';

class ExitGuard extends StatefulWidget {
  const ExitGuard({
    super.key,
    required this.needsConfirmation,
    required this.message,
    required this.child,
    this.stay = '돌아가기',
    this.leave = '저장하지 않고 이동',
  });
  final bool needsConfirmation;
  final String message, stay, leave;
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
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(widget.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.stay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.leave),
            ),
          ],
        ),
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
