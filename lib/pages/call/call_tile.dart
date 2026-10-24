// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/glass.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class CallTile extends StatelessWidget {
  final lk.TrackPublication<lk.VideoTrack>? video;
  final lk.TrackPublication<lk.AudioTrack>? audio;
  final User user;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final lk.VideoViewFit fit;
  final double width, height;
  final bool handRaised, connected, isSpeaking;

  /// Your own tile is labelled 'You'.
  final bool isSelf;

  /// The minimized call: no name pill, a smaller avatar.
  final bool compact;

  const CallTile({
    super.key,
    this.video,
    this.audio,
    this.width = 256.0,
    this.height = 256.0,
    required this.user,
    required this.onTap,
    this.handRaised = false,
    this.fit = lk.VideoViewFit.cover,
    this.margin,
    required this.connected,
    required this.isSpeaking,
    this.isSelf = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final video = this.video?.track;
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final radius = BorderRadius.circular(compact ? 0 : D0b0Radius.card);
    final muted = audio != null && audio?.muted != false;
    final pillStyle = D0b0Type.label.copyWith(
      fontSize: 13,
      letterSpacing: 0,
      color: D0b0Palette.green100,
    );

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedContainer(
        margin: margin,
        duration: D0b0Motion.state,
        // The Mint ring shows who is speaking.
        foregroundDecoration: BoxDecoration(
          border: isSpeaking
              ? Border.all(color: theme.colorScheme.primary, width: 3)
              : null,
          borderRadius: radius,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              video != null && !video.muted
                  ? Positioned.fill(
                      child: lk.VideoTrackRenderer(video, fit: fit),
                    )
                  : Center(
                      child: Avatar(
                        size: compact ? 48 : 72,
                        mxContent: user.avatarUrl,
                        name: user.calcDisplayname(),
                        toneSeed: user.id,
                      ),
                    ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                ),
              ),
              if (handRaised)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: GlassPill(
                    height: 32,
                    child: Icon(Symbols.front_hand_rounded, size: 18),
                  ),
                ),
              if (!compact)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GlassPill(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: .min,
                        spacing: 6,
                        children: [
                          if (muted)
                            const Icon(Symbols.mic_off_rounded, size: 14),
                          if (this.video?.isScreenShare == true)
                            const Icon(Symbols.screen_share_rounded, size: 14),
                          Flexible(
                            child: Text(
                              isSelf ? l10n.you : user.calcDisplayname(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: pillStyle,
                            ),
                          ),
                          if (!connected)
                            const Icon(
                              Symbols.portable_wifi_off_rounded,
                              size: 14,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
