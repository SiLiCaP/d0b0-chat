// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:material_ui/material_ui.dart';

/// What a bubble shows about its message: outline = waiting, fill = done.
enum BubbleState {
  /// Sent: a fill.
  sent,

  /// On its way: a dashed Mint outline whose dashes march.
  sending,

  /// Failed to send: a solid Coral outline.
  error,

  /// Deleted: a still, thinner dashed outline in the outline colour.
  deleted,

  /// Footage or images are the bubble themselves: no fill, no stem.
  bare,
}

/// One bubble shape for every message: a pill on one line, radius 22 when
/// wrapped. The first bubble of a group squares its outer top corner and
/// carries the stem, the curved cut from the mark.
class D0b0Bubble extends StatefulWidget {
  final bool mine;
  final bool firstInGroup;
  final BubbleState state;
  final Widget child;

  const D0b0Bubble({
    required this.mine,
    required this.firstInGroup,
    required this.child,
    this.state = BubbleState.sent,
    super.key,
  });

  static const double radius = D0b0Radius.bubble;
  static const double stemWidth = 10;
  static const double stemHeight = 12.5;

  /// Space above a group's first bubble that the stem rises into.
  static const double stemSpace = 12;

  @override
  State<D0b0Bubble> createState() => _D0b0BubbleState();

  static BorderRadius borderRadius({
    required bool mine,
    required bool firstInGroup,
  }) {
    const round = Radius.circular(radius);
    return BorderRadius.only(
      topLeft: !mine && firstInGroup ? Radius.zero : round,
      topRight: mine && firstInGroup ? Radius.zero : round,
      bottomLeft: round,
      bottomRight: round,
    );
  }
}

class _D0b0BubbleState extends State<D0b0Bubble>
    with SingleTickerProviderStateMixin {
  /// Grows the stem in once the server echoes a sent message.
  late final AnimationController _stem = AnimationController(
    vsync: this,
    duration: D0b0Motion.state,
    value: 1,
  );

  @override
  void didUpdateWidget(D0b0Bubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justSent =
        oldWidget.state == BubbleState.sending &&
        widget.state == BubbleState.sent;
    if (justSent && !MediaQuery.disableAnimationsOf(context)) {
      _stem.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final firstInGroup = widget.firstInGroup;
    final state = widget.state;
    final child = widget.child;
    const radius = D0b0Bubble.radius;
    const stemSpace = D0b0Bubble.stemSpace;
    final theme = Theme.of(context);
    final colors = theme.d0b0;
    // Only a filled bubble has a stem; while sending the stem grows in once
    // the server echoes the message.
    final stem = firstInGroup && state == BubbleState.sent;
    final radii = D0b0Bubble.borderRadius(mine: mine, firstInGroup: stem);
    final fill = mine ? colors.bubbleMine : colors.bubbleTheirs;

    final Widget bubble;
    switch (state) {
      case BubbleState.sent:
        bubble = DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: radii),
          child: child,
        );
      case BubbleState.bare:
        bubble = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        );
      case BubbleState.error:
        bubble = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.colorScheme.error, width: 2),
          ),
          child: child,
        );
      case BubbleState.sending:
        bubble = DashedPill(
          color: theme.colorScheme.primary,
          strokeWidth: 2,
          marching: true,
          child: child,
        );
      case BubbleState.deleted:
        bubble = DashedPill(
          color: theme.colorScheme.outline,
          strokeWidth: 1.5,
          marching: false,
          child: child,
        );
    }
    // On server echo the dashes give way to the fill in 150.
    final switched = AnimatedSwitcher(
      duration: D0b0Motion.state,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(state), child: bubble),
    );
    if (!stem) return switched;
    return Padding(
      padding: const EdgeInsets.only(top: stemSpace),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          switched,
          Positioned(
            top: -stemSpace,
            left: mine ? null : 0,
            right: mine ? 0 : null,
            // The stem grows up out of the corner.
            child: ScaleTransition(
              scale: _stem,
              alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
              child: CustomPaint(
                size: const Size(D0b0Bubble.stemWidth, D0b0Bubble.stemHeight),
                painter: _StemPainter(color: fill, mine: mine),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stem: rises from the bubble's outer top corner in one curved cut.
class _StemPainter extends CustomPainter {
  final Color color;
  final bool mine;

  const _StemPainter({required this.color, required this.mine});

  @override
  void paint(Canvas canvas, Size size) {
    if (mine) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final path = Path()
      ..moveTo(10, 4)
      ..cubicTo(6.15, 3.12, 2.73, 1.76, 0, 0)
      ..lineTo(0, 12.5)
      ..lineTo(10, 12.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StemPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mine != mine;
}

/// A pill-shaped dashed outline (dash 6, gap 5, round caps).
///
/// When [marching], the dashes travel clockwise one dash + gap every
/// 600 ms. The gap is adjusted so the perimeter divides evenly and the seam
/// never jumps. With animations disabled the dashes stay still.
class DashedPill extends StatefulWidget {
  final Color color;
  final double strokeWidth;
  final bool marching;
  final Widget child;

  const DashedPill({
    required this.color,
    required this.strokeWidth,
    required this.marching,
    required this.child,
    super.key,
  });

  @override
  State<DashedPill> createState() => _DashedPillState();
}

class _DashedPillState extends State<DashedPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(DashedPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    final animate = widget.marching && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedPillPainter(
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      phase: _controller,
    ),
    child: widget.child,
  );
}

class _DashedPillPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Animation<double> phase;

  _DashedPillPainter({
    required this.color,
    required this.strokeWidth,
    required this.phase,
  }) : super(repaint: phase);

  static const double dash = 6;
  static const double gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final radius = min(D0b0Radius.bubble, rect.shortestSide / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      final count = max(1, (metric.length / (dash + gap)).round());
      final period = metric.length / count;
      final offset = phase.value * period;
      for (var d = offset - period; d < metric.length; d += period) {
        final start = max(0.0, d);
        final end = min(metric.length, d + dash);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
