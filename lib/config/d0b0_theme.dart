// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:material_ui/material_ui.dart';

/// The d0b0 design system v1 (Penpot file "dobo DS", page "01 · Foundations").
///
/// Every colour in the app maps to a role, never to a raw hex. Roles are
/// defined by hand for dark and light; nothing is generated from the seed
/// while the seed is the d0b0 brand colour. Other colours picked in the style
/// settings still get a seed-derived Material 3 scheme, with the roles
/// derived from it.
abstract class D0b0Palette {
  // Green ramp
  static const green1000 = Color(0xFF0A130D);
  static const green950 = Color(0xFF0F1A12); // Night
  static const green900 = Color(0xFF1B2A1F); // Moss
  static const green850 = Color(0xFF233528);
  static const green800 = Color(0xFF2E4433);
  static const green700 = Color(0xFF3E5844);
  static const green600 = Color(0xFF5E7A62);
  static const green500 = Color(0xFF7F9479);
  static const green400 = Color(0xFFA9BBA4); // Lichen
  static const green300 = Color(0xFFC9D8C4);
  static const green200 = Color(0xFFD8E6D3);
  static const green100 = Color(0xFFE6F0E2);
  static const green50 = Color(0xFFF3F8F0); // Paper

  // Brand
  static const deep = Color(0xFF16520E);
  static const deepHi = Color(0xFF1F6B16);
  static const mint = Color(0xFFB1F49D);
  static const mintHi = Color(0xFFC8F8B8);
  static const signal = Color(0xFF3FD82F);
  static const ink = Color(0xFF0C2408);

  // Status
  static const amber = Color(0xFFE8C25A);
  static const amberDeep = Color(0xFF8A6A00);
  static const coral = Color(0xFFFF8B7B);
  static const coralDeep = Color(0xFFB3261E);

  /// Scrim behind dialogs and sheets: Night at 72 %.
  static const scrim = Color(0xB80F1A12);

  /// Glass pills over footage: Night at 62 %.
  static const glass = Color(0x9E0F1A12);
}

