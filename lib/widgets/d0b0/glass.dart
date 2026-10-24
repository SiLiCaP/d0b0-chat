// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Overlays on footage are glass pills (Night at 62 %), so they read on any
/// frame.
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const GlassPill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: padding,
    decoration: const ShapeDecoration(
      color: D0b0Palette.glass,
      shape: StadiumBorder(),
    ),
    // Hug the content; only centre it vertically.
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: D0b0Palette.green100),
      child: IconTheme.merge(
        data: const IconThemeData(color: D0b0Palette.green100),
        child: Center(widthFactor: 1, child: child),
      ),
    ),
  );
}

/// A round glass button over footage: close, play, pause.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool filledIcon;

  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.filledIcon = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: size * 0.45,
    style: IconButton.styleFrom(
      backgroundColor: D0b0Palette.glass,
      foregroundColor: D0b0Palette.green100,
      fixedSize: Size.square(size),
      minimumSize: Size.square(size),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon, fill: filledIcon ? 1 : 0),
  );
}
