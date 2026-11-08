import 'dart:math' as math;
import 'package:flutter/material.dart';

// Official result page's active .num-0n ... .num-4n rules, checked 2026-11-07.
// https://www.dhlottery.co.kr/resources/css/common.css?v=20261028
const lottoColors = [
  Color(0xffe08f00),
  Color(0xff0063cc),
  Color(0xffd8314f),
  Color(0xff6e7382),
  Color(0xff2c9e44),
];
Color lottoColor(int number) => lottoColors[(number - 1) ~/ 10];

double numberSide(BuildContext context, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: '45',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final size = math.max(40.0, math.max(painter.width, painter.height) + 12);
  painter.dispose();
  return size;
}

class NumberTile extends StatelessWidget {
  const NumberTile({
    super.key,
    required this.number,
    this.colored = true,
    this.card = false,
    this.side,
    this.fontSize = 24,
  });
  final int number;
  final bool colored, card;
  final double? side;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = colored ? lottoColor(number) : scheme.surface;
    // Preserve official fill; choose readable text rather than changing that fill.
    final foreground = colored
        ? (background.computeLuminance() > 0.179 ? Colors.black : Colors.white)
        : scheme.onSurface;
    return Container(
      width: side ?? numberSide(context, fontSize),
      height: side ?? numberSide(context, fontSize),
      decoration: BoxDecoration(
        color: background,
        shape: card ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: card ? BorderRadius.circular(6) : null,
        border: Border.all(color: colored ? background : scheme.outline),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$number',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// All rows have equal cell widths. A short last row is centered, never stretched.
class NumberGrid extends StatelessWidget {
  const NumberGrid({
    super.key,
    required this.numbers,
    this.colored = true,
    this.card = false,
    this.fontSize = 24,
    this.below,
  });
  final List<int> numbers;
  final bool colored, card;
  final double fontSize;
  final Widget Function(int)? below;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = numberSide(context, fontSize);
      final gap = fontSize <= 18 ? 4.0 : 8.0;
      final width = constraints.maxWidth;
      var columns = 1;
      for (final n in [6, 4, 3, 2, 1]) {
        if (n * side + (n - 1) * gap <= width) {
          columns = n;
          break;
        }
      }
      final actualSide = math.min(side, width);
      final contentWidth = columns * actualSide + (columns - 1) * gap;
      final cellWidth = actualSide;
      final rows = <Widget>[];
      for (var start = 0; start < numbers.length; start += columns) {
        final end = math.min(start + columns, numbers.length);
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: start == 0 ? 0 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i > start) SizedBox(width: gap),
                  SizedBox(
                    width: cellWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NumberTile(
                          number: numbers[i],
                          colored: colored,
                          card: card,
                          side: actualSide,
                          fontSize: fontSize,
                        ),
                        if (below != null) below!(numbers[i]),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      final content = SizedBox(
        width: contentWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      );
      return Center(child: content);
    },
  );
}
