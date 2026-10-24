// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class IncomingCallDialog extends StatefulWidget {
  final Event event;
  const IncomingCallDialog({required this.event, super.key});

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  /// Rings ripple outward from the avatar every 1.2 s.
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  final AudioPlayer _player = AudioPlayer();

  StreamSubscription? _onSync;

  @override
  void initState() {
    _initAudioPlayer();
    _onSync = widget.event.room.client.onSync.stream.listen((_) {
      if (!mounted) return;
      if (!widget.event.room.hasActiveMatrixRtcCall) {
        Logs().i('The other party has ended the call');
        Navigator.of(context).pop();
      } else if (widget.event.room.getActiveMatrixRtcMembers().any(
        (member) =>
            member.senderId == widget.event.room.client.userID! &&
            member.deviceId != widget.event.room.client.deviceID!,
      )) {
        Logs().i('User has accepted the call on a different device');
        Navigator.of(context).pop();
      }
    });
    final timeout =
        widget.event.tryParseRtcNotificationContent()?.lifetime ??
        RtcNotificationContent.defaultLifetime;
    Future.delayed(timeout).then((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
    super.initState();
  }

  Future<void> _initAudioPlayer() async {
    await _player.setAsset('assets/sounds/call_ring.mp3');
    await _player.setLoopMode(.one);
    await _player.play();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rings.stop();
      _rings.value = 0.5;
    } else if (!_rings.isAnimating) {
      _rings.repeat();
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    _onSync?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.event.room;
    final displayname = room.getLocalizedDisplayname();
    final avatar = room.avatar;
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final isVideo = room.activeMatrixRtcCallIntent == MatrixRtcCallIntent.video;
    final labelStyle = D0b0Type.label.copyWith(color: D0b0Palette.green100);
    return Dialog.fullscreen(
      backgroundColor: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [D0b0Palette.deep, D0b0Palette.green950],
            stops: [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox.square(
                  dimension: 200,
                  child: AnimatedBuilder(
                    animation: _rings,
                    builder: (context, child) => CustomPaint(
                      painter: _RingsPainter(
                        phase: _rings.value,
                        color: D0b0Palette.mint,
                      ),
                      child: child,
                    ),
                    child: Center(
                      child: Avatar(
                        mxContent: avatar,
                        name: displayname,
                        toneSeed: room.id,
                        isRoom: !room.isDirectChat,
                        size: 112,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayname,
                  textAlign: TextAlign.center,
                  style: D0b0Type.headline.copyWith(
                    color: D0b0Palette.green100,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${isVideo ? l10n.incomingVideoCall : l10n.incomingVoiceCall}'
                  ' · ${room.client.userID?.domain ?? ''}',
                  textAlign: TextAlign.center,
                  style: D0b0Type.monoStyle.copyWith(
                    color: D0b0Palette.green400,
                  ),
                ),
                const Spacer(flex: 3),
                TextButton.icon(
                  onPressed: () {
                    context.pop(false);
                    FluffyChatApp.router.go('/rooms/${room.id}');
                  },
                  icon: const Icon(Symbols.chat_bubble_rounded, size: 20),
                  label: Text(l10n.replyWithMessage),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundAction(
                      label: l10n.decline,
                      labelStyle: labelStyle,
                      color: D0b0Palette.coral,
                      icon: Symbols.call_end_rounded,
                      onPressed: () => context.pop(false),
                    ),
                    _RoundAction(
                      label: l10n.accept,
                      labelStyle: labelStyle,
                      color: D0b0Palette.mint,
                      icon: isVideo
                          ? Symbols.videocam_rounded
                          : Symbols.call_rounded,
                      onPressed: () => context.pop(true),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decline (Coral) and accept (Mint): 72 round buttons with a label.
class _RoundAction extends StatelessWidget {
  final String label;
  final TextStyle labelStyle;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundAction({
    required this.label,
    required this.labelStyle,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        iconSize: 28,
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: D0b0Palette.ink,
          fixedSize: const Size.square(72),
        ),
        icon: Icon(icon, fill: 1),
      ),
      const SizedBox(height: 10),
      Text(label, style: labelStyle),
    ],
  );
}

/// Three thin rings that drift outward from the avatar and fade.
class _RingsPainter extends CustomPainter {
  final double phase;
  final Color color;

  const _RingsPainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const inner = 60.0;
    final outer = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1;
      final radius = inner + (outer - inner) * t;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: (1 - t) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
