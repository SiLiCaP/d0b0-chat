// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/events/bubble_meta_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(String text, {TextStyle? style}) => MaterialApp(
  home: SelectionArea(
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: BubbleMetaLayout(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Text.rich(
                TextSpan(text: text),
                key: const Key('text'),
                style: style,
              ),
            ),
            const SizedBox(key: Key('meta'), width: 60, height: 14),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('short text: meta sits beside it, same height', (tester) async {
    await tester.pumpWidget(_harness('hi'));
    final text = tester.getRect(find.byKey(const Key('text')));
    final meta = tester.getRect(find.byKey(const Key('meta')));
    final size = tester.getSize(find.byType(BubbleMetaLayout));
    expect(meta.left, greaterThanOrEqualTo(text.right));
    expect(size.height, text.height + 22);
    expect(meta.bottom, size.height);
    expect(size.width, lessThan(300));
  });

  testWidgets('full last line: meta gets its own row', (tester) async {
    await tester.pumpWidget(
      // Ahem is 16 wide at this size: two full lines of 16 characters.
      _harness('x' * 32, style: const TextStyle(fontSize: 16)),
    );
    final text = tester.getRect(find.byKey(const Key('text')));
    final meta = tester.getRect(find.byKey(const Key('meta')));
    expect(meta.top, greaterThanOrEqualTo(text.bottom + 11));
    expect(meta.right, tester.getSize(find.byType(BubbleMetaLayout)).width);
  });

  testWidgets('line height leading under the text does not matter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness('hi', style: const TextStyle(fontSize: 16, height: 1.8)),
    );
    final text = tester.getRect(find.byKey(const Key('text')));
    final size = tester.getSize(find.byType(BubbleMetaLayout));
    expect(size.height, text.height + 22);
  });

  testWidgets('short last line of a long text takes the meta', (tester) async {
    await tester.pumpWidget(_harness('${'word ' * 30}end'));
    final text = tester.getRect(find.byKey(const Key('text')));
    final size = tester.getSize(find.byType(BubbleMetaLayout));
    expect(size.height, text.height + 22);
  });
}
