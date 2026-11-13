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

double numberAreaFraction(BuildContext context) =>
    MediaQuery.orientationOf(context) == Orientation.landscape ? .65 : .85;

/// Ratios refer to the available content width, independently of rotation.
class NumberArea extends StatelessWidget {
  const NumberArea({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: FractionallySizedBox(
      widthFactor: numberAreaFraction(context),
      child: child,
    ),
  );
}

Color numberSelectionAccent(BuildContext context) {
  var color = Theme.of(context).colorScheme.primary;
  // The approved badge has a white heart in every theme.
  while ((1.05 / (color.computeLuminance() + .05)) < 4.5) {
    color = Color.alphaBlend(const Color(0x18000000), color);
  }
  return color;
}

class SelectableNumber extends StatelessWidget {
  const SelectableNumber({
    super.key,
    required this.number,
    this.selected = false,
    this.favorite = false,
    this.onTap,
    this.fontSize = 18,
  });
  final int number;
  final bool selected, favorite;
  final VoidCallback? onTap;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    final side = numberSide(context, fontSize),
        accent = numberSelectionAccent(context);
    final badge = side * .46;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: '$number 번호 선택${favorite ? ', 내 번호' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: side + 8,
          height: side + 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 3,
                      color: selected ? accent : Colors.transparent,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: NumberTile(number: number, fontSize: fontSize),
                  ),
                ),
              ),
              if (favorite)
                Positioned(
                  top: 0,
                  right: 0,
                  child: ExcludeSemantics(
                    child: Container(
                      key: ValueKey('favorite-badge-$number'),
                      width: badge,
                      height: badge,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        border: Border.all(color: accent),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: badge * .65,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ordinary wrapping for pickers, not the six-number game row policy.
class NumberPickerGrid extends StatelessWidget {
  const NumberPickerGrid({
    super.key,
    required this.numbers,
    this.selected = const {},
    this.favorites = const {},
    this.disabled = const {},
    this.onToggle,
    this.maxColumns,
  });
  final List<int> numbers;
  final Set<int> selected, favorites, disabled;
  final ValueChanged<int>? onToggle;
  final int? maxColumns;
  @override
  Widget build(BuildContext context) => NumberArea(
    child: LayoutBuilder(
      builder: (context, c) {
        final side = numberSide(context, 18) + 8;
        const gap = 2.0;
        final columns = math.max(
          1,
          math.min(
            maxColumns ?? 45,
            ((c.maxWidth + gap) / (side + gap)).floor(),
          ),
        );
        final tileWidth = math.min(side, c.maxWidth);
        final spacing = columns > 1
            ? math.max(
                0.0,
                (c.maxWidth - columns * tileWidth) / (columns - 1) - .01,
              )
            : 0.0;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final n in numbers)
              SizedBox(
                width: tileWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableNumber(
                    number: n,
                    selected: selected.contains(n),
                    favorite: favorites.contains(n),
                    onTap: onToggle == null || disabled.contains(n)
                        ? null
                        : () => onToggle!(n),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Keep six stable slots so adding a number never recenters the whole group.
class SelectedNumberPreview extends StatelessWidget {
  const SelectedNumberPreview({super.key, required this.numbers});
  final List<int> numbers;
  @override
  Widget build(BuildContext context) => NumberArea(
    child: LayoutBuilder(
      builder: (context, c) {
        final side = numberSide(context, 18);
        final columns = math.max(
          1,
          math.min(6, ((c.maxWidth + 4) / (side + 4)).floor()),
        );
        final tileWidth = math.min(side, c.maxWidth);
        final spacing = columns > 1
            ? math.max(
                0.0,
                (c.maxWidth - columns * tileWidth) / (columns - 1) - .01,
              )
            : 0.0;
        return Wrap(
          runSpacing: 8,
          spacing: spacing,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: tileWidth,
                height: tileWidth,
                child: i < numbers.length
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: NumberTile(number: numbers[i], fontSize: 18),
                      )
                    : null,
              ),
          ],
        );
      },
    ),
  );
}

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

/// Rows occupy the orientation-specific area; short last rows stay centered.
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
  Widget build(BuildContext context) => NumberArea(
    child: LayoutBuilder(
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
        final contentWidth = width;
        final cellWidth = actualSide;
        final spacing = columns > 1
            ? (width - columns * actualSide) / (columns - 1)
            : 0.0;
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
                    if (i > start) SizedBox(width: spacing),
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
    ),
  );
}
