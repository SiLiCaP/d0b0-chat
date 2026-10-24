// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/active_call_indicator.dart';
import 'package:fluffychat/pages/chat_list/unread_bubble.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/room_preview.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../config/themes.dart';
import '../../utils/date_time_extension.dart';
import '../../widgets/avatar.dart';

/// A room row: 72 high, one line of name and one of preview. Unread makes
/// the name heavier and the time Mint; everything else stays where it is,
/// so rows don't jump.
class ChatListItem extends StatelessWidget {
  final Room room;
  final Room? space;
  final bool activeChat;
  final void Function(BuildContext context)? onLongPress;
  final void Function()? onForget;
  final void Function() onTap;
  final String? filter;

  const ChatListItem(
    this.room, {
    this.activeChat = false,
    required this.onTap,
    this.onLongPress,
    this.onForget,
    this.filter,
    this.space,
    super.key,
  });

  static const double minHeight = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.d0b0;
    final l10n = L10n.of(context);

    final displayname = room.getLocalizedDisplayname(MatrixLocals(l10n));
    final filter = this.filter;
    if (filter != null && !displayname.toLowerCase().contains(filter)) {
      return const SizedBox.shrink();
    }

    final isMuted = room.pushRuleState != PushRuleState.notify;
    final isUnread =
        room.notificationCount > 0 || room.hasNewMessages || room.markedUnread;
    final hasBadge = room.isUnreadOrInvited || room.hasNewMessages;
    final directChatMatrixId = room.directChatMatrixID;

    final nameStyle = D0b0Type.subtitle.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
    );
    final timeStyle = D0b0Type.monoS.copyWith(
      color: isUnread && !isMuted ? theme.colorScheme.primary : colors.text3,
    );
    final previewStyle = D0b0Type.bodyS.copyWith(
      color: isUnread
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant,
    );

    return FutureBuilder(
      future: room.name.isEmpty ? room.loadHeroUsers() : null,
      builder: (context, _) => Material(
        color: activeChat
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => onLongPress?.call(context),
          onSecondaryTap: () => onLongPress?.call(context),
          hoverColor: theme.colorScheme.surfaceContainer,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Avatar(
                    mxContent: room.avatar,
                    name: displayname,
                    toneSeed: room.id,
                    isRoom: directChatMatrixId == null,
                    presenceUserId: directChatMatrixId,
                    presenceBackgroundColor: activeChat
                        ? theme.colorScheme.surfaceContainerHigh
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: nameStyle,
                                    ),
                                  ),
                                  if (isMuted)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Symbols.notifications_off_rounded,
                                        size: 16,
                                        color: colors.text3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!room.isSpace &&
                                room.membership != Membership.invite)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  room.latestEventReceivedTime
                                      .localizedTimeShort(context),
                                  style: timeStyle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (room.hasActiveMatrixRtcCall)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActiveCallIndicator(room: room),
                              ),
                            Expanded(
                              child: _PreviewLine(
                                room: room,
                                style: previewStyle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (hasBadge)
                              UnreadBubble(room: room)
                            else if (room.isFavourite)
                              Icon(
                                Symbols.push_pin_rounded,
                                size: 16,
                                color: colors.text3,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onForget != null)
                    IconButton(
                      icon: const Icon(Symbols.delete_rounded),
                      onPressed: onForget,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Typing replaces the preview in Mint. A draft shows 'Draft:' in Coral
/// until it is sent.
class _PreviewLine extends StatelessWidget {
  final Room room;
  final TextStyle style;

  const _PreviewLine({required this.room, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    final typingText = room.getLocalizedTypingText(context);
    if (typingText.isNotEmpty) {
      return _line(
        typingText,
        style.copyWith(color: theme.colorScheme.primary),
      );
    }

    if (room.isSpace && room.membership == Membership.join) {
      return _line(l10n.countChats(room.spaceChildren.length), style);
    }

    if (room.membership == Membership.invite) {
      final reason = room
          .getState(EventTypes.RoomMember, room.client.userID!)
          ?.content
          .tryGet<String>('reason');
      return _line(
        reason ??
            (room.isDirectChat ? l10n.newChatRequest : l10n.inviteGroupChat),
        style,
      );
    }

    final draft = Matrix.of(context).store.getString('draft_${room.id}');
    if (draft != null && draft.trim().isNotEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${l10n.draftPrefix} ',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            TextSpan(text: draft.trim().replaceAll('\n', ' ')),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      );
    }

    final preview = RoomPreview.of(room, l10n);
    if (preview == null) return _line(l10n.noMessagesYet, style);
    final sender = preview.sender;
    return _line(
      sender == null ? preview.body : '$sender ${preview.body}',
      room.lastEvent?.redacted == true
          ? style.copyWith(fontStyle: FontStyle.italic)
          : style,
    );
  }

  Widget _line(String text, TextStyle style) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
    style: style,
  );
}
