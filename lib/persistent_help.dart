import 'dart:math' as math;
import 'package:flutter/material.dart';

Future<void> showPersistentHelp(BuildContext anchorContext, String message) {
  final box = anchorContext.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  return showGeneralDialog<void>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: '안내 닫기',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final top = math.min(
            math.max(
              0.0,
              anchor.bottom - MediaQuery.paddingOf(context).top + 8,
            ),
            math.max(0.0, constraints.maxHeight - 240),
          );
          return Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: top,
                child: Align(
                  alignment: Alignment.topRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 360,
                      maxHeight: math.min(300, constraints.maxHeight - top),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        elevation: 6,
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(8),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
