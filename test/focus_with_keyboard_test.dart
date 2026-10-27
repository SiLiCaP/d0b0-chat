import 'package:fluffychat/utils/focus_with_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FocusNode focusNode;

  setUp(() => focusNode = FocusNode());
  tearDown(() => focusNode.dispose());

  Future<void> pumpField(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TextField(focusNode: focusNode)),
    ),
  );

  testWidgets('focuses an unfocused field', (tester) async {
    await pumpField(tester);
    expect(focusNode.hasFocus, isFalse);

    focusNode.requestFocusWithKeyboard();
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  // Swipe to reply after Back closed the keyboard (#72): the field is still
  // focused, so only an explicit show brings the keyboard back.
  testWidgets('shows the keyboard again for a focused field', (tester) async {
    await pumpField(tester);
    focusNode.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    // What Android's Back does: the keyboard goes, the focus stays.
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(focusNode.hasFocus, isTrue);

    focusNode.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);

    focusNode.requestFocusWithKeyboard();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
