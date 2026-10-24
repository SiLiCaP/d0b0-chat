// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/client_chooser_button.dart';
import 'package:fluffychat/pages/chat_list/new_sheet.dart';
import 'package:fluffychat/pages/chat_list/start_chat_fab.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/d0b0/nav_pill.dart';
import 'package:fluffychat/widgets/d0b0/nav_rail.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'chat_list_body.dart';

class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final hasRail = FluffyThemes.hasNavRail(context);
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
          // From medium windows up the rail replaces the nav pill.
          if (hasRail)
            StreamBuilder(
              stream: Matrix.of(context).client.onSync.stream
                  .where((s) => s.hasRoomUpdate)
                  .rateLimit(const Duration(seconds: 1)),
              builder: (context, _) => D0b0NavRail(
                current: controller.homeTab,
                onSelect: controller.setHomeTab,
                spacesUnread: _HomeNavPill._anySpaceUnread(
                  Matrix.of(context).client,
                ),
                onNewChat: (anchor) => showNewSheet(
                  context,
                  anchor: anchor,
                  onJoinSpace: controller.startSearch,
                ),
                account: ClientChooserButton(controller),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                extendBody: true,
                body: hasRail || controller.isSearchMode
                    ? ChatListViewBody(controller)
                    : Stack(
                        children: [
                          ChatListViewBody(controller),
                          const D0b0NavFade(),
                        ],
                      ),
                bottomNavigationBar: hasRail || controller.isSearchMode
                    ? null
                    : _HomeNavPill(controller),
                floatingActionButton:
                    !controller.isSearchMode &&
                        controller.activeSpaceId == null &&
                        controller.homeTab == HomeTab.chats &&
                        !hasRail
                    ? ValueListenableBuilder(
                        valueListenable: controller.fabExtended,
                        builder: (context, extended, _) => StartChatFab(
                          extended: extended,
                          onJoinSpace: controller.startSearch,
                        ),
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
