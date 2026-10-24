import 'dart:async';

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

enum RecordMode { voice, video }

/// The mic button of the chat input row. If [onVideoMessage] is set, it can
/// be swiped vertically to switch between voice and video messages.
class RecordModeButton extends StatefulWidget {
  final VoidCallback onVoiceMessage;
  final VoidCallback? onVideoMessage;
  final double size;

  const RecordModeButton({
    required this.onVoiceMessage,
    required this.onVideoMessage,
    required this.size,
    super.key,
  });

  @override
  State<RecordModeButton> createState() => _RecordModeButtonState();
}

class _RecordModeButtonState extends State<RecordModeButton>
    with SingleTickerProviderStateMixin {
  /// Past this the mode switches with a haptic tick.
  static const double _switchDistance = 56;
  static const double _maxDrag = 84;
  static const double _trackHeight = 132;

  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  /// How far the knob is lifted, while dragging and snapping back.
  late final AnimationController _knob = AnimationController(
    vsync: this,
    upperBound: _maxDrag,
    duration: const Duration(milliseconds: 250),
  );
  bool _switchedThisDrag = false;
  bool _dragging = false;
  Timer? _labelTimer;
  bool _showLabel = false;

  @override
  void dispose() {
    _labelTimer?.cancel();
    _knob.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _switchedThisDrag = false;
    _labelTimer?.cancel();
    setState(() {
      _dragging = true;
      _showLabel = false;
    });
    _knob.value = 0;
    _portal.show();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _knob.value = (_knob.value - details.delta.dy).clamp(0, _maxDrag);
    if (!_switchedThisDrag && _knob.value >= _switchDistance) {
      _switchedThisDrag = true;
      _toggle(1);
      setState(() => _showLabel = true);
    }
  }

  void _onDragEnd(DragEndDetails _) {
    setState(() => _dragging = false);
    // The knob snaps back with the overshoot curve; the label stays a
    // moment to confirm the mode.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final snap = disableAnimations
        ? Future<void>.sync(() => _knob.value = 0)
        : _knob.animateTo(0, curve: D0b0Motion.overshoot);
    snap.whenComplete(() {
      if (!mounted) return;
      _labelTimer = Timer(Duration(milliseconds: _showLabel ? 1200 : 0), () {
        if (!mounted) return;
        setState(() => _showLabel = false);
        _portal.hide();
      });
    });
  }

  Widget _buildTrack(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final otherIcon = _mode == RecordMode.voice
        ? Symbols.videocam_rounded
        : Symbols.mic_rounded;
    final currentIcon = _mode == RecordMode.voice
        ? Symbols.mic_rounded
        : Symbols.videocam_rounded;
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.bottomRight,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedOpacity(
              duration: D0b0Motion.state,
              opacity: _showLabel ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 82),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Icon(currentIcon, size: 18),
                      Text(
                        _mode == RecordMode.video
                            ? l10n.videoMessage
                            : l10n.voiceMessage,
                        style: D0b0Type.label.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: D0b0Motion.state,
              curve: D0b0Motion.standard,
              width: widget.size,
              height: _dragging ? _trackHeight : widget.size,
              decoration: ShapeDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: const StadiumBorder(),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    top: 12,
                    child: Icon(
                      otherIcon,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _knob,
                    builder: (context, _) => Positioned(
                      bottom: _knob.value,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: D0b0Motion.state,
                          child: Icon(
                            currentIcon,
                            key: ValueKey(currentIcon),
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  late RecordMode _mode =
      widget.onVideoMessage != null &&
          AppSettings.recordButtonMode.value == RecordMode.video.name
      ? RecordMode.video
      : RecordMode.voice;

  bool get _canSwitch => widget.onVideoMessage != null;

  void _toggle(double direction) {
    if (!_canSwitch) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _mode == RecordMode.voice ? RecordMode.video : RecordMode.voice;
    });
    AppSettings.recordButtonMode.setItem(_mode.name);
  }

  void _showHint() {
    final l10n = L10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        margin: EdgeInsets.only(
          bottom: widget.size + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        showCloseIcon: true,
        content: Text(
          _canSwitch
              ? '${l10n.longPressToRecordVoiceMessage}\n${l10n.swipeToSwitchRecordMode}'
              : l10n.longPressToRecordVoiceMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    // Tonal: the trailing button is a quiet surface until there is text.
    final style = IconButton.styleFrom(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      foregroundColor: theme.colorScheme.onSurface,
      minimumSize: const Size.square(48),
    );

    final button = _mode == RecordMode.video
        ? IconButton(
            key: const ValueKey(RecordMode.video),
            tooltip: l10n.videoMessageSwipeForVoice,
            onPressed: widget.onVideoMessage,
            onLongPress: widget.onVideoMessage,
            style: style,
            icon: const Icon(Symbols.videocam_rounded),
          )
        : HoverBuilder(
            key: const ValueKey(RecordMode.voice),
            builder: (context, hovered) => IconButton(
              tooltip: _canSwitch
                  ? l10n.voiceMessageSwipeForVideo
                  : l10n.voiceMessage,
              onPressed: hovered ? widget.onVoiceMessage : _showHint,
              onLongPress: widget.onVoiceMessage,
              style: style,
              icon: const Icon(Symbols.mic_rounded),
            ),
          );

    if (!_canSwitch) return button;

    // Swipe up: a track grows out of the button with the other mode on
    // top; the knob follows the finger and switches past 56 px.
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildTrack,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedOpacity(
              duration: D0b0Motion.state,
              opacity: _dragging ? 0 : 1,
              child: AnimatedSwitcher(
                duration: D0b0Motion.state,
                child: button,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
