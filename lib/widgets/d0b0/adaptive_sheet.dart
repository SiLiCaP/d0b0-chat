// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:material_ui/material_ui.dart';

/// Sheets are for choices. On phones they rise from the bottom and settle
/// with the overshoot curve. From expanded windows up they open as a
/// popover beside [anchor] (in global coordinates), or as a centred panel,
/// max 400 wide, when nothing anchors them. Same surface either way.
Future<T?> showD0b0Sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Rect? anchor,
}) {
  if (FluffyThemes.isColumnMode(context)) {
    if (anchor != null) {
      return _showPopover<T>(
        context: context,
        anchor: anchor,
        builder: builder,
      );
    }
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: builder(context),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    sheetAnimationStyle: const AnimationStyle(
      duration: D0b0Motion.move,
      curve: D0b0Motion.overshoot,
      reverseDuration: D0b0Motion.state,
      reverseCurve: D0b0Motion.exit,
    ),
    builder: builder,
  );
}

/// Where [context]'s widget is on screen, to anchor a sheet to it.
Rect? d0b0AnchorOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<T?> _showPopover<T>({
  required BuildContext context,
  required Rect anchor,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: D0b0Motion.state,
    pageBuilder: (context, _, _) {
      final scheme = Theme.of(context).colorScheme;
      return CustomSingleChildLayout(
        delegate: _PopoverLayout(
          anchor: anchor,
          padding: MediaQuery.paddingOf(context),
        ),
        child: Material(
          color: scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(D0b0Radius.card),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            // The sheets' own safe areas are for the bottom of a phone.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: builder(context),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: D0b0Motion.standard,
        reverseCurve: D0b0Motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Places a popover below or above its anchor, lined up with the anchor's
/// edge nearer the screen edge. Anchors in the rail open to their right.
class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final EdgeInsets padding;

  const _PopoverLayout({required this.anchor, required this.padding});

  static const double width = 360;
  static const double gap = 8;
  static const double margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: min(width, constraints.maxWidth - 2 * margin),
        maxHeight: max(
          0,
          constraints.maxHeight - padding.vertical - 2 * margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final top = padding.top + margin;
    final bottom = size.height - padding.bottom - margin;
    double x;
    double y;
    if (anchor.right <= FluffyThemes.navRailWidth) {
      x = anchor.right + gap;
      // Top-aligned in the upper half, bottom-aligned in the lower half.
      y = anchor.center.dy < size.height / 2
          ? anchor.top
          : anchor.bottom - child.height;
    } else {
      x = anchor.center.dx < size.width / 2
          ? anchor.left
          : anchor.right - child.width;
      final below = anchor.bottom + gap;
      final above = anchor.top - gap - child.height;
      y = below + child.height <= bottom || above < top ? below : above;
    }
    return Offset(
      x.clamp(margin, max(margin, size.width - margin - child.width)),
      y.clamp(top, max(top, bottom - child.height)),
    );
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}
