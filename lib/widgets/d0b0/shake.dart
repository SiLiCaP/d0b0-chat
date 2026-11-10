// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Shakes [child] sideways each time [trigger] notifies, to say "no".
class Shake extends StatefulWidget {
  final Listenable trigger;
  final Widget child;

  const Shake({required this.trigger, required this.child, super.key});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  static const double _distance = 8;

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  void _shake() => _animation.forward(from: 0);

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_shake);
  }

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_shake);
      widget.trigger.addListener(_shake);
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_shake);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final t = _animation.value;
      // Three swings that die out.
      final dx = math.sin(t * math.pi * 6) * _distance * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}
