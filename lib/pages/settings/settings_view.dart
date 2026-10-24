// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settings),
        leading: Center(
          child: BackButton(onPressed: () => context.go('/rooms')),
        ),
      ),
      body: ListTileTheme(
        iconColor: theme.colorScheme.onSurface,
        child: ListView(
          key: const Key('SettingsListViewContent'),
          children: <Widget>[
            FutureBuilder<Profile>(
              future: controller.profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final avatar = profile?.avatarUrl;
                final mxid =
                    Matrix.of(context).client.userID ?? L10n.of(context).user;
                final displayname =
                    profile?.displayName ?? mxid.localpart ?? mxid;
                return Column(
                  crossAxisAlignment: .center,
                  mainAxisSize: .min,
                  children: [
                    Stack(
                      children: [
                        Avatar(
                          mxContent: avatar,
                          name: displayname,
                          size: Avatar.defaultSize * 2.5,
                          onTap: avatar != null
                              ? () => showDialog(
                                  context: context,
                                  builder: (_) => MxcImageViewer(avatar),
                                )
                              : null,
                        ),
                        if (profile != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: FloatingActionButton.small(
                              elevation: 2,
                              onPressed: controller.setAvatarAction,
                              heroTag: null,
                              child: const Icon(Symbols.camera_alt_rounded),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: controller.setDisplaynameAction,
                      icon: const Icon(Symbols.edit_rounded, size: 16),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        iconColor: theme.colorScheme.onSurface,
                      ),
                      label: Text(
                        displayname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    TextButton(
                      onPressed: () => FluffyShare.share(mxid, context),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        iconColor: theme.colorScheme.secondary,
                      ),
                      child: Text(
                        mxid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            SwitchListTile.adaptive(
              controlAffinity: ListTileControlAffinity.trailing,
              value: controller.cryptoIdentityConnected == true,
              secondary: const Icon(Symbols.backup_rounded),
              title: Text(L10n.of(context).chatBackup),
              onChanged: controller.firstRunBootstrapAction,
              contentPadding: EdgeInsets.only(left: 16, right: 8),
            ),
            FutureBuilder(
              future: Result.capture(
                Matrix.of(context).client.getAuthMetadata(),
              ).then((result) => result.asValue?.value),
              builder: (context, snapshot) {
                final accountManageUrl = snapshot.data?.accountManagementUri;
                if (accountManageUrl == null) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Symbols.account_circle_rounded),
                  title: Text(L10n.of(context).manageAccount),
                  trailing: const Icon(Symbols.open_in_new_rounded),
                  onTap: () => launchUrl(
                    accountManageUrl,
                    mode: LaunchMode.inAppBrowserView,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.format_paint_rounded),
              title: Text(L10n.of(context).changeTheme),
              tileColor: activeRoute.startsWith('/rooms/settings/style')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/style'),
            ),
            ListTile(
              leading: const Icon(Symbols.notifications_rounded),
              title: Text(L10n.of(context).notifications),
              tileColor: activeRoute.startsWith('/rooms/settings/notifications')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/notifications'),
            ),
            ListTile(
              leading: const Icon(Symbols.devices_rounded),
              title: Text(L10n.of(context).devices),
              onTap: () => context.go('/rooms/settings/devices'),
              tileColor: activeRoute.startsWith('/rooms/settings/devices')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(Symbols.forum_rounded),
              title: Text(L10n.of(context).chat),
              onTap: () => context.go('/rooms/settings/chat'),
              tileColor: activeRoute.startsWith('/rooms/settings/chat')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(Symbols.shield_rounded),
              title: Text(L10n.of(context).security),
              onTap: () => context.go('/rooms/settings/security'),
              tileColor: activeRoute.startsWith('/rooms/settings/security')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(Symbols.dns_rounded),
              title: Text(
                L10n.of(context).aboutHomeserver(
                  Matrix.of(context).client.userID?.domain ?? 'homeserver',
                ),
              ),
              onTap: () => context.go('/rooms/settings/homeserver'),
              tileColor: activeRoute.startsWith('/rooms/settings/homeserver')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(Symbols.privacy_tip_rounded),
              title: Text(L10n.of(context).privacy),
              onTap: () => launchUrlString(AppSettings.privacyPolicy.value),
            ),
            ListTile(
              leading: const Icon(Symbols.info_rounded),
              title: Text(L10n.of(context).about),
              onTap: () => PlatformInfos.showDialog(context),
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(Symbols.logout_rounded),
              title: Text(L10n.of(context).logout),
              onTap: controller.logoutAction,
            ),
          ],
        ),
      ),
    );
  }
}
