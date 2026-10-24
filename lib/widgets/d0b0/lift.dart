// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'dart:ui' as ui;

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Marks the part of a row that lifts on long-press: the bubble, without
/// its reactions. Hidden while a [LiftedBubble] of it is shown.
class LiftSource extends StatefulWidget {
  final Widget child;

  const LiftSource({required this.child, super.key});

  @override
  State<LiftSource> createState() => _LiftSourceState();
}

class _LiftSourceState extends State<LiftSource> {
  final GlobalKey _boundary = GlobalKey();
  bool _hidden = false;

  void _setHidden(bool hidden) {
    if (!mounted || _hidden == hidden) return;
    setState(() => _hidden = hidden);
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: _hidden ? 0 : 1,
    child: RepaintBoundary(key: _boundary, child: widget.child),
  );
}

/// A still copy of a pressed bubble and where it was on screen.
class LiftedBubble {
  final ui.Image image;

  /// In global coordinates.
  final Rect rect;

  final _LiftSourceState _source;

  LiftedBubble._(this.image, this.rect, this._source);

  /// Copies the first [LiftSource] below [context], if it is on screen.
  static LiftedBubble? capture(BuildContext context) {
    _LiftSourceState? source;
    void visit(Element element) {
      if (source != null) return;
      if (element is StatefulElement && element.state is _LiftSourceState) {
        source = element.state as _LiftSourceState;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    final boundary = source?._boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
    final image = boundary.toImageSync(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final rect = boundary.localToGlobal(Offset.zero) & boundary.size;
    return LiftedBubble._(image, rect, source!);
  }

  void dispose() {
    _source._setHidden(false);
    image.dispose();
  }
}

/// Wraps a modal bottom sheet's content: shows [lifted] above the scrim,
/// scaled up a little and moved with the sheet so it settles just above it.
/// It owns [lifted] and disposes it once the sheet has gone.
class LiftedBubbleHost extends StatefulWidget {
  final LiftedBubble lifted;
  final Widget child;

  const LiftedBubbleHost({
    required this.lifted,
    required this.child,
    super.key,
  });

  /// The bubble grows over this part of the sheet's rise.
  static const Duration lift = Duration(milliseconds: 150);

  static const double scale = 1.03;

  /// Space between the bubble and the sheet's top edge.
  static const double gap = 12;

  @override
  State<LiftedBubbleHost> createState() => _LiftedBubbleHostState();
}

class _LiftedBubbleHostState extends State<LiftedBubbleHost> {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _content = GlobalKey();
  final GlobalKey _canvas = GlobalKey();
  Animation<double>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.animation;
    if (route == _route) return;
    _route?.removeStatusListener(_onStatus);
    _route = route?..addStatusListener(_onStatus);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.lifted._source._setHidden(true);
      _portal.show();
    });
  }

  void _onStatus(AnimationStatus status) {
    // Back in its place: the row shows the bubble again in the same frame
    // the copy is last drawn.
    if (status.isDismissed) widget.lifted._source._setHidden(false);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onStatus);
    widget.lifted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route ?? const AlwaysStoppedAnimation(1.0);
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => IgnorePointer(
        child: CustomPaint(
          key: _canvas,
          size: Size.infinite,
          painter: _LiftPainter(
            lifted: widget.lifted,
            animation: route,
            content: _content,
            canvas: _canvas,
            topPadding: MediaQuery.paddingOf(context).top,
            handle: Theme.of(context).bottomSheetTheme.showDragHandle == true
                ? kMinInteractiveDimension
                : 0,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
        ),
      ),
      child: KeyedSubtree(key: _content, child: widget.child),
    );
  }
}

class _LiftPainter extends CustomPainter {
  final LiftedBubble lifted;
  final Animation<double> animation;
  final GlobalKey content;
  final GlobalKey canvas;
  final double topPadding;
  final double handle;
  final bool reduceMotion;

  _LiftPainter({
    required this.lifted,
    required this.animation,
    required this.content,
    required this.canvas,
    required this.topPadding,
    required this.handle,
    required this.reduceMotion,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final own = this.canvas.currentContext?.findRenderObject();
    final sheet = content.currentContext?.findRenderObject();
    if (own is! RenderBox || sheet is! RenderBox || !sheet.hasSize) return;
    final origin = own.localToGlobal(Offset.zero);
    final rect = lifted.rect.shift(-origin);

    // Where the sheet's top edge is now, and where it comes to rest.
    final sheetTop = sheet.localToGlobal(Offset.zero).dy - origin.dy - handle;
    final restingTop = size.height - sheet.size.height - handle;

    final t = animation.value;
    var dy = 0.0;
    var scale = 1.0;
    if (!reduceMotion) {
      final target = max(
        topPadding + LiftedBubbleHost.gap,
        min(rect.top, restingTop - LiftedBubbleHost.gap - rect.height),
      );
      // Follows the sheet itself: its overshoot, its exit and drags.
      final risen = (size.height - sheetTop) / (size.height - restingTop);
      dy = (target - rect.top) * risen;
      final liftShare =
          LiftedBubbleHost.lift.inMicroseconds / D0b0Motion.move.inMicroseconds;
      scale =
          1 +
          (LiftedBubbleHost.scale - 1) *
              Curves.easeOut.transform((t / liftShare).clamp(0.0, 1.0));
    }

    final destination = Rect.fromCenter(
      center: rect.center.translate(0, dy),
      width: rect.width * scale,
      height: rect.height * scale,
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, max(0, sheetTop)));
    canvas.drawImageRect(
      lifted.image,
      Offset.zero &
          Size(lifted.image.width.toDouble(), lifted.image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiftPainter oldDelegate) =>
      oldDelegate.lifted != lifted ||
      oldDelegate.animation != animation ||
      oldDelegate.topPadding != topPadding ||
      oldDelegate.handle != handle ||
      oldDelegate.reduceMotion != reduceMotion;
}
