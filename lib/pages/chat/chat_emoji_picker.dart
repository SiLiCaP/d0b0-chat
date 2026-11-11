// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/emoji_search_view.dart';
import 'package:fluffychat/pages/chat/sticker_picker_dialog.dart';
import 'package:fluffychat/pages/chat/trust_user_key_dialog.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'chat.dart';
import 'keyboard_tracker.dart';

class ChatEmojiPicker extends StatelessWidget {
  final ChatController controller;
  const ChatEmojiPicker(this.controller, {super.key});

  /// The picker sits in the composer's area, which gives way to the
  /// keyboard, so a search field typed into there would vanish with it. The
  /// search opens in a sheet that makes room for the keyboard instead.
  Future<void> _search(BuildContext context) async {
    final emoji = await showAdaptiveBottomSheet<String>(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(L10n.of(context).emojis),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: SearchableEmojiPicker(
          autofocus: true,
          config: _emojiConfig(context, inSheet: true),
          onSelected: (emoji) => Navigator.of(context).pop(emoji),
        ),
      ),
    );
    if (emoji == null) return;
    controller.onEmojiSelected(null, Emoji(emoji, ''));
  }

  /// In a sheet the picker takes the sheet's colour, not the composer's.
  Config _emojiConfig(BuildContext context, {bool inSheet = false}) {
    final theme = Theme.of(context);
    return Config(
      locale: Localizations.localeOf(context),
      emojiViewConfig: EmojiViewConfig(
        noRecents: const NoRecent(),
        backgroundColor: inSheet
            ? Colors.transparent
            : theme.colorScheme.onInverseSurface,
      ),
      bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
      categoryViewConfig: CategoryViewConfig(
        backspaceColor: theme.colorScheme.primary,
        iconColor: theme.colorScheme.primary.withAlpha(128),
        iconColorSelected: theme.colorScheme.primary,
        indicatorColor: theme.colorScheme.primary,
        backgroundColor: inSheet
            ? Colors.transparent
            : theme.colorScheme.surface,
      ),
      skinToneConfig: SkinToneConfig(
        dialogBackgroundColor: Color.lerp(
          theme.colorScheme.surface,
          theme.colorScheme.primaryContainer,
          0.75,
        )!,
        indicatorColor: theme.colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open =
        controller.showEmojiPicker || controller.emojiPickerHandingOver;
    final windowHeight = MediaQuery.sizeOf(context).height;
    // Rebuilds every frame while the keyboard slides, so the picker content
    // is built once and passed through.
    return ValueListenableBuilder(
      valueListenable: controller.keyboard,
      builder: (context, insets, child) {
        // While a keyboard is moving the picker follows it frame by frame;
        // an animation of its own would lag behind and the composer jumps.
        final followsKeyboard =
            insets.keyboard > 0 || controller.emojiPickerHandingOver;
        return AnimatedContainer(
          duration: followsKeyboard
              ? Duration.zero
              : FluffyThemes.animationDuration,
          curve: FluffyThemes.animationCurve,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          height: open
              ? emojiPickerHeight(
                  keyboardHeight: controller.keyboard.keyboardHeight,
                  insets: insets,
                  windowHeight: windowHeight,
                )
              : 0,
          child: open ? child : null,
        );
      },
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: L10n.of(context).emojis),
                      Tab(text: L10n.of(context).stickers),
                    ],
                  ),
                ),
                // The stickers tab has a search field of its own.
                Builder(
                  builder: (context) {
                    final animation = DefaultTabController.of(
                      context,
                    ).animation!;
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) => animation.value < 0.5
                          ? IconButton(
                              tooltip: L10n.of(context).search,
                              icon: const Icon(Symbols.search_rounded),
                              onPressed: () => _search(context),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  EmojiPicker(
                    onEmojiSelected: controller.onEmojiSelected,
                    onBackspacePressed: controller.emojiPickerBackspace,
                    config: _emojiConfig(context),
                  ),
                  StickerPickerDialog(
                    room: controller.room,
                    onSelected: (sticker) async {
                      final proceed = await showTrustUserInRoomDialog(
                        context,
                        controller.room,
                      );
                      if (!proceed) return;
                      controller.room.sendEvent(
                        {
                          'body': sticker.body,
                          'info': sticker.info ?? {},
                          'url': sticker.url.toString(),
                        },
                        type: EventTypes.Sticker,
                        threadRootEventId: controller.activeThreadId,
                        threadLastEventId: controller.threadLastEventId,
                      );
                      controller.hideEmojiPicker();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoRecent extends StatelessWidget {
  const NoRecent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          L10n.of(context).emoteKeyboardNoRecents,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
