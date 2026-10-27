import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

extension FocusWithKeyboard on FocusNode {
  /// Focuses the field and brings the soft keyboard up.
  ///
  /// Android's Back hides the keyboard but leaves the field focused, and
  /// [requestFocus] on a focused node changes nothing, so the keyboard would
  /// stay down. Asking the text input to show again is what tapping the
  /// focused field does.
  void requestFocusWithKeyboard() {
    if (hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      requestFocus();
    }
  }
}
