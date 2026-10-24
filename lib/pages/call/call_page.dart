// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/call/call_tile.dart';
import 'package:fluffychat/pages/call/call_view_model.dart';
import 'package:fluffychat/pages/call/start_time.dart';
import 'package:fluffychat/pages/call/utils/get_call_tiles.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/glass.dart';
import 'package:fluffychat/widgets/d0b0/syncing_bowls.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/view_model_builder.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' as sdk show Room;
import 'package:matrix/matrix.dart' hide Room;

/// Calls sit over footage, so controls are glass or tonal pills. Joining is
/// Mint, leaving is Coral, and nothing else is red. A muted mic or camera
/// turns into a light filled button so it can't be missed.
class CallPage extends StatelessWidget {
  final String roomId;
  const CallPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId)!;
    final mini = Matrix.of(context).callPosition.value != .fullScreen;
    final tileSize = FluffyThemes.isColumnMode(context) ? 256.0 : 128.0;
    return ViewModelBuilder(
      create: () => CallViewModel(room: room),
      builder: (context, viewModel, _) {
        final liveKitRoom = viewModel.value.room;
        final localVideoTrack = viewModel.value.localVideoTrack;
        final localParticipant = liveKitRoom?.localParticipant;
        final error = viewModel.value.error;

        final activeMembers = room.getActiveMatrixRtcMembers().length;
        final ownUser = room.unsafeGetUserFromMemoryOrFallback(
          room.client.userID!,
        );
        final ownHandRaised = viewModel.participantRaisedHand(ownUser.id);
        final userIsScreensharing =
            localParticipant?.isScreenShareEnabled() == true;
        final inCall = localParticipant != null;
        final startTime = viewModel.startTime;

        if (mini) {
          return _MiniCall(room: room, viewModel: viewModel, ownUser: ownUser);
        }

        final statusStyle = D0b0Type.monoS.copyWith(
          color: inCall ? theme.colorScheme.primary : theme.d0b0.text3,
        );

        final List<Widget> controls;
        if (inCall) {
          final micOn = localParticipant.isMicrophoneEnabled();
          final cameraOn = localParticipant.isCameraEnabled();
          controls = [
            _CallButton(
              tooltip: l10n.toggleMicrophone,
              icon: micOn ? Symbols.mic_rounded : Symbols.mic_off_rounded,
              attention: !micOn,
              onPressed: () => localParticipant.setMicrophoneEnabled(!micOn),
            ),
            _CallButton(
              tooltip: l10n.toggleCamera,
              icon: cameraOn
                  ? Symbols.videocam_rounded
                  : Symbols.videocam_off_rounded,
              attention: !cameraOn,
              onPressed: () => localParticipant.setCameraEnabled(!cameraOn),
            ),
            if (!PlatformInfos.isMobile) // TODO: Fix on mobile?
              _CallButton(
                tooltip: userIsScreensharing
                    ? l10n.stopScreensharing
                    : l10n.startScreensharing,
                icon: userIsScreensharing
                    ? Symbols.stop_screen_share_rounded
                    : Symbols.screen_share_rounded,
                attention: userIsScreensharing,
                onPressed: () => localParticipant.setScreenShareEnabled(
                  !userIsScreensharing,
                ),
              ),
            _CallButton(
              tooltip: ownHandRaised ? l10n.stopRaiseHand : l10n.raiseHand,
              icon: Symbols.front_hand_rounded,
              attention: ownHandRaised,
              onPressed: () => showFutureLoadingDialog(
                context: context,
                future: () => ownHandRaised
                    ? room.lowerHandInMatrixRtcCall(viewModel.timeline!)
                    : room.raiseHandInMatrixRtcCall(),
              ),
            ),
            _HangUpButton(onPressed: () => viewModel.close(context)),
          ];
        } else {
          controls = const [];
        }

        return ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 64,
              leadingWidth: 56,
              leading: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  tooltip: inCall ? l10n.minimizeCall : l10n.close,
                  icon: Icon(
                    inCall
                        ? Symbols.close_fullscreen_rounded
                        : Symbols.arrow_back_rounded,
                  ),
                  onPressed: inCall
                      ? () => Matrix.of(context).callPosition.value = .top
                      : () => viewModel.close(context),
                ),
              ),
              titleSpacing: 4,
              title: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          room.getLocalizedDisplayname(),
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: D0b0Type.subtitle.copyWith(
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      _BetaTag(onTap: () => _showBetaInfo(context)),
                    ],
                  ),
                  if (inCall && startTime != null)
                    StartTime(
                      startTime: startTime,
                      style: statusStyle,
                      label: (elapsed) =>
                          l10n.countInCall(max(activeMembers, 1), elapsed),
                    )
                  else
                    Text(
                      viewModel.waitForOtherSide
                          ? l10n.waitingForParticipant
                          : l10n.countPeopleInCall(activeMembers),
                      maxLines: 1,
                      style: statusStyle,
                    ),
                ],
              ),
              actions: [
                if (!inCall)
                  PopupMenuButton(
                    icon: const Icon(Symbols.more_vert_rounded),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () => viewModel.selectCamera(context),
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 12,
                          children: [
                            const Icon(Symbols.camera_rounded),
                            Text(l10n.selectCamera),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => viewModel.selectMicrophone(context),
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 12,
                          children: [
                            const Icon(Symbols.mic_rounded),
                            Text(l10n.selectMicrophone),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => viewModel.selectSpeaker(context),
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 12,
                          children: [
                            const Icon(Symbols.speaker_phone_rounded),
                            Text(l10n.selectSpeaker),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              top: false,
              child: liveKitRoom == null && error == null
                  ? const Center(child: SyncingBowls(size: 48))
                  : !inCall
                  ? _Lobby(
                      room: room,
                      viewModel: viewModel,
                      ownUser: ownUser,
                      localVideoTrack: localVideoTrack,
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _CallStage(
                            room: room,
                            viewModel: viewModel,
                            liveKitRoom: liveKitRoom!,
                            ownUser: ownUser,
                            tileSize: tileSize,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Wrap(
                            alignment: .center,
                            spacing: 12,
                            runSpacing: 12,
                            children: controls,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  static void _showBetaInfo(BuildContext context) {
    final l10n = L10n.of(context);
    showD0b0Sheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(l10n.betaTag, style: D0b0Type.title),
              const SizedBox(height: 12),
              Text(
                l10n.videoCallsBetaWarning,
                style: D0b0Type.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Beta is a small outline tag beside the title; tapping it explains, so
/// there is no banner on every call.
class _BetaTag extends StatelessWidget {
  final VoidCallback onTap;

  const _BetaTag({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(color: scheme.outline, width: 1.5),
          ),
        ),
        child: Text(
          L10n.of(context).betaTag,
          style: D0b0Type.label.copyWith(
            fontSize: 12,
            letterSpacing: 0,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Before joining: the preview first with the toggles on it, who is
/// already in, one Mint Join. A failure replaces the preview's content with
/// one card.
class _Lobby extends StatelessWidget {
  final sdk.Room room;
  final CallViewModel viewModel;
  final User ownUser;
  final LocalVideoTrack? localVideoTrack;

  const _Lobby({
    required this.room,
    required this.viewModel,
    required this.ownUser,
    required this.localVideoTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final videoTrack = localVideoTrack;
    final cameraOn = videoTrack != null && !videoTrack.muted;
    final micOn = viewModel.value.startWithAudio;
    final isLoading = viewModel.value.isLoading;
    final error = viewModel.value.error;
    final members = room
        .getActiveMatrixRtcMembers()
        .map((member) => member.senderId)
        .whereType<String>()
        .where((userId) => userId != room.client.userID)
        .toSet()
        .map(room.unsafeGetUserFromMemoryOrFallback)
        .toList();
    final names = members.map((user) => user.calcDisplayname()).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(D0b0Radius.card),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: theme.colorScheme.surfaceContainer,
                        child: cameraOn
                            ? VideoTrackRenderer(videoTrack, fit: .cover)
                            : Center(
                                child: Avatar(
                                  mxContent: ownUser.avatarUrl,
                                  name: ownUser.calcDisplayname(),
                                  toneSeed: ownUser.id,
                                  size: 96,
                                ),
                              ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GlassPill(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.youPreview,
                            style: D0b0Type.label.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                              color: D0b0Palette.green100,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Row(
                          mainAxisAlignment: .center,
                          spacing: 12,
                          children: [
                            // Light filled = attention: the toggle turns
                            // light when it is off.
                            _CallButton(
                              tooltip: l10n.toggleMicrophone,
                              icon: micOn
                                  ? Symbols.mic_rounded
                                  : Symbols.mic_off_rounded,
                              attention: !micOn,
                              glass: true,
                              onPressed: isLoading
                                  ? null
                                  : viewModel.togglePreviewMic,
                            ),
                            _CallButton(
                              tooltip: l10n.toggleCamera,
                              icon: cameraOn
                                  ? Symbols.videocam_rounded
                                  : Symbols.videocam_off_rounded,
                              attention: !cameraOn,
                              glass: true,
                              onPressed: isLoading || videoTrack == null
                                  ? null
                                  : viewModel.togglePreviewCamera,
                            ),
                            _CallButton(
                              tooltip: l10n.selectCamera,
                              icon: Symbols.cameraswitch_rounded,
                              glass: true,
                              onPressed: isLoading
                                  ? null
                                  : () => viewModel.selectCamera(context),
                            ),
                          ],
                        ),
                      ),
                      if (error != null)
                        Container(
                          color: D0b0Palette.scrim,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: _CallFailedCard(
                            error: error,
                            server: room.client.userID?.domain ?? '',
                            onRetry: isLoading ? null : viewModel.connect,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: .center,
                children: [
                  for (final user in members.take(3))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Avatar(
                        mxContent: user.avatarUrl,
                        name: user.calcDisplayname(),
                        toneSeed: user.id,
                        size: 32,
                      ),
                    ),
                  if (members.isNotEmpty) const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      names.isEmpty
                          ? l10n.nobodyInCallYet
                          : names.length == 1
                          ? l10n.nameInCall(names.single)
                          : l10n.namesInCall(
                              '${names.take(names.length - 1).join(', ')} '
                              '& ${names.last}',
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.bodyS.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : viewModel.connect,
                  icon: isLoading
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Symbols.call_rounded),
                  label: Text(
                    isLoading ? l10n.loadingPleaseWait : l10n.joinCall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.joinCallHint,
                textAlign: TextAlign.center,
                style: D0b0Type.monoS.copyWith(color: theme.d0b0.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// When it fails: one card in the call's own space, never a second dialog
/// on top. Plain cause, what still works, Try again. Details holds the
/// trace with Copy.
class _CallFailedCard extends StatefulWidget {
  final Object error;
  final String server;
  final VoidCallback? onRetry;

  const _CallFailedCard({
    required this.error,
    required this.server,
    required this.onRetry,
  });

  @override
  State<_CallFailedCard> createState() => _CallFailedCardState();
}

class _CallFailedCardState extends State<_CallFailedCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = L10n.of(context);
    final trace = widget.error.toLocalizedString(context);
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(D0b0Radius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.error_rounded, color: scheme.onError),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.callFailedTitle,
                style: D0b0Type.title.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.callFailedBody(widget.server),
                style: D0b0Type.bodyS.copyWith(color: scheme.onSurfaceVariant),
              ),
              AnimatedSize(
                duration: D0b0Motion.move,
                curve: D0b0Motion.standard,
                child: !_showDetails
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(
                          trace,
                          style: D0b0Type.monoS.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                    icon: Icon(
                      _showDetails
                          ? Symbols.expand_less_rounded
                          : Symbols.expand_more_rounded,
                    ),
                    label: Text(l10n.details),
                  ),
                  if (_showDetails)
                    IconButton(
                      tooltip: l10n.copyToClipboard,
                      icon: const Icon(Symbols.content_copy_rounded),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: trace)),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: widget.onRetry,
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In the call: the active speaker fills the stage, others float as tiles;
/// without a focus everyone gets an equal tile.
class _CallStage extends StatelessWidget {
  final sdk.Room room;
  final CallViewModel viewModel;
  final Room liveKitRoom;
  final User ownUser;
  final double tileSize;

  const _CallStage({
    required this.room,
    required this.viewModel,
    required this.liveKitRoom,
    required this.ownUser,
    required this.tileSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = constraints.maxWidth < constraints.maxHeight
            ? Axis.vertical
            : Axis.horizontal;
        final tiles = liveKitRoom.getCallTiles(room);
        final focused =
            (viewModel.value.focusedTrack == null
                ? null
                : tiles.firstWhereOrNull(
                    (tile) => tile.id == viewModel.value.focusedTrack,
                  )) ??
            tiles.firstWhereOrNull(
              (tile) => tile.video?.isScreenShare == true,
            ) ??
            (tiles.length < 3 && tiles.any((tile) => tile.video != null)
                ? tiles.first
                : null);
        tiles.remove(focused);

        CallTile tile(TileData data, {double? width, double? height}) =>
            CallTile(
              key: ValueKey(data.id),
              user: data.user,
              video: data.video,
              audio: data.audio,
              connected: data.connected,
              width: width ?? 256,
              height: height ?? 256,
              isSpeaking: data.isSpeaking,
              isSelf: data.user.id == ownUser.id,
              handRaised: viewModel.participantRaisedHand(data.user.id),
              onTap: () => viewModel.setFocusedTrack(data.id),
            );

        if (focused == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = max(1, sqrt(tiles.length).ceil());
                final rows = max(1, (tiles.length / columns).ceil());
                const gap = 16.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                final height =
                    (constraints.maxHeight - gap * (rows - 1)) / rows;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  alignment: .center,
                  children: [
                    for (final data in tiles)
                      tile(data, width: width, height: height),
                  ],
                );
              },
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Flex(
            direction: axis,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: CallTile(
                  key: ValueKey(focused.id),
                  user: focused.user,
                  video: focused.video,
                  audio: focused.audio,
                  connected: focused.connected,
                  fit: .contain,
                  isSpeaking: focused.isSpeaking,
                  isSelf: focused.user.id == ownUser.id,
                  handRaised: viewModel.participantRaisedHand(focused.user.id),
                  onTap: () => viewModel.setFocusedTrack(focused.id),
                ),
              ),
              if (tiles.isNotEmpty) ...[
                const SizedBox(width: 16, height: 16),
                SizedBox(
                  height: axis == .horizontal ? null : tileSize,
                  width: axis == .vertical ? null : tileSize,
                  child: ListView.separated(
                    scrollDirection: axis == .horizontal
                        ? .vertical
                        : .horizontal,
                    itemCount: tiles.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 12, height: 12),
                    itemBuilder: (context, i) =>
                        tile(tiles[i], width: tileSize, height: tileSize),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Minimized: the call shrinks to a tile that keeps the speaker's video,
/// with hang up and expand.
class _MiniCall extends StatelessWidget {
  final sdk.Room room;
  final CallViewModel viewModel;
  final User ownUser;

  const _MiniCall({
    required this.room,
    required this.viewModel,
    required this.ownUser,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final liveKitRoom = viewModel.value.room;
    final tiles = liveKitRoom?.getCallTiles(room) ?? [];
    final focused =
        tiles.firstWhereOrNull((tile) => tile.isSpeaking) ??
        tiles.firstWhereOrNull((tile) => tile.user.id != ownUser.id) ??
        tiles.firstOrNull;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (focused != null)
            CallTile(
              key: ValueKey(focused.id),
              user: focused.user,
              video: focused.video,
              audio: focused.audio,
              connected: focused.connected,
              isSpeaking: false,
              compact: true,
              handRaised: viewModel.participantRaisedHand(focused.user.id),
              onTap: null,
            )
          else
            Center(
              child: Avatar(
                mxContent: room.avatar,
                name: room.getLocalizedDisplayname(),
                toneSeed: room.id,
                isRoom: !room.isDirectChat,
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                _HangUpButton(
                  compact: true,
                  onPressed: () => viewModel.close(context),
                ),
                const Spacer(),
                GlassIconButton(
                  icon: Symbols.open_in_full_rounded,
                  tooltip: l10n.expandCall,
                  onPressed: () =>
                      Matrix.of(context).callPosition.value = .fullScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 56 call control. Off states that need attention (muted mic, camera
/// off, raised hand) turn light filled.
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool attention;

  /// On the preview the idle state is glass instead of tonal.
  final bool glass;

  const _CallButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.attention = false,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 24,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(56),
        backgroundColor: attention
            ? D0b0Palette.green100
            : glass
            ? D0b0Palette.glass
            : scheme.surfaceContainerHigh,
        foregroundColor: attention ? D0b0Palette.ink : D0b0Palette.green100,
        disabledBackgroundColor: glass
            ? D0b0Palette.glass
            : scheme.surfaceContainerHigh,
      ),
      icon: Icon(icon),
    );
  }
}

/// Leaving is Coral: a wide pill, the only red control in a call.
class _HangUpButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact;

  const _HangUpButton({required this.onPressed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).hangUp,
      child: Material(
        color: D0b0Palette.coral,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: compact ? 48 : 72,
            height: compact ? 36 : 56,
            child: Icon(
              Symbols.call_end_rounded,
              fill: 1,
              size: compact ? 20 : 24,
              color: D0b0Palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
