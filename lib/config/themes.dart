// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Material window size classes. Wider windows add panes instead of
/// stretching; the phone layout is always one of the panes.
enum WindowSize {
  /// < 600: bottom nav pill, one pane, sheets from the bottom.
  compact,

  /// 600–839: navigation rail, one pane.
  medium,

  /// 840–1199: rail, room list 360, room pane.
  expanded,

  /// ≥ 1200: rail, list 360, room, details pane when open.
  large;

  static WindowSize of(BuildContext context) =>
      byWidth(MediaQuery.sizeOf(context).width);

  static WindowSize byWidth(double width) => width < 600
      ? compact
      : width < 840
      ? medium
      : width < 1200
      ? expanded
      : large;
}

abstract class FluffyThemes {
  /// The list pane: the phone list at 360.
  static const double columnWidth = 360.0;

  /// The details pane on large windows.
  static const double detailsPaneWidth = 400.0;

  static const double maxTimelineWidth = 960.0;

  static const double navRailWidth = 80.0;

  static bool isColumnModeByWidth(double width) => width >= 840;

  static bool isColumnMode(BuildContext context) =>
      isColumnModeByWidth(MediaQuery.sizeOf(context).width);

  static bool isThreeColumnMode(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;

  /// The rail replaces the bottom nav pill from medium windows up.
  static bool hasNavRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static LinearGradient backgroundGradient(BuildContext context, int alpha) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topCenter,
      colors: [
        colorScheme.primaryContainer.withAlpha(alpha),
        colorScheme.secondaryContainer.withAlpha(alpha),
        colorScheme.tertiaryContainer.withAlpha(alpha),
        colorScheme.primaryContainer.withAlpha(alpha),
      ],
    );
  }

  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Curve animationCurve = Curves.easeInOut;

  static ThemeData buildTheme(
    BuildContext context,
    Brightness brightness, [
    Color? seed,
  ]) {
    final seedColor = seed ?? Color(AppSettings.colorSchemeSeedInt.value);
    final isBrand = D0b0Theme.isBrandSeed(seedColor);
    final colorScheme = isBrand
        ? D0b0Theme.scheme(brightness)
        : ColorScheme.fromSeed(
            brightness: brightness,
            seedColor: seedColor,
            dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
          );
    final d0b0Colors = isBrand
        ? (brightness == Brightness.dark ? D0b0Colors.dark : D0b0Colors.light)
        : D0b0Colors.fromScheme(colorScheme);
    final textTheme = D0b0Type.textTheme(colorScheme);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    const stadium = StadiumBorder();
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(D0b0Radius.card),
    );
    final scrim = colorScheme.surface.withAlpha(184);
    // Every focusable control gets a 2 px Mint ring so pills keep their
    // pill; keyboard users always see where they are.
    final focusRing = WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: colorScheme.primary, width: 2)
          : null,
    );
    return ThemeData(
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: D0b0Type.sans,
      textTheme: textTheme,
      extensions: [d0b0Colors],
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      shadowColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // Android's default predictive back transition lets the topmost page of
      // each navigator take the back swipe for itself. A chat sits in two
      // nested navigators, so the room page took it and closed the chat past
      // dialogs and PopScopes above it. This is the same transition without
      // that, so every back goes through the router, which finds the
      // topmost route.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...const PageTransitionsTheme().builders,
          TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(
        size: 24,
        weight: 500,
        grade: brightness == Brightness.dark ? -25 : 0,
        opticalSize: 24,
        fill: 0,
        color: colorScheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          iconColor: colorScheme.onSurface,
          disabledIconColor: colorScheme.onSurface,
          shape: stadium,
          side: BorderSide(color: colorScheme.outline, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.primary.withAlpha(96),
        selectionHandleColor: colorScheme.primary,
        cursorColor: colorScheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        hintStyle: textTheme.bodyLarge?.copyWith(color: d0b0Colors.text3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        shape: stadium,
        backgroundColor: Colors.transparent,
        selectedColor: colorScheme.primary,
        labelStyle: textTheme.labelLarge!.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: colorScheme.outline, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        pressElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : Colors.transparent,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outline,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline,
        ),
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Icon(
                  Symbols.check_rounded,
                  size: 16,
                  color: colorScheme.primary,
                )
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: colorScheme.outline, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outline,
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: isColumnMode ? 72 : 56,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        actionsPadding: isColumnMode
            ? const EdgeInsets.symmetric(horizontal: 16.0)
            : null,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness.reversed,
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: brightness.reversed,
          systemNavigationBarColor: colorScheme.surface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: stadium,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        extendedTextStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorShape: stadium,
        indicatorColor: d0b0Colors.brand,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorShape: stadium,
        indicatorColor: d0b0Colors.brand,
        selectedIconTheme: IconThemeData(color: d0b0Colors.onBrand, fill: 1),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium,
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      dialogTheme: DialogThemeData(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        elevation: 0,
        barrierColor: scrim,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainerHigh,
        modalBarrierColor: scrim,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(D0b0Radius.card),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.outline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: textTheme.bodyLarge,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.surfaceContainerHigh,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: stadium,
              foregroundColor: colorScheme.onSurface,
              textStyle: textTheme.labelLarge,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ).copyWith(
              side: WidgetStateBorderSide.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ).copyWith(side: focusRing),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ).copyWith(side: focusRing),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: stadium,
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ).copyWith(side: focusRing),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: d0b0Colors.signal,
        textColor: d0b0Colors.onSignal,
        textStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        strokeCap: StrokeCap.round,
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: colorScheme.surfaceContainerHigh,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(colorScheme.outline),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          shape: stadium,
          color: colorScheme.inverseSurface,
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: colorScheme.primary,
        closeIconColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        shape: cardShape,
        showCloseIcon: isColumnMode ? true : null,
        width: isColumnMode ? FluffyThemes.columnWidth * 1.5 : null,
      ),
    );
  }
}

extension on Brightness {
  Brightness get reversed =>
      this == Brightness.dark ? Brightness.light : Brightness.dark;
}

extension BubbleColorTheme on ThemeData {
  D0b0Colors get d0b0 => extension<D0b0Colors>()!;

  Color get bubbleColor => d0b0.bubbleMine;

  Color get onBubbleColor => d0b0.onBubbleMine;

  Color get secondaryBubbleColor => d0b0.bubbleTheirs;

  Color get onSecondaryBubbleColor => d0b0.onBubbleTheirs;
}
