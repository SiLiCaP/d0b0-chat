// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

/// An [InteractiveViewer] that reports whether it is currently zoomed in, so
/// the surrounding [PageView] can stop paging while the user pans the image.
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

class _ZoomableImageState extends State<ZoomableImage> {
  static const _zoomedThreshold = 1.01;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    widget.zoomed.value =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedThreshold;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 10.0,
      onInteractionEnd: widget.onInteractionEnd,
      child: widget.child,
    );
  }
}
