// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:material_ui/material_ui.dart';

/// Replaces every spinner: the mark's two bowls drift apart and back while
/// something is working. Use the small size inline.
///
/// With animations disabled it is a still 'Syncing…' in mono instead.
class SyncingBowls extends StatefulWidget {
  /// Height of the mark at rest.
  final double size;
  final Color? color;

  const SyncingBowls({this.size = 24, this.color, super.key});

  @override
  State<SyncingBowls> createState() => _SyncingBowlsState();
}

class _SyncingBowlsState extends State<SyncingBowls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final l10n = L10n.of(context);
    if (_reduceMotion) {
      return Text(
        l10n.syncingEllipsis,
        style: D0b0Type.monoS.copyWith(color: color),
      );
    }
    final scale = widget.size / D0b0MarkPath.height;
    // Leave room for the bowls to drift a quarter of the mark apart.
    final drift = widget.size * 0.14;
    return Semantics(
      label: l10n.syncingEllipsis,
      child: SizedBox(
        width: D0b0MarkPath.width * scale,
        height: widget.size + drift * 2,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) => CustomPaint(
            painter: _BowlsPainter(
              scale: scale,
              apart: Curves.easeInOutCubic.transform(_breath.value) * drift,
              top: drift,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _BowlsPainter extends CustomPainter {
  final double scale;
  final double apart;
  final double top;
  final Color color;

  const _BowlsPainter({
    required this.scale,
    required this.apart,
    required this.top,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(0, top - apart);
    canvas.scale(scale);
    canvas.drawPath(D0b0MarkPath.d, paint);
    canvas.restore();
    canvas.save();
    canvas.translate(0, top + apart);
    canvas.scale(scale);
    canvas.drawPath(D0b0MarkPath.b, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BowlsPainter oldDelegate) =>
      oldDelegate.apart != apart ||
      oldDelegate.color != color ||
      oldDelegate.scale != scale;
}
