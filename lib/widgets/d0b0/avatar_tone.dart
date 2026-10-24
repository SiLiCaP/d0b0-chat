// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:material_ui/material_ui.dart';

/// One of the four avatar tones from the green ramp. No pastel rainbow;
/// photos carry the colour.
class AvatarTone {
  final Color background;
  final Color foreground;

  const AvatarTone(this.background, this.foreground);

  static const _dark = [
    AvatarTone(D0b0Palette.deep, D0b0Palette.mint),
    AvatarTone(D0b0Palette.mint, D0b0Palette.ink),
    AvatarTone(D0b0Palette.green800, D0b0Palette.green400),
    AvatarTone(D0b0Palette.green700, D0b0Palette.green100),
  ];

  static const _light = [
    AvatarTone(D0b0Palette.deep, D0b0Palette.mint),
    AvatarTone(D0b0Palette.mint, D0b0Palette.ink),
    AvatarTone(D0b0Palette.green300, D0b0Palette.deep),
    AvatarTone(D0b0Palette.green200, D0b0Palette.green700),
  ];

  /// Picks the tone by hashing [seed] (the room or user ID). The hash is
  /// computed by hand so it is the same on every platform, web included.
  static AvatarTone of(String seed, Brightness brightness) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final tones = brightness == Brightness.dark ? _dark : _light;
    return tones[hash % tones.length];
  }
}
