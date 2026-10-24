// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/navigation_rail.dart';
import 'package:fluffychat/pages/chat_list/start_chat_fab.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/d0b0/nav_pill.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'chat_list_body.dart';

class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop:
          !controller.isSearchMode &&
          controller.activeSpaceId == null &&
          controller.homeTab == HomeTab.chats,
      onPopInvokedWithResult: (pop, _) {
        if (pop) return;
        if (controller.activeSpaceId != null) {
          controller.clearActiveSpace();
          return;
        }
        if (controller.isSearchMode) {
          controller.cancelSearch();
          return;
        }
        if (controller.homeTab != HomeTab.chats) {
          controller.setHomeTab(HomeTab.chats);
        }
      },
      child: Row(
        children: [
          // Wide windows keep the rail; on phones Spaces is a tab.
          if (isColumnMode) ...[
            Material(
              color: theme.colorScheme.surface,
              child: SpacesNavigationRail(
                activeSpaceId: controller.activeSpaceId,
                onGoToChats: controller.clearActiveSpace,
                onGoToSpaceId: controller.setActiveSpace,
              ),
            ),
            Container(width: 1, color: theme.dividerColor),
          ],
          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                extendBody: true,
                body: ChatListViewBody(controller),
                bottomNavigationBar: isColumnMode || controller.isSearchMode
                    ? null
                    : _HomeNavPill(controller),
                floatingActionButton:
                    !controller.isSearchMode &&
                        controller.activeSpaceId == null &&
                        controller.homeTab == HomeTab.chats &&
                        !isColumnMode
                    ? ValueListenableBuilder(
                        valueListenable: controller.fabExtended,
                        builder: (context, extended, _) =>
                            StartChatFab(extended: extended),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeNavPill extends StatelessWidget {
  final ChatListController controller;

  const _HomeNavPill(this.controller);

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    return StreamBuilder(
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) => D0b0NavPill(
        current: controller.homeTab,
        onSelect: controller.setHomeTab,
        spacesUnread: _anySpaceUnread(client),
      ),
    );
  }

  static bool _anySpaceUnread(Client client) {
    for (final space in client.rooms) {
      if (!space.isSpace || space.membership != Membership.join) continue;
      for (final child in space.spaceChildren) {
        final roomId = child.roomId;
        if (roomId == null) continue;
        if (client.getRoomById(roomId)?.isUnreadOrInvited ?? false) {
          return true;
        }
      }
    }
    return false;
  }
}
