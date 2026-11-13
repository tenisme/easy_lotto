import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Uniform, checkmark-free text choices; wrapping follows the active text scale.
class SelectionTiles extends StatelessWidget {
  const SelectionTiles({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.columns,
    this.disabled = const {},
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;
  final int? columns;
  final Set<int> disabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final style = Theme.of(context).textTheme.labelLarge!;
      final scaler = MediaQuery.textScalerOf(context);
      double measure(String text, double width) {
        final p = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: width);
        final h = p.height;
        p.dispose();
        return h;
      }

      final sample = TextPainter(
        text: TextSpan(text: columns == null ? '가나다라' : '가', style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final minimum = math.max(44.0, sample.width + 24);
      sample.dispose();
      final count = math.max(
        1,
        math.min(
          columns ?? labels.length,
          ((constraints.maxWidth + gap) / (minimum + gap)).floor(),
        ),
      );
      final width = (constraints.maxWidth - gap * (count - 1)) / count;
      final height = math.max(
        48.0,
        labels
                .map((s) => measure(s, math.max(1, width - 24)))
                .fold<double>(0, math.max) +
            24,
      );
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < labels.length; i++)
            SizedBox(
              width: width,
              height: height,
              child: Semantics(
                selected: selected == i,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    backgroundColor: selected == i
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    side: BorderSide(
                      width: selected == i ? 2 : 1,
                      color: selected == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  onPressed: onChanged == null || disabled.contains(i)
                      ? null
                      : () => onChanged!(i),
                  child: Text(labels[i], textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      );
    },
  );
}
