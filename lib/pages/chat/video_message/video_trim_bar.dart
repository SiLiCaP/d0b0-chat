import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// WhatsApp style trim bar: a filmstrip of the video with two draggable
/// handles around the selected range and a playhead.
class VideoTrimBar extends StatefulWidget {
  final String videoPath;
  final Duration duration;
  final Duration start;
  final Duration end;
  final Duration position;
  final Duration minDuration;
  final void Function(Duration start, Duration end, {required bool isStart})
  onChanged;
  final VoidCallback? onChangeEnd;
  final void Function(Duration position)? onSeek;

  static const double height = 56;
  static const double handleWidth = 16;
  static const int frameCount = 10;

  const VideoTrimBar({
    super.key,
    required this.videoPath,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.onChanged,
    this.onChangeEnd,
    this.onSeek,
    this.minDuration = const Duration(seconds: 1),
  });

  @override
  State<VideoTrimBar> createState() => _VideoTrimBarState();
}

class _VideoTrimBarState extends State<VideoTrimBar> {
  final List<Uint8List?> _frames = List.filled(VideoTrimBar.frameCount, null);
  StreamSubscription<ThumbnailFrame>? _framesSub;

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  void _loadFrames() {
    final step = widget.duration ~/ VideoTrimBar.frameCount;
    final configs = ThumbnailConfigs(
      video: EditorVideo.file(widget.videoPath),
      outputSize: const Size(96, 128),
      timestamps: [
        for (var i = 0; i < VideoTrimBar.frameCount; i++) step * i + step ~/ 2,
      ],
      // The preview player shares the decoder pool.
      maxParallelDecoders: 1,
    );
    try {
      _framesSub = ProVideoEditor.instance
          .getThumbnailStream(configs)
          .listen(
            (frame) {
              if (!mounted) return;
              setState(() {
                for (final index in frame.indices) {
                  _frames[index] = frame.bytes;
                }
              });
            },
            onError: (e, s) =>
                Logs().w('Unable to load video trim thumbnails', e, s),
            cancelOnError: true,
          );
    } catch (e, s) {
      Logs().w('Unable to load video trim thumbnails', e, s);
    }
  }

  @override
  void dispose() {
    _framesSub?.cancel();
    super.dispose();
  }

  Duration get _minDuration => widget.minDuration > widget.duration
      ? widget.duration
      : widget.minDuration;

  void _dragHandle(double dx, double trackWidth, {required bool isStart}) {
    final totalMs = widget.duration.inMilliseconds;
    final deltaMs = (dx / trackWidth * totalMs).round();
    final minMs = _minDuration.inMilliseconds;
    var start = widget.start.inMilliseconds;
    var end = widget.end.inMilliseconds;
    if (isStart) {
      start = (start + deltaMs).clamp(0, end - minMs);
    } else {
      end = (end + deltaMs).clamp(start + minMs, totalMs);
    }
    widget.onChanged(
      Duration(milliseconds: start),
      Duration(milliseconds: end),
      isStart: isStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const h = VideoTrimBar.handleWidth;
    const radius = 12.0;

    return SizedBox(
      height: VideoTrimBar.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 2 * h;
          final totalMs = widget.duration.inMilliseconds.clamp(1, 1 << 31);
          double toX(Duration d) => d.inMilliseconds / totalMs * trackWidth;
          final startX = toX(widget.start);
          final endX = toX(widget.end);
          final positionX = toX(widget.position).clamp(startX, endX);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Filmstrip
              Positioned(
                left: h,
                right: h,
                top: 4,
                bottom: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final ms = (details.localPosition.dx / trackWidth * totalMs)
                        .round();
                    widget.onSeek?.call(Duration(milliseconds: ms));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius / 2),
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Row(
                        children: [
                          for (final frame in _frames)
                            Expanded(
                              child: frame == null
                                  ? const SizedBox.expand()
                                  : Image.memory(
                                      frame,
                                      fit: BoxFit.cover,
                                      height: double.infinity,
                                      gaplessPlayback: true,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Dim the parts outside of the selection
              Positioned(
                left: h,
                width: startX,
                top: 4,
                bottom: 4,
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.black.withAlpha(140)),
                ),
              ),
              Positioned(
                left: h + endX,
                right: h,
                top: 4,
                bottom: 4,
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.black.withAlpha(140)),
                ),
              ),
              // Selection frame
              Positioned(
                left: startX + h / 2,
                width: endX - startX + h,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Playhead
              Positioned(
                left: h + positionX - 1.5,
                width: 3,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
              // Handles
              Positioned(
                left: startX,
                width: h,
                top: 0,
                bottom: 0,
                child: _TrimHandle(
                  isStart: true,
                  radius: radius,
                  onDrag: (dx) => _dragHandle(dx, trackWidth, isStart: true),
                  onDragEnd: widget.onChangeEnd,
                ),
              ),
              Positioned(
                left: h + endX,
                width: h,
                top: 0,
                bottom: 0,
                child: _TrimHandle(
                  isStart: false,
                  radius: radius,
                  onDrag: (dx) => _dragHandle(dx, trackWidth, isStart: false),
                  onDragEnd: widget.onChangeEnd,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  final bool isStart;
  final double radius;
  final void Function(double dx) onDrag;
  final VoidCallback? onDragEnd;

  const _TrimHandle({
    required this.isStart,
    required this.radius,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = Radius.circular(radius);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      onHorizontalDragEnd: (_) => onDragEnd?.call(),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: isStart
              ? BorderRadius.horizontal(left: r)
              : BorderRadius.horizontal(right: r),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.onPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
