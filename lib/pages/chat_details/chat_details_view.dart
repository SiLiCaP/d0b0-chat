// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:async/async.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_details/chat_details.dart';
import 'package:fluffychat/pages/chat_details/participant_list_item.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/verified_room_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/chat_settings_popup_menu.dart';
import 'package:fluffychat/widgets/d0b0/settings_group.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/presence_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' hide Result;

import '../../utils/url_launcher.dart';
import '../../widgets/mxc_image_viewer.dart';
import '../../widgets/qr_code_viewer.dart';

class ChatDetailsView extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final room = Matrix.of(context).client.getRoomById(controller.roomId!);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
        ),
      );
    }

    final directChatMatrixID = room.directChatMatrixID;
    final roomAvatar = room.avatar;

    return StreamBuilder(
      stream: room.client.onRoomState.stream.where(
        (update) => update.roomId == room.id,
      ),
      builder: (context, snapshot) {
        final l10n = L10n.of(context);
        final colors = theme.d0b0;
        var members = room.getParticipants().toList()
          ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));
        members = members.take(10).toList();
        final actualMembersCount =
            (room.summary.mInvitedMemberCount ?? 0) +
            (room.summary.mJoinedMemberCount ?? 0);
        final canRequestMoreMembers = members.length < actualMembersCount;
        final displayname = room.getLocalizedDisplayname(MatrixLocals(l10n));
        final isDirect = directChatMatrixID != null;
        final canRename =
            !room.isDirectChat && room.canChangeStateEvent(EventTypes.RoomName);
        final subtitleId = directChatMatrixID ?? room.canonicalAlias;
        final inCommon = directChatMatrixID == null
            ? const <Room>[]
            : room.client.rooms
                  .where(
                    (other) =>
                        other.id != room.id &&
                        !other.isDirectChat &&
                        !other.isSpace &&
                        other.membership == Membership.join &&
                        other
                                .getState(
                                  EventTypes.RoomMember,
                                  directChatMatrixID,
                                )
                                ?.content
                                .tryGet<String>('membership') ==
                            'join',
                  )
                  .toList();

        return Scaffold(
          appBar: AppBar(
            leading:
                controller.widget.embeddedCloseButton ??
                const Center(child: BackButton()),
            actions: <Widget>[
              if (subtitleId.isNotEmpty)
                IconButton(
                  tooltip: l10n.share,
                  icon: const Icon(Symbols.qr_code_rounded),
                  onPressed: () => showQrCodeViewer(context, subtitleId),
                ),
              if (controller.widget.embeddedCloseButton == null)
                ChatSettingsPopupMenu(room, false),
              const SizedBox(width: 4),
            ],
            title: Text(l10n.chatDetails),
          ),
          body: MaxWidthBody(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                // Identity first: who this is, their Matrix ID in mono and
                // presence in words.
                const SizedBox(height: 8),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: controller.widget.embeddedCloseButton != null
                            ? 'embedded_content_banner'
                            : 'content_banner',
                        child: Avatar(
                          mxContent: room.avatar,
                          name: displayname,
                          toneSeed: room.id,
                          isRoom: !isDirect,
                          presenceUserId: directChatMatrixID,
                          size: 96,
                          onTap: roomAvatar != null
                              ? () => showDialog(
                                  context: context,
                                  builder: (_) => MxcImageViewer(roomAvatar),
                                )
                              : null,
                        ),
                      ),
                      if (!isDirect &&
                          room.canChangeStateEvent(EventTypes.RoomAvatar))
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: IconButton.filledTonal(
                            tooltip: l10n.changeAvatar,
                            onPressed: controller.setAvatarAction,
                            icon: const Icon(Symbols.photo_camera_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: InkWell(
                    onTap: canRename ? controller.setDisplaynameAction : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisSize: .min,
                        spacing: 6,
                        children: [
                          if (room.allUsersVerified)
                            Icon(
                              Symbols.verified_rounded,
                              fill: 1,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          Flexible(
                            child: Text(
                              displayname,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: D0b0Type.headline.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (canRename)
                            Icon(
                              Symbols.edit_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (subtitleId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitleId,
                      textAlign: TextAlign.center,
                      style: D0b0Type.monoStyle.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: isDirect
                        ? PresenceBuilder(
                            userId: directChatMatrixID,
                            builder: (context, presence) {
                              final lastActive = presence?.lastActiveTimestamp;
                              final online =
                                  presence?.presence.isOnline == true ||
                                  presence?.currentlyActive == true;
                              if (!online && lastActive == null) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                online
                                    ? l10n.presenceOnline
                                    : l10n.presenceLastSeen(
                                        lastActive!.localizedTimeShort(context),
                                      ),
                                style: D0b0Type.monoS.copyWith(
                                  color: online
                                      ? theme.colorScheme.primary
                                      : colors.text3,
                                ),
                              );
                            },
                          )
                        : Text(
                            l10n.countMembers(actualMembersCount),
                            style: D0b0Type.monoS.copyWith(color: colors.text3),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Three pill actions.
                StreamBuilder(
                  stream: room.client.onSync.stream.where(
                    (s) =>
                        s.accountData?.any(
                          (data) => data.type == 'm.push_rules',
                        ) ??
                        false,
                  ),
                  builder: (context, _) => Wrap(
                    alignment: .center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (room.hasPermissionForMatrixRtcCall)
                        FutureBuilder(
                          future: Result.capture(
                            room.client.getLiveKitServiceUrls(),
                          ),
                          builder: (context, snapshot) {
                            final urls = snapshot.data?.asValue?.value;
                            if (urls == null || urls.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _MainChatDetailsButton(
                              onPressed: () =>
                                  Matrix.of(context).activeCallRoomId.value =
                                      room.id,
                              label: l10n.callAction,
                              icon: Symbols.call_rounded,
                            );
                          },
                        ),
                      _MainChatDetailsButton(
                        onPressed: () => context.go('/rooms/${room.id}/search'),
                        label: l10n.search,
                        icon: Symbols.search_rounded,
                      ),
                      if (room.pushRuleState == PushRuleState.notify)
                        _MainChatDetailsButton(
                          onPressed: () => showFutureLoadingDialog(
                            context: context,
                            future: () => room.setPushRuleState(
                              PushRuleState.mentionsOnly,
                            ),
                          ),
                          label: l10n.mute,
                          icon: Symbols.notifications_rounded,
                        )
                      else
                        _MainChatDetailsButton(
                          onPressed: () => showFutureLoadingDialog(
                            context: context,
                            future: () =>
                                room.setPushRuleState(PushRuleState.notify),
                          ),
                          label: l10n.unmuteChat,
                          icon: Symbols.notifications_off_rounded,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                D0b0SectionLabel(
                  l10n.about,
                  trailing: room.canChangeStateEvent(EventTypes.RoomTopic)
                      ? IconButton(
                          onPressed: controller.setTopicAction,
                          tooltip: l10n.setChatDescription,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Symbols.edit_rounded, size: 18),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: room.topic.isEmpty
                      ? Text(
                          l10n.noDescriptionYet,
                          style: D0b0Type.bodyS.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colors.text3,
                          ),
                        )
                      : SelectableLinkify(
                          text: room.topic,
                          textScaleFactor: MediaQuery.textScalerOf(
                            context,
                          ).scale(1),
                          options: const LinkifyOptions(humanize: false),
                          linkStyle: TextStyle(
                            color: theme.colorScheme.primary,
                            decorationColor: theme.colorScheme.primary,
                          ),
                          style: D0b0Type.bodyS.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onOpen: (url) =>
                              UrlLauncher(context, url.url).launchUrl(),
                        ),
                ),
                D0b0SectionLabel(l10n.chatSection),
                D0b0SettingsGroup(
                  children: [
                    D0b0SettingsTile(
                      icon: Symbols.notifications_rounded,
                      title: l10n.notifications,
                      subtitle: switch (room.pushRuleState) {
                        PushRuleState.notify => l10n.notificationsAll,
                        PushRuleState.mentionsOnly =>
                          l10n.notificationsMentions,
                        PushRuleState.dontNotify => l10n.notificationsMuted,
                      },
                      onTap: () => _pickNotifications(context, room),
                    ),
                    D0b0SettingsTile(
                      icon: Symbols.image_rounded,
                      title: l10n.sharedMedia,
                      chevron: true,
                      onTap: () => context.go('/rooms/${room.id}/search'),
                    ),
                    D0b0SettingsTile(
                      icon: room.encrypted
                          ? Symbols.lock_rounded
                          : Symbols.lock_open_rounded,
                      title: l10n.encryption,
                      subtitle: !room.encrypted
                          ? l10n.encryptionOff
                          : room.allUsersVerified
                          ? l10n.encryptionOnVerified
                          : l10n.encryptionOn,
                      chevron: true,
                      onTap: () => context.go('/rooms/${room.id}/encryption'),
                    ),
                    if (room.pinnedEventIds.isNotEmpty)
                      D0b0SettingsTile(
                        icon: Symbols.keep_rounded,
                        title: l10n.pinnedMessages,
                        chevron: true,
                        onTap: () => context.go('/rooms/${room.id}'),
                      ),
                    D0b0SettingsTile(
                      icon: Symbols.add_reaction_rounded,
                      title: l10n.emojiAndStickerPacks,
                      chevron: true,
                      onTap: () =>
                          context.push('/rooms/${room.id}/details/emotes'),
                    ),
                  ],
                ),
                if (!isDirect) ...[
                  D0b0SectionLabel(l10n.roomAdmin),
                  D0b0SettingsGroup(
                    children: [
                      D0b0SettingsTile(
                        icon: Symbols.admin_panel_settings_rounded,
                        title: l10n.accessAndVisibility,
                        subtitle: l10n.accessAndVisibilityDescription,
                        chevron: true,
                        onTap: () =>
                            context.push('/rooms/${room.id}/details/access'),
                      ),
                      D0b0SettingsTile(
                        icon: Symbols.tune_rounded,
                        title: l10n.chatPermissions,
                        subtitle: l10n.whoCanPerformWhichAction,
                        chevron: true,
                        onTap: () => context.push(
                          '/rooms/${room.id}/details/permissions',
                        ),
                      ),
                    ],
                  ),
                  D0b0SectionLabel(
                    l10n.countMembers(actualMembersCount),
                    trailing: room.canInvite
                        ? TextButton.icon(
                            icon: const Icon(Symbols.person_add_rounded),
                            label: Text(l10n.invite),
                            onPressed: () =>
                                context.go('/rooms/${room.id}/invite'),
                          )
                        : null,
                  ),
                  D0b0SettingsGroup(
                    children: [
                      for (final member in members) ParticipantListItem(member),
                      if (canRequestMoreMembers)
                        D0b0SettingsTile(
                          icon: Symbols.group_rounded,
                          title: l10n.loadCountMoreParticipants(
                            actualMembersCount - members.length,
                          ),
                          chevron: true,
                          onTap: () => context.push(
                            '/rooms/${controller.roomId!}/details/members',
                          ),
                        ),
                    ],
                  ),
                ],
                if (inCommon.isNotEmpty) ...[
                  D0b0SectionLabel(l10n.inCommon),
                  D0b0SettingsGroup(
                    children: [
                      for (final other in inCommon)
                        D0b0SettingsTile(
                          title: other.getLocalizedDisplayname(
                            MatrixLocals(l10n),
                          ),
                          chevron: true,
                          onTap: () => context.go('/rooms/${other.id}'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Destructive rows sit alone at the bottom.
                D0b0SettingsGroup(
                  children: [
                    if (directChatMatrixID != null)
                      D0b0SettingsTile(
                        icon: Symbols.block_rounded,
                        title: l10n.blockUserName(displayname),
                        destructive: true,
                        onTap: () => context.go(
                          '/rooms/settings/security/ignorelist',
                          extra: directChatMatrixID,
                        ),
                      ),
                    D0b0SettingsTile(
                      icon: Symbols.logout_rounded,
                      title: l10n.leaveChat,
                      destructive: true,
                      onTap: () => _leave(context, room),
                    ),
                  ],
                ),
                SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickNotifications(BuildContext context, Room room) async {
    final l10n = L10n.of(context);
    final state = await showModalActionPopup<PushRuleState>(
      context: context,
      title: l10n.notifications,
      cancelLabel: l10n.cancel,
      actions: [
        AdaptiveModalAction(
          value: PushRuleState.notify,
          label: l10n.notificationsAll,
        ),
        AdaptiveModalAction(
          value: PushRuleState.mentionsOnly,
          label: l10n.notificationsMentions,
        ),
        AdaptiveModalAction(
          value: PushRuleState.dontNotify,
          label: l10n.notificationsMuted,
        ),
      ],
    );
    if (state == null || !context.mounted) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => room.setPushRuleState(state),
    );
  }

  Future<void> _leave(BuildContext context, Room room) async {
    final l10n = L10n.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showOkCancelAlertDialog(
      context: context,
      title: l10n.areYouSure,
      message: l10n.archiveRoomDescription,
      okLabel: l10n.leave,
      cancelLabel: l10n.cancel,
      isDestructive: true,
    );
    if (confirmed != OkCancelResult.ok || !context.mounted) return;
    final result = await showFutureLoadingDialog(
      context: context,
      future: room.leave,
    );
    if (result.error == null) router.go('/rooms');
  }
}

/// A tonal pill action under the identity: icon and label, 48 high.
class _MainChatDetailsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _MainChatDetailsButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        padding: const EdgeInsets.only(left: 16, right: 20),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
