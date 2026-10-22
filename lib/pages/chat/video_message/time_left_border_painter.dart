import 'package:material_ui/material_ui.dart';

/// Paints a rounded rectangle border that fills clockwise, starting at the
/// top center, as the recording time is used up. The unfilled part of the
/// border is the time left.
class TimeLeftBorderPainter extends CustomPainter {
  /// From 0.0 (nothing recorded) to 1.0 (time is up).
  final double progress;
  final double radius;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  const TimeLeftBorderPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final r = Radius.circular(radius - inset);
    final top = rect.top;
    final midX = rect.center.dx;

    // Build the path manually so that it starts at the top center.
    final path = Path()
      ..moveTo(midX, top)
      ..lineTo(rect.right - r.x, top)
      ..arcToPoint(Offset(rect.right, top + r.y), radius: r)
      ..lineTo(rect.right, rect.bottom - r.y)
      ..arcToPoint(Offset(rect.right - r.x, rect.bottom), radius: r)
      ..lineTo(rect.left + r.x, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r.y), radius: r)
      ..lineTo(rect.left, top + r.y)
      ..arcToPoint(Offset(rect.left + r.x, top), radius: r)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint..color = trackColor);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * clamped),
      paint..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(TimeLeftBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
