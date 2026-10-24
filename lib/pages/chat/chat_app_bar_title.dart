// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/sync_status_localization.dart';
import 'package:fluffychat/utils/verified_room_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/presence_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class ChatAppBarTitle extends StatelessWidget {
  final ChatController controller;
  const ChatAppBarTitle(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final room = controller.room;
    if (controller.selectedEvents.isNotEmpty) {
      return Text(
        controller.selectedEvents.length.toString(),
        style: D0b0Type.title.copyWith(color: theme.d0b0.onBrand),
      );
    }
    final statusStyle = D0b0Type.monoS.copyWith(color: theme.d0b0.text3);
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: controller.room.membership != .join
          ? null
          : () => FluffyThemes.isThreeColumnMode(context)
                ? controller.toggleDisplayChatDetailsColumn()
                : context.go('/rooms/${room.id}/details'),
      child: Row(
        children: [
          Hero(
            tag: 'content_banner',
            child: Avatar(
              mxContent: room.avatar,
              name: room.getLocalizedDisplayname(MatrixLocals(l10n)),
              toneSeed: room.id,
              isRoom: !room.isDirectChat,
              presenceUserId: room.directChatMatrixID,
              size: 40,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    if (room.allUsersVerified)
                      Icon(
                        Symbols.verified_rounded,
                        fill: 1,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                    Expanded(
                      child: Text(
                        room.getLocalizedDisplayname(MatrixLocals(l10n)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: D0b0Type.subtitle.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                StreamBuilder(
                  stream: room.client.onSyncStatus.stream,
                  builder: (context, snapshot) {
                    final status =
                        room.client.onSyncStatus.value ??
                        const SyncStatusUpdate(SyncStatus.waitingForResponse);
                    final synced =
                        room.client.onSync.value != null &&
                        status.status != SyncStatus.error &&
                        room.client.prevBatch != null;
                    if (!synced && !FluffyThemes.isColumnMode(context)) {
                      return Text(
                        status.calcLocalizedString(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: statusStyle,
                      );
                    }
                    if (room.isDirectChat) {
                      // Presence in words: Mint when online, otherwise
                      // when they were last seen.
                      return PresenceBuilder(
                        userId: room.directChatMatrixID,
                        builder: (context, presence) {
                          final lastActive = presence?.lastActiveTimestamp;
                          if (presence?.presence.isOnline == true ||
                              presence?.currentlyActive == true) {
                            return Text(
                              l10n.presenceOnline,
                              style: statusStyle.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            );
                          }
                          if (lastActive == null) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            l10n.presenceLastSeen(
                              lastActive.localizedTimeShort(context),
                            ),
                            style: statusStyle,
                          );
                        },
                      );
                    }
                    final members =
                        (room.summary.mJoinedMemberCount ?? 1) +
                        (room.summary.mInvitedMemberCount ?? 0);
                    return Text(
                      l10n.countMembers(members),
                      maxLines: 1,
                      style: statusStyle,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
