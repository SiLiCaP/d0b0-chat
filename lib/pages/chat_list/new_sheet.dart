// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Behind the FAB. New chat is primary (Mint icon); group, space and invite
/// follow. The sheet drops in with the overshoot curve.
///
/// [onJoinSpace] opens the search, where spaces can be browsed or a link
/// pasted.
Future<void> showNewSheet(BuildContext context, {VoidCallback? onJoinSpace}) {
  final router = GoRouter.of(context);
  return showD0b0Sheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = L10n.of(sheetContext);
      final scheme = Theme.of(sheetContext).colorScheme;
      void close() => Navigator.of(sheetContext).pop();
      return SafeArea(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                l10n.newSheetTitle,
                style: D0b0Type.title.copyWith(color: scheme.onSurface),
              ),
            ),
            D0b0SheetRow(
              icon: Symbols.chat_bubble_rounded,
              primary: true,
              title: l10n.newChat,
              description: l10n.newChatDescription,
              onTap: () {
                close();
                router.go('/rooms/newprivatechat');
              },
            ),
            D0b0SheetRow(
              icon: Symbols.group_rounded,
              title: l10n.newGroupTitle,
              description: l10n.newGroupDescription,
              onTap: () {
                close();
                router.go('/rooms/newgroup');
              },
            ),
            if (onJoinSpace != null)
              D0b0SheetRow(
                icon: Symbols.workspaces_rounded,
                title: l10n.joinASpace,
                description: l10n.joinSpaceDescription,
                onTap: () {
                  close();
                  onJoinSpace();
                },
              ),
            D0b0SheetRow(
              icon: Symbols.share_rounded,
              title: l10n.inviteFriend,
              description: l10n.inviteFriendDescription,
              onTap: () {
                close();
                FluffyShare.shareInviteLink(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
