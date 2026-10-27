import 'package:fluffychat/pages/chat/keyboard_tracker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(KeyboardTracker.forgetHeights);

  group('KeyboardTracker', () {
    // Widget tests run on fake time, so pump() fires the settle timer.
    Future<void> slide(
      WidgetTester tester,
      KeyboardTracker tracker,
      Iterable<double> insets, {
      Orientation orientation = Orientation.portrait,
    }) async {
      for (final inset in insets) {
        tracker.update(keyboard: inset, padding: 24, orientation: orientation);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(KeyboardTracker.settleDelay);
    }

    test('has no height before a keyboard was seen', () {
      expect(KeyboardTracker().keyboardHeight, isNull);
    });

    testWidgets('keeps the open height while the keyboard closes', (
      tester,
    ) async {
      final tracker = KeyboardTracker();
      await slide(tester, tracker, [0, 100, 250, 330]);
      expect(tracker.keyboardHeight, 330);
      await slide(tester, tracker, [250, 120, 40, 0]);
      expect(tracker.keyboardHeight, 330);
      tracker.dispose();
    });

    testWidgets('takes a smaller keyboard once it settles', (tester) async {
      final tracker = KeyboardTracker();
      await slide(tester, tracker, [330]);
      await slide(tester, tracker, [0]);
      await slide(tester, tracker, [150, 290]);
      expect(tracker.keyboardHeight, 290);
      tracker.dispose();
    });

    testWidgets('is shared between chats, per orientation', (tester) async {
      final first = KeyboardTracker();
      await slide(tester, first, [330]);
      await slide(tester, first, [200], orientation: Orientation.landscape);
      first.dispose();

      final second = KeyboardTracker();
      await slide(tester, second, [0]);
      expect(second.keyboardHeight, 330);
      await slide(tester, second, [0], orientation: Orientation.landscape);
      expect(second.keyboardHeight, 200);
      second.dispose();
    });
  });

  group('emojiPickerHeight', () {
    const windowHeight = 900.0;

    // The picker and the safe area below it fill the keyboard's space, so
    // the composer stays put whatever the keyboard is doing (#67).
    test('fills the space of the stored keyboard', () {
      for (final keyboard in [330.0, 200.0, 24.0, 10.0, 0.0]) {
        final picker = emojiPickerHeight(
          keyboardHeight: 330,
          insets: (keyboard: keyboard, padding: 24),
          windowHeight: windowHeight,
        );
        final safeArea = keyboard < 24 ? 24 - keyboard : 0;
        expect(picker + keyboard + safeArea, 330, reason: 'at $keyboard');
      }
    });

    test('falls back to a typical keyboard height', () {
      expect(
        emojiPickerHeight(
          keyboardHeight: null,
          insets: (keyboard: 0, padding: 0),
          windowHeight: windowHeight,
        ),
        300,
      );
      expect(
        emojiPickerHeight(
          keyboardHeight: null,
          insets: (keyboard: 0, padding: 0),
          windowHeight: 400,
        ),
        200,
      );
    });

    test('ignores a keyboard that is only a strip', () {
      expect(
        emojiPickerHeight(
          keyboardHeight: 72,
          insets: (keyboard: 0, padding: 24),
          windowHeight: windowHeight,
        ),
        300,
      );
    });
  });
}
