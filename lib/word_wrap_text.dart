import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keep labels intact for callers and semantics, but break at word boundaries.
class WordWrapText extends Text {
  const WordWrapText(
    super.data, {
    super.key,
    super.style,
    super.textAlign = TextAlign.center,
  });
  @override
  Widget build(BuildContext context) => _WordParagraph(
    label: data!,
    style: DefaultTextStyle.of(context).style.merge(style),
    scaler: MediaQuery.textScalerOf(context),
    direction: Directionality.of(context),
    alignment: textAlign ?? TextAlign.center,
  );
}

class _WordParagraph extends LeafRenderObjectWidget {
  const _WordParagraph({
    required this.label,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.alignment,
  });
  final String label;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final TextAlign alignment;
  @override
  RenderParagraph createRenderObject(BuildContext context) =>
      _RenderWordParagraph(label, style, scaler, direction, alignment);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWordParagraph render,
  ) {
    render.updateLabel(label, style);
    render
      ..textScaler = scaler
      ..textDirection = direction
      ..textAlign = alignment;
  }
}

class _RenderWordParagraph extends RenderParagraph {
  _RenderWordParagraph(
    this.label,
    this.labelStyle,
    TextScaler scaler,
    TextDirection direction,
    TextAlign alignment,
  ) : super(
        TextSpan(text: label, style: labelStyle),
        textScaler: scaler,
        textDirection: direction,
        textAlign: alignment,
      );
  String label;
  TextStyle labelStyle;
  bool preparingLayout = false;
  @override
  void markNeedsLayout() {
    // The text setter invalidates TextPainter; this layout immediately consumes it.
    if (!preparingLayout) super.markNeedsLayout();
  }

  void updateLabel(String next, TextStyle style) {
    if (label == next && labelStyle == style) return;
    label = next;
    labelStyle = style;
    markNeedsLayout();
  }

  TextPainter measure(double width, {bool wrap = true}) {
    final p = TextPainter(
      text: TextSpan(
        text: wrap
            ? buttonLineText(
                label,
                width,
                labelStyle,
                textScaler,
                textDirection,
              )
            : label,
        style: labelStyle,
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      textAlign: textAlign,
    )..layout(maxWidth: width);
    return p;
  }

  @override
  void performLayout() {
    preparingLayout = true;
    try {
      text = TextSpan(
        text: buttonLineText(
          label,
          constraints.maxWidth,
          labelStyle,
          textScaler,
          textDirection,
        ),
        style: labelStyle,
      );
    } finally {
      preparingLayout = false;
    }
    super.performLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final p = measure(constraints.maxWidth);
    final size = constraints.constrain(p.size);
    p.dispose();
    return size;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final p = measure(width);
    final h = p.height;
    p.dispose();
    return h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = measure(double.infinity, wrap: false);
    final w = p.width;
    p.dispose();
    return w;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var result = 0.0;
    for (final word in label.split(RegExp(r'\s+'))) {
      final p = TextPainter(
        text: TextSpan(text: word, style: labelStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      if (p.width > result) result = p.width;
      p.dispose();
    }
    return result;
  }
}

String buttonLineText(
  String label,
  double width,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  double measure(String text) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  final lines = <String>[];
  var line = '';
  for (final word in label.split(RegExp(r'\s+'))) {
    final candidate = line.isEmpty ? word : '$line $word';
    if (line.isNotEmpty && measure(candidate) > width) {
      lines.add(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n');
}
