import 'dart:async';
import 'dart:math';
import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

/// The bottom of the window: how far the soft keyboard covers it right now
/// and the system bar padding below the composer.
typedef BottomInsets = ({double keyboard, double padding});

/// Follows the soft keyboard so the emoji picker can take its place at the
/// same height and the composer does not move when switching (#67).
class KeyboardTracker extends ValueNotifier<BottomInsets> {
  KeyboardTracker() : super((keyboard: 0, padding: 0));

  /// How long the inset must hold still to count as the keyboard height.
  /// The keyboard reports a new inset every frame while it slides.
  static const Duration settleDelay = Duration(milliseconds: 150);

  /// Last settled keyboard height per orientation, kept for the session so
  /// every chat starts with it.
  static final Map<Orientation, double> _heights = {};

  @visibleForTesting
  static void forgetHeights() => _heights.clear();

  Orientation _orientation = Orientation.portrait;
  Timer? _settleTimer;

  /// Called once the keyboard stops moving.
  VoidCallback? onSettled;

  /// The keyboard height, measured from the bottom of the window, or null
  /// before a keyboard has been seen in this orientation.
  double? get keyboardHeight => _heights[_orientation];

  void update({
    required double keyboard,
    required double padding,
    required Orientation orientation,
  }) {
    _orientation = orientation;
    // Taller always counts. Smaller only once it has settled, as a closing
    // keyboard passes through every height on its way down.
    if (keyboard > (_heights[orientation] ?? 0)) {
      _heights[orientation] = keyboard;
    }
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, () {
      if (keyboard > 0) _heights[orientation] = keyboard;
      onSettled?.call();
    });
    value = (keyboard: keyboard, padding: padding);
  }

  void readFrom(FlutterView view) {
    final ratio = view.devicePixelRatio;
    final size = view.physicalSize;
    update(
      keyboard: view.viewInsets.bottom / ratio,
      padding: view.viewPadding.bottom / ratio,
      orientation: size.width > size.height
          ? Orientation.landscape
          : Orientation.portrait,
    );
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }
}

/// Height of the open emoji picker. Together with the keyboard still on
/// screen and the safe area below it, it fills [keyboardHeight], so while
/// the keyboard slides the picker grows or shrinks by the same amount.
/// Without a soft keyboard (desktop, web, hardware keyboard) it falls back
/// to a typical phone keyboard height. A keyboard that only shows a strip,
/// like the suggestions bar above a hardware keyboard, is not used.
double emojiPickerHeight({
  required double? keyboardHeight,
  required BottomInsets insets,
  required double windowHeight,
}) {
  const minHeight = 160.0;
  final fallback = min(windowHeight / 2, 300.0);
  final known = keyboardHeight == null ? null : keyboardHeight - insets.padding;
  final height = known != null && known >= minHeight ? known : fallback;
  return max(0, height + insets.padding - max(insets.keyboard, insets.padding));
}
