import 'package:flutter/rendering.dart';

/// Strokes a dashed rounded rectangle around the painted area.
///
/// Flutter's [Border] only supports solid lines, so dashed outlines are
/// drawn by walking the outline path and emitting alternating segments.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the line sits fully inside the bounds,
    // matching how a solid Border is drawn.
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          Radius.circular(radius - inset),
        ),
      );

    final dashes = Path();
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dashLength + gapLength) {
        dashes.addPath(metric.extractPath(d, d + dashLength), Offset.zero);
      }
    }

    canvas.drawPath(
      dashes,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength;
  }
}