abstract class D0b0Theme {
  static bool isBrandSeed(Color seed) =>
      seed.toARGB32() == AppConfig.primaryColor.toARGB32();

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: D0b0Palette.mint,
    onPrimary: D0b0Palette.ink,
    primaryContainer: D0b0Palette.deep,
    onPrimaryContainer: D0b0Palette.mint,
    secondary: D0b0Palette.mint,
    onSecondary: D0b0Palette.ink,
    secondaryContainer: D0b0Palette.green850,
    onSecondaryContainer: D0b0Palette.green100,
    tertiary: D0b0Palette.signal,
    onTertiary: D0b0Palette.ink,
    tertiaryContainer: D0b0Palette.deep,
    onTertiaryContainer: D0b0Palette.mint,
    error: D0b0Palette.coral,
    onError: D0b0Palette.ink,
    errorContainer: D0b0Palette.coralDeep,
    onErrorContainer: D0b0Palette.green100,
    surface: D0b0Palette.green950,
    onSurface: D0b0Palette.green100,
    onSurfaceVariant: D0b0Palette.green400,
    surfaceDim: D0b0Palette.green1000,
    surfaceBright: D0b0Palette.green800,
    surfaceContainerLowest: D0b0Palette.green1000,
    surfaceContainerLow: Color(0xFF15221A),
    surfaceContainer: D0b0Palette.green900,
    surfaceContainerHigh: D0b0Palette.green850,
    surfaceContainerHighest: D0b0Palette.green800,
    outline: D0b0Palette.green700,
    outlineVariant: D0b0Palette.green850,
    shadow: Colors.transparent,
    scrim: D0b0Palette.green1000,
    inverseSurface: D0b0Palette.green100,
    onInverseSurface: D0b0Palette.green950,
    inversePrimary: D0b0Palette.deep,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: D0b0Palette.deep,
    onPrimary: D0b0Palette.mint,
    primaryContainer: D0b0Palette.mint,
    onPrimaryContainer: D0b0Palette.ink,
    secondary: D0b0Palette.deep,
    onSecondary: D0b0Palette.mint,
    secondaryContainer: D0b0Palette.green200,
    onSecondaryContainer: D0b0Palette.green950,
    tertiary: D0b0Palette.deepHi,
    onTertiary: Colors.white,
    tertiaryContainer: D0b0Palette.mint,
    onTertiaryContainer: D0b0Palette.ink,
    error: D0b0Palette.coralDeep,
    onError: Colors.white,
    errorContainer: D0b0Palette.coral,
    onErrorContainer: D0b0Palette.ink,
    surface: D0b0Palette.green50,
    onSurface: D0b0Palette.green950,
    onSurfaceVariant: D0b0Palette.green700,
    surfaceDim: D0b0Palette.green200,
    surfaceBright: D0b0Palette.green50,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFEBF3E8),
    surfaceContainer: Color(0xFFE4EEE0),
    surfaceContainerHigh: D0b0Palette.green200,
    surfaceContainerHighest: D0b0Palette.green300,
    outline: D0b0Palette.green400,
    outlineVariant: D0b0Palette.green200,
    shadow: Colors.transparent,
    scrim: D0b0Palette.green950,
    inverseSurface: D0b0Palette.green950,
    onInverseSurface: D0b0Palette.green100,
    inversePrimary: D0b0Palette.mint,
    surfaceTint: Colors.transparent,
  );

  static ColorScheme scheme(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// The roles that have no slot in [ColorScheme].
@immutable
class D0b0Colors extends ThemeExtension<D0b0Colors> {
  /// Unread badges, online dots and mention markers. Never text on light.
  final Color signal;
  final Color onSignal;

  /// The brand surface: Deep in both modes (selection bar, light FAB).
  final Color brand;
  final Color onBrand;

  final Color bubbleMine;
  final Color onBubbleMine;
  final Color bubbleTheirs;
  final Color onBubbleTheirs;

  /// Timestamps, hints and disabled text; the contrast floor.
  final Color text3;

  final Color online;
  final Color away;
  final Color offline;

  /// Reserved for warnings (key backup).
  final Color warning;

  const D0b0Colors({
    required this.signal,
    required this.onSignal,
    required this.brand,
    required this.onBrand,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleTheirs,
    required this.onBubbleTheirs,
    required this.text3,
    required this.online,
    required this.away,
    required this.offline,
    required this.warning,
  });

  static const dark = D0b0Colors(
    signal: D0b0Palette.signal,
    onSignal: D0b0Palette.ink,
    brand: D0b0Palette.deep,
    onBrand: D0b0Palette.mint,
    bubbleMine: D0b0Palette.deep,
    onBubbleMine: D0b0Palette.green100,
    bubbleTheirs: D0b0Palette.green900,
    onBubbleTheirs: D0b0Palette.green100,
    text3: D0b0Palette.green500,
    online: D0b0Palette.signal,
    away: D0b0Palette.signal,
    offline: D0b0Palette.green600,
    warning: D0b0Palette.amber,
  );

  static const light = D0b0Colors(
    signal: D0b0Palette.signal,
    onSignal: D0b0Palette.ink,
    brand: D0b0Palette.deep,
    onBrand: D0b0Palette.mint,
    bubbleMine: D0b0Palette.mint,
    onBubbleMine: D0b0Palette.ink,
    bubbleTheirs: Color(0xFFE4EEE0),
    onBubbleTheirs: D0b0Palette.green950,
    text3: D0b0Palette.green600,
    online: D0b0Palette.deepHi,
    away: D0b0Palette.deepHi,
    offline: D0b0Palette.green600,
    warning: D0b0Palette.amberDeep,
  );

  /// Roles for a seed-derived scheme, used when another colour is picked.
  factory D0b0Colors.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return D0b0Colors(
      signal: scheme.tertiary,
      onSignal: scheme.onTertiary,
      brand: isDark ? scheme.primaryContainer : scheme.primary,
      onBrand: isDark ? scheme.onPrimaryContainer : scheme.onPrimary,
      bubbleMine: isDark ? scheme.primaryContainer : scheme.primary,
      onBubbleMine: isDark ? scheme.onPrimaryContainer : scheme.onPrimary,
      bubbleTheirs: scheme.surfaceContainer,
      onBubbleTheirs: scheme.onSurface,
      text3: scheme.outline,
      online: scheme.tertiary,
      away: scheme.tertiary,
      offline: scheme.outline,
      warning: isDark ? D0b0Palette.amber : D0b0Palette.amberDeep,
    );
  }

  static D0b0Colors of(BuildContext context) =>
      Theme.of(context).extension<D0b0Colors>()!;

  @override
  D0b0Colors copyWith({
    Color? signal,
    Color? onSignal,
    Color? brand,
    Color? onBrand,
    Color? bubbleMine,
    Color? onBubbleMine,
    Color? bubbleTheirs,
    Color? onBubbleTheirs,
    Color? text3,
    Color? online,
    Color? away,
    Color? offline,
    Color? warning,
  }) => D0b0Colors(
    signal: signal ?? this.signal,
    onSignal: onSignal ?? this.onSignal,
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    bubbleMine: bubbleMine ?? this.bubbleMine,
    onBubbleMine: onBubbleMine ?? this.onBubbleMine,
    bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
    onBubbleTheirs: onBubbleTheirs ?? this.onBubbleTheirs,
    text3: text3 ?? this.text3,
    online: online ?? this.online,
    away: away ?? this.away,
    offline: offline ?? this.offline,
    warning: warning ?? this.warning,
  );

  @override
  D0b0Colors lerp(D0b0Colors? other, double t) {
    if (other == null) return this;
    return D0b0Colors(
      signal: Color.lerp(signal, other.signal, t)!,
      onSignal: Color.lerp(onSignal, other.onSignal, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      onBubbleMine: Color.lerp(onBubbleMine, other.onBubbleMine, t)!,
      bubbleTheirs: Color.lerp(bubbleTheirs, other.bubbleTheirs, t)!,
      onBubbleTheirs: Color.lerp(onBubbleTheirs, other.onBubbleTheirs, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      online: Color.lerp(online, other.online, t)!,
      away: Color.lerp(away, other.away, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Inter for everything people write, JetBrains Mono for everything the
/// machine says. Ten styles; letter-spacing is 0 for body text.
abstract class D0b0Type {
  static const String sans = 'Inter';
  static const String mono = 'JetBrains Mono';

  static const display = TextStyle(
    fontFamily: sans,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.7,
  );
  static const headline = TextStyle(
    fontFamily: sans,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );
  static const title = TextStyle(
    fontFamily: sans,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );
  static const subtitle = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );
  static const bodyS = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );
  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );
  static const overline = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1,
  );
  static const monoStyle = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0,
  );
  static const monoS = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Maps the ten styles onto Material's slots so every existing
  /// `textTheme.*` lookup lands on one of them.
  static TextTheme textTheme(ColorScheme scheme) {
    final text = scheme.onSurface;
    final text2 = scheme.onSurfaceVariant;
    return TextTheme(
      displayLarge: display.copyWith(color: text),
      displayMedium: display.copyWith(color: text),
      displaySmall: display.copyWith(color: text),
      headlineLarge: headline.copyWith(color: text),
      headlineMedium: headline.copyWith(color: text),
      headlineSmall: headline.copyWith(color: text),
      titleLarge: title.copyWith(color: text),
      titleMedium: subtitle.copyWith(color: text),
      titleSmall: label.copyWith(color: text),
      bodyLarge: body.copyWith(color: text),
      bodyMedium: bodyS.copyWith(color: text),
      bodySmall: bodyS.copyWith(color: text2),
      labelLarge: label.copyWith(color: text),
      labelMedium: label.copyWith(fontSize: 12, color: text),
      labelSmall: label.copyWith(fontSize: 12, color: text2),
    );
  }
}

/// Four radii, nothing else.
abstract class D0b0Radius {
  /// Controls are pills: radius = height ÷ 2.
  static const double pill = 999;

  /// Messages: a pill on one line, 22 when wrapped.
  static const double bubble = 22;

  /// Cards, sheets, dialogs, menus, settings groups.
  static const double card = 28;

  /// Room and space avatars at 48 (radius = size ÷ 3).
  static const double room = 16;
}

/// Four durations and three curves, nothing else.
abstract class D0b0Motion {
  /// Press feedback.
  static const press = Duration(milliseconds: 100);

  /// State changes: outline → fill, chip select, toggle, colour.
  static const state = Duration(milliseconds: 150);

  /// Anything that moves: page push, sheet, tab indicator, bubble rise.
  static const move = Duration(milliseconds: 250);

  /// Brand moments only: splash drop, first-run empty state.
  static const brand = Duration(milliseconds: 400);

  /// Default for movement and fades.
  static const standard = Curves.easeInOutCubicEmphasized;

  /// Arrivals: badge pop, b drop, sheet settle.
  static const overshoot = Curves.easeOutBack;

  /// Leaving: sheet dismiss, snackbar out.
  static const exit = Curves.easeInCubic;

  /// Scale applied to a control while it is pressed.
  static const double pressScale = 0.97;
}
