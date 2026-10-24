// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/qr_code_viewer.dart';
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
    return showD0b0Sheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();
        return _AccountSheet(
          controller: controller,
          onSetStatus: () {
            close();
            controller.setStatus();
          },
          onArchive: () {
            close();
            router.go('/rooms/archive');
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
  final VoidCallback onArchive;
  final VoidCallback onSettings;
  final VoidCallback onAddAccount;
  final void Function(Client client) onSwitch;
  final void Function(Client client, String? bundle) onEditBundles;

  const _AccountSheet({
    required this.controller,
    required this.onSetStatus,
    required this.onArchive,
    required this.onSettings,
    required this.onAddAccount,
    required this.onSwitch,
    required this.onEditBundles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            // Me: who you are, your Matrix ID in mono, and your QR code.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(D0b0Radius.card),
                ),
                child: FutureBuilder<Profile>(
                  future: active.fetchOwnProfile(),
                  builder: (context, snapshot) {
                    final name =
                        snapshot.data?.displayName ??
                        active.userID?.localpart ??
                        '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                      child: Row(
                        children: [
                          Avatar(
                            mxContent: snapshot.data?.avatarUrl,
                            name: name,
                            toneSeed: active.userID,
                            presenceUserId: active.userID,
                            presenceBackgroundColor: scheme.surfaceContainer,
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
                                  style: D0b0Type.subtitle.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active.userID ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: D0b0Type.monoStyle.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.share,
                            icon: const Icon(Symbols.qr_code_rounded),
                            onPressed: () {
                              final userId = active.userID;
                              if (userId != null) {
                                showQrCodeViewer(context, userId);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onSetStatus,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  icon: const Icon(Symbols.edit_rounded, size: 18),
                  label: Text(l10n.setAStatus),
                ),
              ),
            ),
            if (accounts.length > 1)
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
                      plain: true,
                      leading: Avatar(
                        mxContent: snapshot.data?.avatarUrl,
                        name: name,
                        toneSeed: client.userID,
                        size: 32,
                      ),
                      title: name,
                      onTap: () => onSwitch(client),
                      trailing: isActive
                          ? Icon(
                              Symbols.check_circle_rounded,
                              fill: 1,
                              color: scheme.primary,
                            )
                          : IconButton(
                              tooltip: l10n.editBundlesForAccount,
                              icon: const Icon(Symbols.edit_rounded),
                              onPressed: () => onEditBundles(client, bundle),
                            ),
                    );
                  },
                ),
            D0b0SheetRow(
              plain: true,
              icon: Symbols.archive_rounded,
              title: l10n.archive,
              onTap: onArchive,
            ),
            D0b0SheetRow(
              plain: true,
              icon: Symbols.person_add_rounded,
              title: l10n.addAnotherAccount,
              onTap: onAddAccount,
            ),
            D0b0SheetRow(
              plain: true,
              icon: Symbols.settings_rounded,
              title: l10n.settings,
              onTap: onSettings,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
