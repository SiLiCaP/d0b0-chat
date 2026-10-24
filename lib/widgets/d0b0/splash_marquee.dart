// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:flutter/widgets.dart';

/// The splash: the O3 mark tiles into an endless chain (each stem meets
/// the next bowl), drawn as one column that rises slowly up the screen
/// while the app loads. It fades and blurs out at the top and bottom.
///
/// Works without a MaterialApp above it, so it can run before the app
/// itself is built.
class D0b0SplashMarquee extends StatefulWidget {
  final Color background;
  final Color color;

  const D0b0SplashMarquee({
    this.background = D0b0Palette.deep,
    this.color = D0b0Palette.mint,
    super.key,
  });

  /// One d + b period passes in this time.
  static const Duration periodDuration = Duration(milliseconds: 2700);

  @override
  State<D0b0SplashMarquee> createState() => _D0b0SplashMarqueeState();
}

class _D0b0SplashMarqueeState extends State<D0b0SplashMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: D0b0SplashMarquee.periodDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _phase.stop();
    } else if (!_phase.isAnimating) {
      _phase.repeat();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chain = RepaintBoundary(
      child: CustomPaint(
        painter: _ChainPainter(phase: _phase, color: widget.color),
        size: Size.infinite,
      ),
    );
    return ColoredBox(
      color: widget.background,
      child: Stack(
        fit: StackFit.expand,
        textDirection: TextDirection.ltr,
        children: [
          // A blurred copy shows only towards the ends, so the chain
          // softens as it fades.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00FFFFFF),
                Color(0x66FFFFFF),
              ],
              stops: [0.05, 0.3, 0.7, 0.95],
            ).createShader(rect),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 6,
                sigmaY: 6,
                tileMode: TileMode.decal,
              ),
              child: chain,
            ),
          ),
          // The sharp chain, fading out at the top and bottom.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.04, 0.32, 0.68, 0.96],
            ).createShader(rect),
            child: chain,
          ),
        ],
      ),
    );
  }
}

class _ChainPainter extends CustomPainter {
  final Animation<double> phase;
  final Color color;

  _ChainPainter({required this.phase, required this.color})
    : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    // About two fifths of the screen wide.
    final width = (size.shortestSide * 0.41).clamp(120.0, 240.0);
    final scale = width / D0b0MarkPath.width;
    final period = D0b0MarkPath.period * scale;
    final left = (size.width - width) / 2;
    // Rises steadily, one d + b period per cycle.
    final offset = -phase.value * period;
    final paint = Paint()..color = color;
    final first = -((size.height / 2) / period).ceil() - 2;
    final last = ((size.height / 2) / period).ceil() + 2;
    final centre = size.height / 2 - D0b0MarkPath.height * scale / 2;
    for (var i = first; i <= last; i++) {
      canvas.save();
      canvas.translate(left, centre + i * period + offset);
      canvas.scale(scale);
      canvas.drawPath(D0b0MarkPath.d, paint);
      canvas.drawPath(D0b0MarkPath.b, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ChainPainter oldDelegate) => oldDelegate.color != color;
}
