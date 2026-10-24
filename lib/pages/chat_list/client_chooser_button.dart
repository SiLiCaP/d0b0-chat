// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;

import 'chat_list.dart';

/// The account avatar in the chat list header. Tapping it opens the account
/// sheet, which holds everything the old hamburger menu held minus what
/// moved: creating a group lives behind the FAB, the archive at the end of
/// the list.
class ClientChooserButton extends StatelessWidget {
  final ChatListController controller;
  final double size;

  const ClientChooserButton(this.controller, {this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix.of(context);
    final client = Result(() => matrix.client).asValue?.value;
    return FutureBuilder<Profile>(
      future: client?.isLogged() == true ? client?.fetchOwnProfile() : null,
      builder: (context, snapshot) => Tooltip(
        message: L10n.of(context).accountsAndSettings,
        child: Semantics(
          button: true,
          label: L10n.of(context).accountsAndSettings,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Avatar(
                key: const Key('accounts_and_settings_buttons'),
                mxContent: snapshot.data?.avatarUrl,
                name: snapshot.data?.displayName ?? client?.userID?.localpart,
                toneSeed: client?.userID,
                presenceUserId: client?.userID,
                size: size,
                onTap: () => _showAccountSheet(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountSheet(BuildContext context) {
    final router = GoRouter.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: D0b0Motion.move,
        curve: D0b0Motion.overshoot,
        reverseDuration: D0b0Motion.state,
        reverseCurve: D0b0Motion.exit,
      ),
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();
        return _AccountSheet(
          controller: controller,
          onSetStatus: () {
            close();
            controller.setStatus();
          },
          onSettings: () {
            close();
            router.go('/rooms/settings');
          },
          onAddAccount: () {
            close();
            router.go('/rooms/settings/addaccount');
          },
          onSwitch: (client) {
            close();
            controller.setActiveClient(client);
          },
          onEditBundles: (client, bundle) {
            close();
            controller.editBundlesForAccount(client.userID, bundle);
          },
        );
      },
    );
  }
}

class _AccountSheet extends StatelessWidget {
  final ChatListController controller;
  final VoidCallback onSetStatus;
  final VoidCallback onSettings;
  final VoidCallback onAddAccount;
  final void Function(Client client) onSwitch;
  final void Function(Client client, String? bundle) onEditBundles;

  const _AccountSheet({
    required this.controller,
    required this.onSetStatus,
    required this.onSettings,
    required this.onAddAccount,
    required this.onSwitch,
    required this.onEditBundles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final matrix = Matrix.of(context);
    final active = matrix.client;
    final accounts = <(Client, String?)>[
      for (final entry in matrix.accountBundles.entries)
        for (final client in entry.value.whereType<Client>())
          if (client.isLogged()) (client, entry.key),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            FutureBuilder<Profile>(
              future: active.fetchOwnProfile(),
              builder: (context, snapshot) {
                final name =
                    snapshot.data?.displayName ??
                    active.userID?.localpart ??
                    '';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      Avatar(
                        mxContent: snapshot.data?.avatarUrl,
                        name: name,
                        toneSeed: active.userID,
                        presenceUserId: active.userID,
                        presenceBackgroundColor:
                            theme.colorScheme.surfaceContainerHigh,
                        size: 56,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: D0b0Type.title.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              active.userID ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: D0b0Type.monoStyle.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            D0b0SheetRow(
              icon: Symbols.edit_rounded,
              title: l10n.setStatus,
              onTap: onSetStatus,
            ),
            D0b0SheetRow(
              icon: Symbols.tune_rounded,
              title: l10n.settings,
              onTap: onSettings,
            ),
            if (accounts.length > 1) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              for (final (client, bundle) in accounts)
                FutureBuilder<Profile>(
                  future: client.fetchOwnProfile(),
                  builder: (context, snapshot) {
                    final name =
                        snapshot.data?.displayName ??
                        client.userID?.localpart ??
                        '';
                    final isActive = client == active;
                    return D0b0SheetRow(
                      key: ValueKey('switch_account_$name'),
                      leading: Avatar(
                        mxContent: snapshot.data?.avatarUrl,
                        name: name,
                        toneSeed: client.userID,
                        size: 40,
                      ),
                      title: name,
                      description: client.userID,
                      onTap: () => onSwitch(client),
                      trailing: isActive
                          ? Icon(
                              Symbols.check_circle_rounded,
                              fill: 1,
                              color: theme.colorScheme.primary,
                            )
                          : IconButton(
                              tooltip: l10n.editBundlesForAccount,
                              icon: const Icon(Symbols.edit_rounded),
                              onPressed: () => onEditBundles(client, bundle),
                            ),
                    );
                  },
                ),
            ],
            D0b0SheetRow(
              icon: Symbols.person_add_rounded,
              title: l10n.addAccount,
              onTap: onAddAccount,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
