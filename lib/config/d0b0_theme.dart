// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:material_ui/material_ui.dart';

/// Hand-tuned d0b0 palette, matching the deployed Element Web "d0b0" theme.
///
/// Applied on top of the seed-derived [ColorScheme] only while the seed is the
/// d0b0 brand green, so other colours picked in the style settings still get
/// the plain Material 3 scheme.
abstract class D0b0Theme {
  static bool isBrandSeed(Color seed) =>
      seed.toARGB32() == AppConfig.primaryColor.toARGB32();

  static ColorScheme apply(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? _dark(scheme) : _light(scheme);

  static ColorScheme _dark(ColorScheme scheme) {
    const canvas = Color(0xFF060D06);
    const surface = Color(0xFF0A140A);
    const subtle = Color(0xFF143314);
    return scheme.copyWith(
      primary: const Color(0xFF3FD82F),
      onPrimary: const Color(0xFF041004),
      surface: canvas,
      surfaceDim: canvas,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: Color.lerp(surface, subtle, 1 / 3),
      surfaceContainerHigh: Color.lerp(surface, subtle, 2 / 3),
      surfaceContainerHighest: subtle,
      surfaceBright: subtle,
      onSurface: const Color(0xFFDFE8DF),
      onSurfaceVariant: const Color(0xFF8A9A8A),
      outlineVariant: const Color(0xFF2A3A2A),
    );
  }

  static ColorScheme _light(ColorScheme scheme) {
    const canvas = Color(0xFFF7FBF6);
    const surface = Color(0xFFEDF6EB);
    const subtle = Color(0xFFD2ECCE);
    return scheme.copyWith(
      primary: const Color(0xFF1F9915),
      onPrimary: const Color(0xFFFFFFFF),
      surface: canvas,
      surfaceBright: canvas,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: canvas,
      surfaceContainer: surface,
      surfaceContainerHigh: Color.lerp(surface, subtle, 0.5),
      surfaceContainerHighest: subtle,
      surfaceDim: subtle,
      onSurface: const Color(0xFF182018),
      onSurfaceVariant: const Color(0xFF54644F),
      outlineVariant: const Color(0xFFC2DCBE),
    );
  }
}
