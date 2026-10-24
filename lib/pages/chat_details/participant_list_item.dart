// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/member_actions_popup_menu_button.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../widgets/avatar.dart';

class ParticipantListItem extends StatelessWidget {
  final User user;

  const ParticipantListItem(this.user, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final membershipBatch = switch (user.membership) {
      Membership.ban => L10n.of(context).banned,
      Membership.invite => L10n.of(context).invited,
      Membership.join => null,
      Membership.knock => L10n.of(context).knocking,
      Membership.leave => L10n.of(context).leftTheChat,
    };

    final permissionBatch = switch (user.powerLevel.role) {
      PowerLevelRole.user => null,
      PowerLevelRole.moderator => L10n.of(context).moderator,
      PowerLevelRole.admin => L10n.of(context).admin,
      PowerLevelRole.owner => L10n.of(context).owner,
    };

    // Roles and membership are outline pills in text-2.
    Widget pill(String label) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
        ),
      ),
      child: Text(
        label,
        style: D0b0Type.label.copyWith(
          fontSize: 12,
          letterSpacing: 0,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => showMemberActionsPopupMenu(context: context, user: user),
      title: Row(
        children: <Widget>[
          if (user.room.client.userDeviceKeys[user.id]?.masterKey?.verified ==
              true)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Icon(
                Symbols.verified_rounded,
                fill: 1,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
          Expanded(
            child: Text(
              user.calcDisplayname(),
              overflow: TextOverflow.ellipsis,
              style: D0b0Type.body.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          ?permissionBatch == null ? null : pill(permissionBatch),
          ?membershipBatch == null ? null : pill(membershipBatch),
        ],
      ),
      subtitle: Text(
        user.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: D0b0Type.monoS.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      leading: Opacity(
        opacity: user.membership == Membership.join ? 1 : 0.5,
        child: Avatar(
          mxContent: user.avatarUrl,
          name: user.calcDisplayname(),
          toneSeed: user.id,
          size: 40,
          presenceUserId: user.stateKey,
          presenceBackgroundColor: theme.colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}
