// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// An [InteractiveViewer] that reports whether it is currently zoomed in, so
/// the surrounding [PageView] can stop paging while the user pans the image.
///
/// Besides pinching, a double tap zooms in on the tapped point and back out,
/// and a double tap whose second touch is held and dragged zooms with one
/// finger: down zooms in, up zooms out.
class ZoomableImage extends StatefulWidget {
  final Widget child;
  final ValueNotifier<bool> zoomed;
  final GestureScaleEndCallback? onInteractionEnd;

  const ZoomableImage({
    required this.child,
    required this.zoomed,
    this.onInteractionEnd,
    super.key,
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  static const _zoomedThreshold = 1.01;
  static const _doubleTapScale = 2.5;
  static const _maxScale = 10.0;

  /// Max time and distance between the taps of a tap-drag.
  static const _tapDragGap = Duration(milliseconds: 300);
  static const _tapDragDistance = 48.0;
  static const _dragSlop = 16.0;

  /// Zoom factor per pixel of vertical drag, as an exponent.
  static const _dragZoomPerPixel = 0.006;

  final TransformationController _transformationController =
      TransformationController();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  Offset _doubleTapPosition = Offset.zero;

  int _pointers = 0;
  Offset _downPosition = Offset.zero;
  bool _downMoved = false;
  DateTime? _lastTapUp;
  Offset _lastTapPosition = Offset.zero;

  int? _tapDragPointer;
  bool _tapDragging = false;
  bool _tapDragAtLimit = false;
  Offset _tapDragStart = Offset.zero;
  Matrix4 _tapDragStartMatrix = Matrix4.identity();

  /// True from the second touch of a possible tap-drag until it ends. The
  /// viewer's own pan and pinch are off then, so they do not fight the drag.
  bool _tapDragCandidate = false;

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers > 1) {
      _lastTapUp = null;
      _endTapDrag();
      return;
    }
    _downPosition = event.localPosition;
    _downMoved = false;
    final lastTapUp = _lastTapUp;
    if (lastTapUp != null &&
        DateTime.now().difference(lastTapUp) < _tapDragGap &&
        (event.localPosition - _lastTapPosition).distance < _tapDragDistance) {
      _animationController.stop();
      _tapDragPointer = event.pointer;
      _tapDragging = false;
      _tapDragStart = event.localPosition;
      _tapDragStartMatrix = _transformationController.value.clone();
      setState(() => _tapDragCandidate = true);
    }
    _lastTapUp = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointers != 1) return;
    if ((event.localPosition - _downPosition).distance > _dragSlop) {
      _downMoved = true;
    }
    if (_tapDragPointer != event.pointer) return;
    if (!_tapDragging &&
        (event.localPosition - _tapDragStart).distance > _dragSlop) {
      _tapDragging = true;
      _tapDragAtLimit = false;
      HapticFeedback.selectionClick();
    }
    if (_tapDragging) _applyTapDrag(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers = max(0, _pointers - 1);
    if (_tapDragPointer == event.pointer) {
      _endTapDrag();
      return;
    }
    if (_pointers == 0 && !_downMoved) {
      _lastTapUp = DateTime.now();
      _lastTapPosition = event.localPosition;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers = max(0, _pointers - 1);
    _lastTapUp = null;
    _endTapDrag();
  }

  void _endTapDrag() {
    _tapDragPointer = null;
    _tapDragging = false;
    if (_tapDragCandidate && mounted) {
      setState(() => _tapDragCandidate = false);
    }
  }

  /// Zooms around where the drag started: dragging down zooms in, up out.
  void _applyTapDrag(Offset position) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final size = box.size;
    final start = _tapDragStartMatrix;
    final startScale = start.getMaxScaleOnAxis();
    final scale =
        (startScale * exp((position.dy - _tapDragStart.dy) * _dragZoomPerPixel))
            .clamp(1.0, _maxScale);
    // A firm tick once when the zoom hits either end.
    final atLimit = scale <= 1.0 || scale >= _maxScale;
    if (atLimit && !_tapDragAtLimit) HapticFeedback.heavyImpact();
    _tapDragAtLimit = atLimit;
    // The point of the image under the finger stays under it.
    final scenePoint = Offset(
      (_tapDragStart.dx - start.storage[12]) / startScale,
      (_tapDragStart.dy - start.storage[13]) / startScale,
    );
    final dx = (_tapDragStart.dx - scenePoint.dx * scale).clamp(
      size.width - size.width * scale,
      0.0,
    );
    final dy = (_tapDragStart.dy - scenePoint.dy * scale).clamp(
      size.height - size.height * scale,
      0.0,
    );
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  /// Double tap zooms in on the tapped point, or back out when already zoomed.
  void _onDoubleTap() {
    final current = _transformationController.value;
    final Matrix4 target;
    if (current.getMaxScaleOnAxis() > _zoomedThreshold) {
      HapticFeedback.lightImpact();
      target = Matrix4.identity();
    } else {
      HapticFeedback.mediumImpact();
      // Keeps the tapped point under the finger.
      target = Matrix4.identity()
        ..translateByDouble(
          -_doubleTapPosition.dx * (_doubleTapScale - 1),
          -_doubleTapPosition.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    final animation = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    void update() => _transformationController.value = animation.value;
    animation.addListener(update);
    _animationController.forward(from: 0).whenComplete(() {
      animation.removeListener(update);
    });
  }

  void _onTransformationChanged() {
    widget.zoomed.value =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedThreshold;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: _maxScale,
        panEnabled: !_tapDragCandidate,
        scaleEnabled: !_tapDragCandidate,
        onInteractionEnd: widget.onInteractionEnd,
        child: GestureDetector(
          // Swallows single taps, so they do not close the viewer behind it.
          onTap: () {},
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: _onDoubleTap,
          child: widget.child,
        ),
      ),
    );
  }
}
