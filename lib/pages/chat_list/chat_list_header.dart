// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/client_chooser_button.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/sync_status_localization.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../widgets/matrix.dart';

/// Screen title row: the mark and 'Chats' in display, the account avatar on
/// the right. Scrolls away with the list.
class ChatListTitle extends StatelessWidget {
  final ChatListController controller;
  final String title;

  /// The mark only leads the Chats title.
  final bool showMark;

  /// Replaces the account avatar on the right.
  final Widget? trailing;

  const ChatListTitle({
    required this.controller,
    required this.title,
    this.showMark = true,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                if (showMark && !FluffyThemes.hasNavRail(context)) ...[
                  D0b0Mark(height: 26, color: theme.colorScheme.primary),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: D0b0Type.display.copyWith(
                      fontSize: FluffyThemes.hasNavRail(context) ? 28 : 30,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                trailing ??
                    (FluffyThemes.hasNavRail(context)
                        ? const SizedBox.shrink()
                        : ClientChooserButton(controller)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The search pill. Floats back in when the list scrolls up; tapping it
/// opens the full-screen search in place.
class ChatListHeader extends StatelessWidget implements PreferredSizeWidget {
  final ChatListController controller;
  final bool globalSearch;

  const ChatListHeader({
    super.key,
    required this.controller,
    this.globalSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = Matrix.of(context).client;
    final l10n = L10n.of(context);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return SliverAppBar(
      floating: true,
      pinned: isColumnMode || controller.isSearchMode,
      toolbarHeight: 64,
      titleSpacing: controller.isSearchMode ? 0 : 16,
      leadingWidth: 56,
      leading: controller.isSearchMode
          ? Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Symbols.arrow_back_rounded),
                onPressed: controller.cancelSearch,
              ),
            )
          : null,
      primary: controller.isSearchMode,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.surface,
      automaticallyImplyLeading: false,
      actions: controller.isSearchMode ? const [SizedBox(width: 12)] : null,
      title: StreamBuilder(
        stream: client.onSyncStatus.stream,
        builder: (context, snapshot) {
          final status =
              client.onSyncStatus.value ??
              const SyncStatusUpdate(SyncStatus.waitingForResponse);
          final synced =
              client.onSync.value != null &&
              status.status != SyncStatus.error &&
              client.prevBatch != null;
          return SizedBox(
            height: 48,
            child: TextField(
              controller: controller.searchController,
              focusNode: controller.searchFocusNode,
              textInputAction: TextInputAction.search,
              onTap: controller.isSearchMode ? null : controller.startSearch,
              onChanged: (text) =>
                  controller.onSearchEnter(text, globalSearch: globalSearch),
              style: D0b0Type.body.copyWith(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                fillColor: theme.colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                hintText: !synced
                    ? status.calcLocalizedString(context)
                    : PlatformInfos.isMobile
                    ? l10n.searchRoomsAndPeople
                    : l10n.searchShortcutHint,
                hintStyle: D0b0Type.body.copyWith(color: iconColor),
                prefixIcon: !synced
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: status.progress,
                          ),
                        ),
                      )
                    : controller.isSearchMode
                    ? null
                    : Icon(Symbols.search_rounded, size: 20, color: iconColor),
                suffixIcon: controller.isSearchMode
                    ? controller.isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: l10n.clear,
                              icon: const Icon(Symbols.close_rounded),
                              color: iconColor,
                              onPressed: () {
                                controller.searchController.clear();
                                controller.onSearchEnter(
                                  '',
                                  globalSearch: globalSearch,
                                );
                                controller.startSearch();
                              },
                            )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
