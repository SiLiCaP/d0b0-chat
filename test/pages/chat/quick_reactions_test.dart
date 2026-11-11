// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/message_actions_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no recent emoji: the defaults', () {
    expect(mergeQuickReactions([]), defaultQuickReactions);
  });

  test('recent emoji come first and the defaults fill the rest', () {
    expect(mergeQuickReactions(['🔥', '👍']), [
      '🔥',
      '👍',
      '❤️',
      '😂',
      '😮',
      '😢',
    ]);
  });

  test('enough recent emoji push the defaults out', () {
    final recent = ['🔥', '🎉', '👀', '💯', '🤝', '✨', '🙌'];
    expect(mergeQuickReactions(recent), recent.take(6));
  });

  test('an emoji is never offered twice', () {
    expect(mergeQuickReactions(['😂', '😂', '❤️']).toSet().length, 6);
  });
}
