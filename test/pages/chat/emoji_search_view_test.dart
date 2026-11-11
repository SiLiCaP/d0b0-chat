// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/emoji_search_view.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'search field stays above the keyboard and results can be picked',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showAdaptiveBottomSheet(
                context: context,
                builder: (context) => Scaffold(
                  body: SearchableEmojiPicker(
                    onSelected: (emoji) => Navigator.of(context).pop(emoji),
                    config: const Config(
                      bottomActionBarConfig: BottomActionBarConfig(
                        enabled: false,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(find.byType(TextField), 'grinning');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TextField)).bottom, lessThan(500));

      await tester.tap(find.text('😀').first);
      await tester.pumpAndSettle();
      expect(picked, '😀');
    },
  );
}
