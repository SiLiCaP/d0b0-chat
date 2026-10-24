// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

/// The O3 mark: a drawn d over a solid b that sits 30 % lower.
///
/// Drawn from the logo path rather than an image so it takes any colour.
class D0b0Mark extends StatelessWidget {
  /// Height of the mark; the width follows the mark's aspect ratio.
  final double height;
  final Color? color;

  /// Colour of the drawn d; defaults to [color].
  final Color? dColor;

  const D0b0Mark({this.height = 24, this.color, this.dColor, super.key});

  static const double aspectRatio = _MarkPainter.width / _MarkPainter.height;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(height * aspectRatio, height),
      painter: _MarkPainter(dColor ?? color, color),
    );
  }
}

class _MarkPainter extends CustomPainter {
  static const double width = 93.0;
  static const double height = 104.046;

  final Color dColor;
  final Color bColor;

  const _MarkPainter(this.dColor, this.bColor);

  /// The drawn d: the bowl with its hole and the stem.
  static final Path _d = Path()
    ..moveTo(84.320, 6.242)
    ..cubicTo(87.664, 4.875, 90.639, 2.734, 93.000, 0.000)
    ..lineTo(93.000, 35.843)
    ..cubicTo(93.000, 45.429, 85.228, 53.203, 75.640, 53.203)
    ..lineTo(17.360, 53.203)
    ..cubicTo(7.772, 53.203, 0.000, 45.429, 0.000, 35.843)
    ..cubicTo(0.000, 26.257, 7.772, 18.484, 17.360, 18.484)
    ..lineTo(84.320, 18.484)
    ..close()
    ..moveTo(17.360, 27.164)
    ..cubicTo(12.566, 27.164, 8.680, 31.054, 8.680, 35.843)
    ..cubicTo(8.680, 40.640, 12.566, 44.523, 17.360, 44.523)
    ..lineTo(75.640, 44.523)
    ..cubicTo(80.434, 44.523, 84.320, 40.640, 84.320, 35.843)
    ..lineTo(84.320, 27.164)
    ..close()
    ..fillType = PathFillType.evenOdd;

  static final Path _b = Path()
    ..moveTo(0.000, 50.843)
    ..cubicTo(2.361, 53.578, 5.336, 55.711, 8.680, 57.078)
    ..lineTo(8.680, 69.328)
    ..lineTo(75.640, 69.328)
    ..cubicTo(85.228, 69.328, 93.000, 77.101, 93.000, 86.687)
    ..cubicTo(93.000, 96.273, 85.228, 104.046, 75.640, 104.046)
    ..lineTo(17.360, 104.046)
    ..cubicTo(7.772, 104.046, 0.000, 96.273, 0.000, 86.687)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / width, size.height / height);
    canvas.drawPath(_d, Paint()..color = dColor);
    canvas.drawPath(_b, Paint()..color = bColor);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.dColor != dColor || oldDelegate.bColor != bColor;
}
