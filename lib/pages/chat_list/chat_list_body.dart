// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item.dart';
import 'package:fluffychat/pages/chat_list/dummy_chat_list_item.dart';
import 'package:fluffychat/pages/chat_list/space_view.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/public_room_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:fluffychat/widgets/d0b0/nav_pill.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../widgets/adaptive_dialogs/user_dialog.dart';
import '../../widgets/matrix.dart';
import 'chat_list_header.dart';

class ChatListViewBody extends StatelessWidget {
  final ChatListController controller;

  const ChatListViewBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final activeSpace = controller.activeSpaceId;
    if (activeSpace != null) {
      return SpaceView(
        key: ValueKey(activeSpace),
        spaceId: activeSpace,
        onBack: controller.clearActiveSpace,
        onChatTab: controller.onChatTap,
        activeChat: controller.activeChat,
      );
    }
    final spaces = client.rooms.where((r) => r.isSpace);
    final spaceDelegateCandidates = <String, Room>{};
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    final publicRooms = controller.roomSearchResult?.chunk
        .where((room) => room.roomType != 'm.space')
        .toList();
    final publicSpaces = controller.roomSearchResult?.chunk
        .where((room) => room.roomType == 'm.space')
        .toList();
    final userSearchResult = controller.userSearchResult;
    const dummyChatCount = 4;
    final filter = controller.searchController.text.toLowerCase();
    return StreamBuilder(
      key: ValueKey(client.userID.toString()),
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        final spacesTab = controller.homeTab == HomeTab.spaces;
        final rooms = spacesTab
            ? client.rooms
                  .where((room) => room.isSpace && room.membership == .join)
                  .toList()
            : controller.filteredRooms
                  .where(
                    (room) =>
                        !room.isSpace &&
                        (!AppSettings.hideRoomsInSpaces.value ||
                            spaceDelegateCandidates[room.id] == null),
                  )
                  .toList();
        final l10n = L10n.of(context);
        final showArchive =
            !spacesTab &&
            !controller.isSearchMode &&
            controller.activeFilter == ActiveFilter.allChats &&
            client.prevBatch != null;

        return CustomScrollView(
          controller: controller.scrollController,
          slivers: [
            if (!controller.isSearchMode)
              ChatListTitle(
                controller: controller,
                title: spacesTab ? l10n.navSpaces : l10n.navChats,
              ),
            ChatListHeader(controller: controller),
            SliverList(
              delegate: SliverChildListDelegate([
                // Search results are grouped: people first, then rooms.
                if (controller.isSearchMode &&
                    userSearchResult != null &&
                    userSearchResult.results.isNotEmpty) ...[
                  _SearchSection(l10n.people),
                  for (final profile in userSearchResult.results)
                    _SearchResultRow(
                      avatar: profile.avatarUrl,
                      name:
                          profile.displayName ??
                          profile.userId.localpart ??
                          profile.userId,
                      id: profile.userId,
                      toneSeed: profile.userId,
                      onTap: () =>
                          UserDialog.show(context: context, profile: profile),
                    ),
                ],
                if (client.rooms.isNotEmpty &&
                    !controller.isSearchMode &&
                    !spacesTab)
                  SizedBox(
                    height: 36 + 16,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final filter in ActiveFilter.values.where(
                          (filter) => filter != ActiveFilter.tag,
                        ))
                          _FilterChip(
                            label: filter.toLocalizedString(context),
                            selected: filter == controller.activeFilter,
                            onSelected: () =>
                                controller.setActiveFilter(filter, null),
                          ),
                        for (final entry in controller.roomTags.entries)
                          _FilterChip(
                            label: entry.key.replaceFirst('u.', ''),
                            selected: entry.key == controller.activeTag,
                            onSelected: () => controller.setActiveFilter(
                              ActiveFilter.tag,
                              entry.key,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (controller.isSearchMode && rooms.isNotEmpty)
                  _SearchSection(l10n.chats),
                if (client.prevBatch != null &&
                    rooms.isEmpty &&
                    !controller.isSearchMode)
                  _EmptyChats(
                    firstRun: client.rooms.isEmpty && !spacesTab,
                    spaces: spacesTab,
                    message: spacesTab
                        ? l10n.emptySpacesTitle
                        : l10n.noMoreChatsFound,
                  ),
              ]),
            ),
            if (client.prevBatch == null)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => DummyChatListItem(
                    opacity: (dummyChatCount - i) / dummyChatCount,
                    animate: true,
                  ),
                  childCount: dummyChatCount,
                ),
              ),
            if (client.prevBatch != null)
              SliverSafeArea(
                top: false,
                sliver: SliverList.builder(
                  itemCount: rooms.length + (showArchive ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (i == rooms.length) return const _ArchiveRow();
                    final room = rooms[i];
                    final space = spaceDelegateCandidates[room.id];
                    final item = ChatListItem(
                      room,
                      space: space,
                      key: Key('chat_list_item_${room.id}'),
                      filter: filter,
                      onTap: () => controller.onChatTap(room),
                      onLongPress: (context) =>
                          controller.chatContextAction(room, context, space),
                      activeChat: controller.activeChat == room.id,
                    );
                    if (spacesTab || controller.isSearchMode) return item;
                    return _SwipeActions(
                      key: ValueKey('swipe_${room.id}'),
                      room: room,
                      controller: controller,
                      child: item,
                    );
                  },
                ),
              ),
            if (controller.isSearchMode)
              SliverSafeArea(
                top: false,
                sliver: SliverList.list(
                  children: [
                    for (final (title, chunks) in [
                      (l10n.publicRooms, publicRooms),
                      (l10n.publicSpaces, publicSpaces),
                    ])
                      if (chunks != null && chunks.isNotEmpty) ...[
                        _SearchSection(title),
                        for (final chunk in chunks)
                          _SearchResultRow(
                            avatar: chunk.avatarUrl,
                            name:
                                chunk.name ??
                                chunk.canonicalAlias?.localpart ??
                                l10n.group,
                            id: chunk.canonicalAlias ?? chunk.roomId,
                            toneSeed: chunk.roomId,
                            isRoom: true,
                            onTap: () => showAdaptiveDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (c) => PublicRoomDialog(
                                roomAlias: chunk.canonicalAlias ?? chunk.roomId,
                                chunk: chunk,
                              ),
                            ),
                          ),
                      ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Section label in search results.
class _SearchSection extends StatelessWidget {
  final String title;

  const _SearchSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title.toUpperCase(),
      style: D0b0Type.overline.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A person or public room in search results; Matrix IDs are mono.
class _SearchResultRow extends StatelessWidget {
  final Uri? avatar;
  final String name;
  final String id;
  final String toneSeed;
  final bool isRoom;
  final VoidCallback onTap;

  const _SearchResultRow({
    required this.avatar,
    required this.name,
    required this.id,
    required this.toneSeed,
    required this.onTap,
    this.isRoom = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      hoverColor: scheme.surfaceContainer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ChatListItem.minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Avatar(
                mxContent: avatar,
                name: name,
                toneSeed: toneSeed,
                isRoom: isRoom,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.subtitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.monoStyle.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-select filter. Selected = Mint fill; others = 2 px outline,
/// label text-2.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: scheme.outline, width: 2),
        ),
        child: InkWell(
          onTap: onSelected,
          customBorder: const StadiumBorder(),
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: D0b0Type.label.copyWith(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right: mark read / unread. Left: archive.
class _SwipeActions extends StatelessWidget {
  final Room room;
  final ChatListController controller;
  final Widget child;

  const _SwipeActions({
    required this.room,
    required this.controller,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);
    Widget background(IconData icon, String label, Alignment alignment) =>
        Container(
          color: scheme.surfaceContainerHigh,
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: .min,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: D0b0Type.label.copyWith(color: scheme.primary),
              ),
            ],
          ),
        );
    final unread = room.isUnreadOrInvited;
    return Dismissible(
      key: ValueKey('dismissible_${room.id}'),
      background: background(
        unread
            ? Symbols.mark_chat_read_rounded
            : Symbols.mark_chat_unread_rounded,
        unread ? l10n.markAsRead : l10n.markAsUnread,
        Alignment.centerLeft,
      ),
      secondaryBackground: background(
        Symbols.archive_rounded,
        l10n.archive,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.lightImpact();
        if (direction == DismissDirection.startToEnd) {
          await controller.toggleRead(room);
        } else {
          await controller.archiveRoom(room);
        }
        // The row stays; the room updates or disappears through sync.
        return false;
      },
      child: child,
    );
  }
}

/// Archived rooms live behind 'Archive' at the end of the list.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.go('/rooms/archive'),
      hoverColor: scheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: Avatar.defaultSize,
                child: Icon(
                  Symbols.archive_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                L10n.of(context).archive,
                style: D0b0Type.body.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First run: the mark itself is the illustration, drawn d and Mint b.
/// Two actions, one filled.
class _EmptyChats extends StatelessWidget {
  final bool firstRun;
  final bool spaces;
  final String? message;

  const _EmptyChats({
    required this.firstRun,
    this.spaces = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        mainAxisSize: .min,
        children: [
          D0b0Mark(height: 104, dColor: scheme.outline, color: scheme.primary),
          const SizedBox(height: 32),
          Text(
            firstRun ? l10n.emptyChatsTitle : message ?? '',
            textAlign: TextAlign.center,
            style: D0b0Type.headline.copyWith(color: scheme.onSurface),
          ),
          if (spaces) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => context.go('/rooms/newspace'),
              icon: const Icon(Symbols.workspaces_rounded),
              label: Text(l10n.createNewSpace),
            ),
          ],
          if (firstRun) ...[
            const SizedBox(height: 8),
            Text(
              l10n.emptyChatsBody,
              textAlign: TextAlign.center,
              style: D0b0Type.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/rooms/newprivatechat'),
              icon: const Icon(Symbols.edit_rounded),
              label: Text(l10n.newChat),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => FluffyShare.shareInviteLink(context),
              icon: const Icon(Symbols.share_rounded),
              label: Text(l10n.inviteContact),
            ),
          ],
        ],
      ),
    );
  }
}
