// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Unread marker of a room row: a Signal pill with the count, '@' for
/// mentions, a dot when there is something new without a count. Muted
/// rooms get a tonal badge so they don't shout.
class UnreadBubble extends StatelessWidget {
  final Room room;
  const UnreadBubble({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    final count = room.notificationCount;
    final isMuted = room.pushRuleState != PushRuleState.notify;
    final label = room.highlightCount > 0
        ? '@'
        : count > 0
        ? (count > 99 ? '99+' : '$count')
        : room.markedUnread
        ? ''
        : null;
    final showDot =
        label == null &&
        (room.membership == Membership.invite || room.hasNewMessages);
    return D0b0Badge(
      label: label,
      dot: showDot,
      muted: isMuted && room.highlightCount == 0,
    );
  }
}

class D0b0Badge extends StatelessWidget {
  /// The text in the pill; null hides the pill.
  final String? label;

  /// Shows a small dot instead of a pill when there is no [label].
  final bool dot;

  final bool muted;

  const D0b0Badge({
    this.label,
    this.dot = false,
    this.muted = false,
    super.key,
  });

  static const double height = 22;
  static const double dotSize = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.d0b0;
    final background = muted
        ? theme.colorScheme.surfaceContainerHighest
        : colors.signal;
    final foreground = muted
        ? theme.colorScheme.onSurfaceVariant
        : colors.onSignal;
    final label = this.label;
    final Widget child;
    if (label != null) {
      child = Container(
        key: const ValueKey('pill'),
        height: height,
        constraints: const BoxConstraints(minWidth: height),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: D0b0Type.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            height: 1,
            color: foreground,
          ),
        ),
      );
    } else if (dot) {
      child = Container(
        key: const ValueKey('dot'),
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('none'));
    }
    // A new badge pops in with the overshoot curve; counting up afterwards
    // just swaps the number. Clearing fades out.
    return AnimatedSwitcher(
      duration: D0b0Motion.move,
      reverseDuration: D0b0Motion.state,
      switchInCurve: D0b0Motion.overshoot,
      transitionBuilder: (child, animation) =>
          child.key == const ValueKey('none')
          ? FadeTransition(opacity: animation, child: child)
          : ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
      child: child,
    );
  }
}
