// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Behind the FAB. New chat is primary (Mint icon); group, space and invite
/// follow. The sheet drops in with the overshoot curve.
Future<void> showNewSheet(BuildContext context) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: const AnimationStyle(
      duration: D0b0Motion.move,
      curve: D0b0Motion.overshoot,
      reverseDuration: D0b0Motion.state,
      reverseCurve: D0b0Motion.exit,
    ),
    builder: (sheetContext) {
      final l10n = L10n.of(sheetContext);
      void go(String path) {
        Navigator.of(sheetContext).pop();
        router.go(path);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.newSheetTitle, style: D0b0Type.title),
            ),
            D0b0SheetRow(
              icon: Symbols.edit_rounded,
              primary: true,
              title: l10n.newChat,
              description: l10n.newChatDescription,
              onTap: () => go('/rooms/newprivatechat'),
            ),
            D0b0SheetRow(
              icon: Symbols.group_add_rounded,
              title: l10n.createGroup,
              onTap: () => go('/rooms/newgroup'),
            ),
            D0b0SheetRow(
              icon: Symbols.workspaces_rounded,
              title: l10n.createNewSpace,
              onTap: () => go('/rooms/newspace'),
            ),
            D0b0SheetRow(
              icon: Symbols.share_rounded,
              title: l10n.inviteContact,
              onTap: () {
                Navigator.of(sheetContext).pop();
                FluffyShare.shareInviteLink(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
