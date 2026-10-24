// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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

  /// When the app is ready the chain speeds up and rises away.
  final bool exiting;

  const D0b0SplashMarquee({
    this.background = D0b0Palette.deep,
    this.color = D0b0Palette.mint,
    this.exiting = false,
    super.key,
  });

  /// One d + b period passes in this time.
  static const Duration periodDuration = Duration(milliseconds: 2700);

  /// The column is a fixed size, centred on the screen, so the native splash
  /// can show this exact first frame as a static image
  /// (`tool/generate_splash_frame.dart`): 41 % of a 390 wide phone.
  static const double columnWidth = 160;

  /// The band the chain is drawn and faded in; room for the blur either
  /// side of the column.
  static const Size bandSize = Size(240, 760);

  @override
  State<D0b0SplashMarquee> createState() => _D0b0SplashMarqueeState();
}

class _D0b0SplashMarqueeState extends State<D0b0SplashMarquee>
    with SingleTickerProviderStateMixin {
  /// Cruising speed in periods per second.
  static final double _cruise =
      1000 / D0b0SplashMarquee.periodDuration.inMilliseconds;

  /// The static first frame comes to life: from rest to cruising speed.
  static const Duration _rampUp = Duration(milliseconds: 700);

  /// Leaving, the chain picks up to this many times its cruising speed.
  static const double _exitBoost = 5;
  static const Duration _exitRamp = Duration(milliseconds: 500);

  /// Position in periods; 0 is the first frame the native splash shows.
  final ValueNotifier<double> _phase = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Duration? _exitStart;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    var speed =
        _cruise *
        Curves.easeInOutCubic.transform(
          (elapsed.inMicroseconds / _rampUp.inMicroseconds).clamp(0.0, 1.0),
        );
    final exitStart = _exitStart;
    if (exitStart != null) {
      final t =
          ((elapsed - exitStart).inMicroseconds / _exitRamp.inMicroseconds)
              .clamp(0.0, 1.0);
      speed += _cruise * (_exitBoost - 1) * Curves.easeInCubic.transform(t);
    }
    _phase.value = (_phase.value + speed * dt) % 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(D0b0SplashMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _exitStart = _last;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.background,
    child: Center(
      child: SplashBand(phase: _phase, color: widget.color),
    ),
  );
}

/// The chain at its fixed size with its faded, blurred ends, on a
/// transparent background. [phase] 0 is the first frame.
class SplashBand extends StatelessWidget {
  final ValueListenable<double> phase;
  final Color color;

  const SplashBand({
    required this.phase,
    this.color = D0b0Palette.mint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chain = RepaintBoundary(
      child: CustomPaint(
        painter: _ChainPainter(phase: phase, color: color),
        size: D0b0SplashMarquee.bandSize,
      ),
    );
    return SizedBox.fromSize(
      size: D0b0SplashMarquee.bandSize,
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
              // Everything reaches nothing at the band's edges, so the
              // band never shows a cut on taller screens.
              colors: [
                Color(0x00FFFFFF),
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00FFFFFF),
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.12, 0.32, 0.68, 0.88, 1.0],
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
  final ValueListenable<double> phase;
  final Color color;

  _ChainPainter({required this.phase, required this.color})
    : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    const width = D0b0SplashMarquee.columnWidth;
    const scale = width / D0b0MarkPath.width;
    const period = D0b0MarkPath.period * scale;
    final left = (size.width - width) / 2;
    // Rises steadily, one d + b period per cycle.
    final offset = -phase.value * period;
    final paint = Paint()..color = color;
    canvas.clipRect(Offset.zero & size);
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
