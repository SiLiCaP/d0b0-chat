// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/nav_pill.dart';
import 'package:fluffychat/widgets/d0b0/nav_rail.dart';
import 'package:fluffychat/widgets/d0b0/settings_group.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/theme_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/mxc_image_viewer.dart';
import 'settings.dart';

class SettingsView extends StatelessWidget {
  final SettingsController controller;

  const SettingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeRoute = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;

    // On phones settings is the 'You' tab: a screen title instead of an app
    // bar, the nav pill instead of a back button.
    final hasRail = FluffyThemes.hasNavRail(context);
    final isTab = !hasRail;
    final l10n = L10n.of(context);
    final client = Matrix.of(context).client;
    final userId = client.userID;
    final ownDevices = userId == null
        ? null
        : client.userDeviceKeys[userId]?.deviceKeys.values;
    final unverified =
        ownDevices?.where((device) => !device.verified).length ?? 0;
    final themeMode = ThemeController.of(context).themeMode;
    bool isActive(String path) => activeRoute.startsWith(path);

    void onSelectTab(HomeTab tab) => switch (tab) {
      HomeTab.chats => context.go('/rooms'),
      HomeTab.spaces => context.go('/rooms?tab=spaces'),
      HomeTab.you => null,
    };

    return Scaffold(
      extendBody: isTab,
      bottomNavigationBar: isTab
          ? D0b0NavPill(current: HomeTab.you, onSelect: onSelectTab)
          : null,
      body: Row(
        children: [
          if (hasRail)
            D0b0NavRail(
              current: HomeTab.you,
              onSelect: onSelectTab,
              account: Avatar(
                name: userId?.localpart,
                toneSeed: userId,
                presenceUserId: userId,
                size: 40,
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  key: const Key('SettingsListViewContent'),
                  padding: EdgeInsets.only(
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: <Widget>[
                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 64,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.navYou,
                              style: D0b0Type.display.copyWith(
                                fontSize: 30,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Profile>(
                      future: controller.profileFuture,
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        final avatar = profile?.avatarUrl;
                        final mxid = userId ?? l10n.user;
                        final displayname =
                            profile?.displayName ?? mxid.localpart ?? mxid;
                        return _MeCard(
                          avatar: avatar,
                          name: displayname,
                          userId: mxid,
                          onAvatarTap: controller.setAvatarAction,
                          onEdit: (anchor) => _editProfile(context, anchor),
                        );
                      },
                    ),
                    D0b0SectionLabel(l10n.account),
                    D0b0SettingsGroup(
                      children: [
                        D0b0SwitchTile(
                          icon: Symbols.cloud_sync_rounded,
                          title: l10n.chatBackup,
                          subtitle: controller.cryptoIdentityConnected == true
                              ? l10n.keysBackedUp
                              : l10n.backupNotSetUp,
                          value: controller.cryptoIdentityConnected == true,
                          onChanged: controller.firstRunBootstrapAction,
                        ),
                        D0b0SettingsTile(
                          icon: Symbols.devices_rounded,
                          title: l10n.devices,
                          subtitle: ownDevices == null
                              ? null
                              : [
                                  l10n.countSessions(ownDevices.length),
                                  if (unverified > 0)
                                    l10n.countUnverified(unverified),
                                ].join(' · '),
                          chevron: true,
                          selected: isActive('/rooms/settings/devices'),
                          onTap: () => context.go('/rooms/settings/devices'),
                        ),
                        D0b0SettingsTile(
                          icon: Symbols.shield_rounded,
                          title: l10n.security,
                          chevron: true,
                          selected: isActive('/rooms/settings/security'),
                          onTap: () => context.go('/rooms/settings/security'),
                        ),
                        FutureBuilder(
                          future: Result.capture(
                            client.getAuthMetadata(),
                          ).then((result) => result.asValue?.value),
                          builder: (context, snapshot) {
                            final accountManageUrl =
                                snapshot.data?.accountManagementUri;
                            if (accountManageUrl == null) {
                              return const SizedBox.shrink();
                            }
                            return D0b0SettingsTile(
                              icon: Symbols.account_circle_rounded,
                              title: l10n.manageAccount,
                              trailing: Icon(
                                Symbols.open_in_new_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onTap: () => launchUrl(
                                accountManageUrl,
                                mode: LaunchMode.inAppBrowserView,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    D0b0SectionLabel(l10n.preferences),
                    D0b0SettingsGroup(
                      children: [
                        D0b0SettingsTile(
                          icon: Symbols.palette_rounded,
                          title: l10n.appearance,
                          subtitle: switch (themeMode) {
                            ThemeMode.light => l10n.lightTheme,
                            ThemeMode.dark => l10n.darkTheme,
                            ThemeMode.system => l10n.systemTheme,
                          },
                          chevron: true,
                          selected: isActive('/rooms/settings/style'),
                          onTap: () => context.go('/rooms/settings/style'),
                        ),
                        D0b0SettingsTile(
                          icon: Symbols.notifications_rounded,
                          title: l10n.notifications,
                          chevron: true,
                          selected: isActive('/rooms/settings/notifications'),
                          onTap: () =>
                              context.go('/rooms/settings/notifications'),
                        ),
                        D0b0SettingsTile(
                          icon: Symbols.chat_bubble_rounded,
                          title: l10n.chat,
                          chevron: true,
                          selected: isActive('/rooms/settings/chat'),
                          onTap: () => context.go('/rooms/settings/chat'),
                        ),
                      ],
                    ),
                    D0b0SectionLabel(userId?.domain ?? l10n.aboutTheServer),
                    D0b0SettingsGroup(
                      children: [
                        D0b0SettingsTile(
                          icon: Symbols.dns_rounded,
                          title: l10n.aboutTheServer,
                          chevron: true,
                          selected: isActive('/rooms/settings/homeserver'),
                          onTap: () => context.go('/rooms/settings/homeserver'),
                        ),
                        D0b0SettingsTile(
                          icon: Symbols.info_rounded,
                          title: l10n.privacyAndAbout,
                          chevron: true,
                          onTap: () => PlatformInfos.showDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Destructive rows sit alone at the bottom.
                    D0b0SettingsGroup(
                      children: [
                        D0b0SettingsTile(
                          icon: Symbols.logout_rounded,
                          title: l10n.logout,
                          destructive: true,
                          onTap: controller.logoutAction,
                        ),
                      ],
                    ),
                  ],
                ),
                if (isTab) const D0b0NavFade(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, Rect? anchor) async {
    final l10n = L10n.of(context);
    final action = await showD0b0Sheet<int>(
      context: context,
      anchor: anchor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Text(l10n.editProfile, style: D0b0Type.title),
            ),
            D0b0SheetRow(
              plain: true,
              icon: Symbols.badge_rounded,
              title: l10n.changeDisplayname,
              onTap: () => Navigator.of(context).pop(0),
            ),
            D0b0SheetRow(
              plain: true,
              icon: Symbols.add_a_photo_rounded,
              title: l10n.changeAvatar,
              onTap: () => Navigator.of(context).pop(1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (action) {
      case 0:
        await controller.setDisplaynameAction();
      case 1:
        await controller.setAvatarAction();
    }
  }
}

/// Profile card on top: a 64 avatar, the name, the Matrix ID in mono and
/// an edit button.
class _MeCard extends StatelessWidget {
  final Uri? avatar;
  final String name;
  final String userId;
  final VoidCallback onAvatarTap;

  /// Opens the edit sheet, anchored to the edit button.
  final void Function(Rect? anchor) onEdit;

  const _MeCard({
    required this.avatar,
    required this.name,
    required this.userId,
    required this.onAvatarTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = this.avatar;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D0b0Radius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Row(
            children: [
              Avatar(
                mxContent: avatar,
                name: name,
                toneSeed: userId,
                presenceUserId: userId,
                presenceBackgroundColor: scheme.surfaceContainer,
                size: 64,
                onTap: avatar != null
                    ? () => showDialog(
                        context: context,
                        builder: (_) => MxcImageViewer(avatar),
                      )
                    : onAvatarTap,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => FluffyShare.share(userId, context),
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
                        userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: D0b0Type.monoStyle.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Builder(
                builder: (context) => IconButton(
                  tooltip: L10n.of(context).editProfile,
                  icon: const Icon(Symbols.edit_rounded),
                  onPressed: () => onEdit(d0b0AnchorOf(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
