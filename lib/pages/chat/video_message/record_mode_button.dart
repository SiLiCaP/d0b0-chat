import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:flutter/services.dart';
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

class _RecordModeButtonState extends State<RecordModeButton> {
  static const double _swipeDistance = 16;
  static const double _swipeVelocity = 300;

  late RecordMode _mode =
      widget.onVideoMessage != null &&
          AppSettings.recordButtonMode.value == RecordMode.video.name
      ? RecordMode.video
      : RecordMode.voice;

  double _dragDistance = 0;

  /// Direction of the last swipe, used for the slide animation.
  double _slideDirection = 1;

  bool get _canSwitch => widget.onVideoMessage != null;

  void _toggle(double direction) {
    if (!_canSwitch) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slideDirection = direction;
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
    final style = IconButton.styleFrom(
      backgroundColor: theme.bubbleColor,
      foregroundColor: theme.onBubbleColor,
    );

    final button = _mode == RecordMode.video
        ? IconButton(
            key: const ValueKey(RecordMode.video),
            tooltip: l10n.videoMessageSwipeForVoice,
            onPressed: widget.onVideoMessage,
            onLongPress: widget.onVideoMessage,
            style: style,
            icon: const Icon(Icons.videocam_outlined),
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
              icon: Icon(hovered ? Icons.mic : Icons.mic_none_outlined),
            ),
          );

    if (!_canSwitch) return button;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dragDistance = 0,
      onVerticalDragUpdate: (details) => _dragDistance += details.delta.dy,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragDistance.abs() >= _swipeDistance ||
            velocity.abs() >= _swipeVelocity) {
          final direction = _dragDistance != 0
              ? _dragDistance.sign
              : velocity.sign;
          _toggle(direction);
        }
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRect(
              child: AnimatedSwitcher(
                duration: FluffyThemes.animationDuration,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_mode);
                  final offset = Tween<Offset>(
                    begin: Offset(
                      0,
                      (incoming ? -1 : 1) * _slideDirection * 0.8,
                    ),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: button,
              ),
            ),
            // Between the button and the rounded (clipped) end of the input
            // bar.
            Positioned(
              right: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in RecordMode.values)
                    AnimatedContainer(
                      duration: FluffyThemes.animationDuration,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      width: 4,
                      height: mode == _mode ? 8 : 4,
                      decoration: BoxDecoration(
                        color: mode == _mode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
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
}
