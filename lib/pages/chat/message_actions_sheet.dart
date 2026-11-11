// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat_emoji_picker.dart' show NoRecent;
import 'package:fluffychat/pages/chat/emoji_search_view.dart';
import 'package:fluffychat/pages/chat/sticker_picker_dialog.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/lift.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

enum MessageAction {
  reply,
  replyInThread,
  copy,
  forward,
  edit,
  pin,
  save,
  select,
  report,
  retry,
  delete,
}

/// What the actions sheet may offer for one message.
class MessageActionOptions {
  final bool canReact;
  final bool canReply;
  final bool canReplyInThread;
  final bool canCopy;
  final bool canEdit;
  final bool canPin;
  final bool isPinned;
  final bool canSave;
  final bool canReport;
  final bool canRetry;
  final bool canDelete;

  const MessageActionOptions({
    required this.canReact,
    required this.canReply,
    required this.canReplyInThread,
    required this.canCopy,
    required this.canEdit,
    required this.canPin,
    required this.isPinned,
    required this.canSave,
    required this.canReport,
    required this.canRetry,
    required this.canDelete,
  });
}

/// The quick reactions a new user starts with, in order.
const defaultQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// The quick reactions: the most recently used emoji first, filled up with
/// the defaults that are not among them.
List<String> mergeQuickReactions(Iterable<String> recent) => {
  ...recent,
  ...defaultQuickReactions,
}.take(defaultQuickReactions.length).toList();

/// [mergeQuickReactions] of the emoji used in the pickers.
Future<List<String>> loadQuickReactions() async {
  final recent = await EmojiPickerUtils().getRecentEmojis();
  return mergeQuickReactions(recent.map((e) => e.emoji.emoji));
}

/// Long-press on a message: quick reactions first, then actions. Returns the
/// chosen action, or the emoji (or sticker mxc URL) to react with.
Future<Object?> showMessageActionsSheet({
  required BuildContext context,
  required Event event,
  required MessageActionOptions options,
  required Set<String> sentReactions,
  LiftedBubble? lifted,
  Rect? anchor,
}) async {
  final quickReactions = await loadQuickReactions();
  if (!context.mounted) {
    lifted?.dispose();
    return null;
  }
  // The lift is for the sheet rising from the bottom on touch screens.
  if (lifted != null && FluffyThemes.isColumnMode(context)) {
    lifted.dispose();
    lifted = null;
  }
  final result = await showD0b0Sheet<Object>(
    context: context,
    anchor: anchor,
    isScrollControlled: true,
    builder: (context) {
      final l10n = L10n.of(context);
      final scheme = Theme.of(context).colorScheme;
      void pick(Object value) => Navigator.of(context).pop(value);
      Widget item(
        MessageAction action,
        IconData icon,
        String label, {
        bool destructive = false,
      }) => D0b0SheetRow(
        plain: true,
        icon: icon,
        title: label,
        destructive: destructive,
        onTap: () => pick(action),
      );
      final sheet = SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              if (options.canReact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Material(
                    color: scheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(D0b0Radius.card),
                    ),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          for (final emoji in quickReactions)
                            Expanded(
                              child: _QuickReaction(
                                emoji: emoji,
                                sent: sentReactions.contains(emoji),
                                onTap: () => pick(emoji),
                              ),
                            ),
                          IconButton(
                            tooltip: l10n.customReaction,
                            icon: Icon(
                              Symbols.add_reaction_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                            onPressed: () async {
                              final emoji = await _pickCustomReaction(
                                context,
                                event.room,
                              );
                              if (emoji == null || !context.mounted) return;
                              pick(emoji);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              if (options.canReply)
                item(MessageAction.reply, Symbols.reply_rounded, l10n.reply),
              if (options.canReplyInThread)
                item(
                  MessageAction.replyInThread,
                  Symbols.forum_rounded,
                  l10n.replyInThread,
                ),
              if (options.canCopy)
                item(
                  MessageAction.copy,
                  Symbols.content_copy_rounded,
                  l10n.copyText,
                ),
              item(
                MessageAction.forward,
                Symbols.forward_rounded,
                l10n.forward,
              ),
              if (options.canEdit)
                item(MessageAction.edit, Symbols.edit_rounded, l10n.edit),
              if (options.canPin)
                item(
                  MessageAction.pin,
                  Symbols.keep_rounded,
                  options.isPinned ? l10n.unpin : l10n.pin,
                ),
              if (options.canSave)
                item(
                  MessageAction.save,
                  Symbols.download_rounded,
                  l10n.downloadFile,
                ),
              item(
                MessageAction.select,
                Symbols.radio_button_unchecked_rounded,
                l10n.select,
              ),
              if (options.canRetry)
                item(
                  MessageAction.retry,
                  Symbols.refresh_rounded,
                  l10n.tryToSendAgain,
                ),
              if (options.canReport)
                item(
                  MessageAction.report,
                  Symbols.flag_rounded,
                  l10n.reportMessage,
                ),
              if (options.canDelete)
                item(
                  MessageAction.delete,
                  Symbols.delete_rounded,
                  l10n.delete,
                  destructive: true,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (lifted == null) return sheet;
      return LiftedBubbleHost(lifted: lifted, child: sheet);
    },
  );
  // A reaction counts as use, so the next sheet offers it. A sticker is an
  // mxc URL and has no place among emoji.
  if (result is String && !result.startsWith('mxc://')) {
    await EmojiPickerUtils().addEmojiToRecentlyUsed(
      key: GlobalKey<EmojiPickerState>(),
      emoji: Emoji(result, ''),
    );
  }
  return result;
}

class _QuickReaction extends StatelessWidget {
  final String emoji;
  final bool sent;
  final VoidCallback onTap;

  const _QuickReaction({
    required this.emoji,
    required this.sent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: sent ? scheme.surfaceContainerHighest : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Text(emoji, style: D0b0Type.emoji(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickCustomReaction(BuildContext context, Room room) {
  final theme = Theme.of(context);
  return showAdaptiveBottomSheet<String>(
    context: context,
    // Everything takes the colour of the sheet it sits in.
    builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(L10n.of(context).customReaction),
        leading: CloseButton(onPressed: () => Navigator.of(context).pop(null)),
      ),
      body: SizedBox(
        height: double.infinity,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: L10n.of(context).emojis),
                  Tab(text: L10n.of(context).stickers),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SearchableEmojiPicker(
                      onSelected: (emoji) => Navigator.of(context).pop(emoji),
                      config: Config(
                        locale: Localizations.localeOf(context),
                        emojiViewConfig: const EmojiViewConfig(
                          backgroundColor: Colors.transparent,
                          noRecents: NoRecent(),
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          // People react with a few favourites; the whole
                          // set is one tap or a search away.
                          initCategory: Category.RECENT,
                          backspaceColor: theme.colorScheme.primary,
                          iconColor: theme.colorScheme.onSurfaceVariant,
                          iconColorSelected: theme.colorScheme.primary,
                          indicatorColor: theme.colorScheme.primary,
                          backgroundColor: Colors.transparent,
                        ),
                        skinToneConfig: SkinToneConfig(
                          dialogBackgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                          indicatorColor: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    StickerPickerDialog(
                      room: room,
                      usage: ImagePackUsage.emoticon,
                      backgroundColor: Colors.transparent,
                      onSelected: (sticker) =>
                          Navigator.of(context).pop(sticker.url.toString()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
