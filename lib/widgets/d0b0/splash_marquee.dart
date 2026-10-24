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
/// It starts as the single mark the native splash shows; copies then grow
/// out above and below it, and the chain eases into motion. On [exit] the
/// background goes first, leaving the chain over the app, then the chain.
///
/// Works without a MaterialApp above it, so it can run before the app
/// itself is built.
class D0b0SplashMarquee extends StatefulWidget {
  final Color background;
  final Color color;

  /// Runs from 0 to 1 while the splash hands over to the app.
  final Animation<double>? exit;

  const D0b0SplashMarquee({
    this.background = D0b0Palette.deep,
    this.color = D0b0Palette.mint,
    this.exit,
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

  /// The single mark the splash starts from: the size of the mark in
  /// Android 12+'s system splash icon (measured on a Pixel 6 Pro), so the
  /// system splash hands over without a jump. It grows to [columnWidth]
  /// while the copies appear.
  static const double startWidth = 110;

  /// Android 12+ fades its icon splash out after Flutter's first frame;
  /// the intro waits for it so it is never played unseen.
  static const Duration systemSplashExit = Duration(milliseconds: 300);

  /// During the exit the background fades over the first part, the chain
  /// over the rest.
  static const double exitBackgroundShare = 0.45;

  @override
  State<D0b0SplashMarquee> createState() => _D0b0SplashMarqueeState();
}

class _D0b0SplashMarqueeState extends State<D0b0SplashMarquee>
    with SingleTickerProviderStateMixin {
  /// Cruising speed in periods per second.
  static final double _cruise =
      1000 / D0b0SplashMarquee.periodDuration.inMilliseconds;

  /// The single mark holds for a beat before the copies appear.
  static const Duration _hold = Duration(milliseconds: 200);

  /// The mark grows to chain size while copies grow out above and below.
  static const Duration _grow = Duration(milliseconds: 1100);

  /// Then the chain eases from rest to cruising speed.
  static const Duration _rampUp = Duration(milliseconds: 700);

  /// Leaving, the chain picks up to this many times its cruising speed.
  static const double _exitBoost = 4;

  /// Position in periods; 0 is the first frame the native splash shows.
  final ValueNotifier<double> _phase = ValueNotifier(0);

  /// 0: only the centre mark; 1: the whole chain.
  final ValueNotifier<double> _intro = ValueNotifier(0);

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    final growing = elapsed - _hold;
    _intro.value = (growing.inMicroseconds / _grow.inMicroseconds).clamp(
      0.0,
      1.0,
    );

    final moving = growing - _grow;
    var speed =
        _cruise *
        Curves.easeInOutCubic.transform(
          (moving.inMicroseconds / _rampUp.inMicroseconds).clamp(0.0, 1.0),
        );
    final exit = widget.exit?.value ?? 0;
    if (exit > 0) {
      speed += _cruise * (_exitBoost - 1) * Curves.easeIn.transform(exit);
    }
    _phase.value = (_phase.value + speed * dt) % 1;
  }

  /// Whether the first frame is on screen and the system splash is gone.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.waitUntilFirstFrameRasterized
        .then((_) => Future.delayed(D0b0SplashMarquee.systemSplashExit))
        .then((_) {
          if (!mounted) return;
          _visible = true;
          _startIfAllowed();
        });
  }

  void _startIfAllowed() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _intro.value = 1;
    } else if (_visible && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfAllowed();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = Center(
      child: SplashBand(phase: _phase, intro: _intro, color: widget.color),
    );
    final exit = widget.exit;
    if (exit == null) {
      return ColoredBox(color: widget.background, child: band);
    }
    const split = D0b0SplashMarquee.exitBackgroundShare;
    return AnimatedBuilder(
      animation: exit,
      child: band,
      builder: (context, band) {
        final t = exit.value;
        // The background goes first, then the chain.
        final background =
            1 - Curves.easeInOut.transform((t / split).clamp(0.0, 1.0));
        final chain =
            1 -
            Curves.easeIn.transform(
              ((t - split) / (1 - split)).clamp(0.0, 1.0),
            );
        return Stack(
          fit: StackFit.expand,
          textDirection: TextDirection.ltr,
          children: [
            Opacity(
              opacity: background,
              child: ColoredBox(color: widget.background),
            ),
            Opacity(opacity: chain, child: band),
          ],
        );
      },
    );
  }
}

/// The chain at its fixed size with its faded, blurred ends, on a
/// transparent background. [phase] 0 with [intro] 0 is the first frame:
/// the single mark.
class SplashBand extends StatelessWidget {
  final ValueListenable<double> phase;
  final ValueListenable<double> intro;
  final Color color;

  const SplashBand({
    required this.phase,
    this.intro = const AlwaysStoppedAnimation(1),
    this.color = D0b0Palette.mint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chain = RepaintBoundary(
      child: CustomPaint(
        painter: _ChainPainter(phase: phase, intro: intro, color: color),
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
  final ValueListenable<double> intro;
  final Color color;

  _ChainPainter({required this.phase, required this.intro, required this.color})
    : super(repaint: Listenable.merge([phase, intro]));

  /// The single mark grows to chain size over this much of the intro.
  static const double _zoomShare = 0.4;

  /// The first copies start this far into the intro.
  static const double _copiesStart = 0.2;

  /// Each ring of copies starts this much of the intro after the previous.
  static const double _stagger = 0.12;

  /// How much of the intro one copy takes to grow in.
  static const double _growShare = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = Curves.easeInOutCubic.transform(
      (intro.value / _zoomShare).clamp(0.0, 1.0),
    );
    final width = ui.lerpDouble(
      D0b0SplashMarquee.startWidth,
      D0b0SplashMarquee.columnWidth,
      zoom,
    )!;
    final scale = width / D0b0MarkPath.width;
    final period = D0b0MarkPath.period * scale;
    final left = (size.width - width) / 2;
    // Rises steadily, one d + b period per cycle.
    final offset = -phase.value * period;
    final centre = size.height / 2 - D0b0MarkPath.height * scale / 2;
    canvas.clipRect(Offset.zero & size);
    final reach = ((size.height / 2) / period).ceil() + 2;
    for (var i = -reach; i <= reach; i++) {
      final distance = i.abs();
      // The centre mark is there from the start; copies grow out from
      // their inner neighbour, nearest first, with a little overshoot.
      final grow = distance == 0
          ? 1.0
          : ((intro.value - _copiesStart - (distance - 1) * _stagger) /
                    _growShare)
                .clamp(0.0, 1.0);
      if (grow == 0) continue;
      final travel = D0b0Motion.overshoot.transform(grow);
      final from = (i - i.sign) * period;
      final y = centre + from + (i * period - from) * travel + offset;
      final paint = Paint()
        ..color = color.withValues(
          alpha: color.a * Curves.easeOut.transform(grow),
        );
      canvas.save();
      canvas.translate(left, y);
      canvas.scale(scale);
      canvas.drawPath(D0b0MarkPath.d, paint);
      canvas.drawPath(D0b0MarkPath.b, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ChainPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.phase != phase ||
      oldDelegate.intro != intro;
}
