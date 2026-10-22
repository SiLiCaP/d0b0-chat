import 'dart:math';

import 'package:camera/camera.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'time_left_border_painter.dart';
import 'video_message_recorder.dart';
import 'video_trim_bar.dart';

class VideoMessageRecorderView extends StatelessWidget {
  final VideoMessageRecorderController controller;

  static const double _cardRadius = 28;
  static const double _borderWidth = 4;
  static const double _controlsHeight = 96;
  static const double _trimAreaHeight = VideoTrimBar.height + 48;

  const VideoMessageRecorderView(this.controller, {super.key});

  /// Aspect ratio (width / height) of the card for the current phase.
  double _aspectRatio(BuildContext context) {
    final videoSize = controller.videoSize;
    if (videoSize != null &&
        !videoSize.isEmpty &&
        controller.phase != VideoMessageRecorderPhase.recording) {
      return videoSize.width / videoSize.height;
    }
    final camera = controller.cameraController;
    if (camera != null && camera.value.isInitialized) {
      final ratio = camera.value.aspectRatio;
      final portrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;
      // The camera reports its sensor (landscape) aspect ratio.
      return portrait ? 1 / ratio : ratio;
    }
    return MediaQuery.orientationOf(context) == Orientation.portrait
        ? 9 / 16
        : 16 / 9;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = controller.phase;
    final showTrimArea =
        phase == VideoMessageRecorderPhase.editing ||
        phase == VideoMessageRecorderPhase.rendering;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (phase == VideoMessageRecorderPhase.rendering) return;
        controller.discard();
      },
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final aspectRatio = _aspectRatio(context);
              final maxWidth = min(constraints.maxWidth * 0.9, 560.0);
              final maxHeight =
                  constraints.maxHeight -
                  _controlsHeight -
                  _trimAreaHeight -
                  56;
              var cardWidth = maxWidth;
              var cardHeight = cardWidth / aspectRatio;
              if (cardHeight > maxHeight) {
                cardHeight = maxHeight;
                cardWidth = cardHeight * aspectRatio;
              }

              return Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        tooltip: L10n.of(context).close,
                        color: Colors.white,
                        onPressed: phase == VideoMessageRecorderPhase.rendering
                            ? null
                            : controller.discard,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: cardWidth,
                          height: cardHeight,
                          child: _RecorderCard(controller),
                        ),
                        SizedBox(
                          height: _trimAreaHeight,
                          width: maxWidth,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: showTrimArea
                                ? _TrimArea(controller)
                                : const SizedBox.shrink(),
                          ),
                        ),
                        SizedBox(
                          height: _controlsHeight,
                          width: maxWidth,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _Controls(
                              key: ValueKey(showTrimArea),
                              controller: controller,
                              theme: theme,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecorderCard extends StatelessWidget {
  final VideoMessageRecorderController controller;

  const _RecorderCard(this.controller);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = VideoMessageRecorderView._cardRadius;
    const borderWidth = VideoMessageRecorderView._borderWidth;
    final phase = controller.phase;
    final showBorder =
        phase == VideoMessageRecorderPhase.recording ||
        phase == VideoMessageRecorderPhase.stopping ||
        phase == VideoMessageRecorderPhase.initializing;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(borderWidth + 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - borderWidth - 2),
            child: ColoredBox(
              color: Colors.black,
              child: _buildContent(context),
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: showBorder ? 1 : 0,
            child: CustomPaint(
              painter: TimeLeftBorderPainter(
                progress: controller.recordingProgress,
                radius: radius,
                strokeWidth: borderWidth,
                trackColor: theme.colorScheme.surfaceContainerHighest,
                progressColor: controller.isTimeRunningOut
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        if (phase == VideoMessageRecorderPhase.recording ||
            phase == VideoMessageRecorderPhase.stopping)
          Positioned(top: 16, right: 16, child: _TimerChip(controller)),
        if (phase == VideoMessageRecorderPhase.recording &&
            controller.maxZoom > controller.minZoom)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _ZoomChip(controller)),
          ),
        if (phase == VideoMessageRecorderPhase.editing && controller.muted)
          Positioned(
            top: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer.withAlpha(204),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_off_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        if (phase == VideoMessageRecorderPhase.rendering)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  L10n.of(context).preparingVideo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.renderProgress,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    switch (controller.phase) {
      case VideoMessageRecorderPhase.error:
        return Center(
          key: const ValueKey('error'),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage ??
                      L10n.of(context).oopsSomethingWentWrong,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      case VideoMessageRecorderPhase.editing:
      case VideoMessageRecorderPhase.rendering:
        final player = controller.videoPlayerController;
        if (player == null) return const SizedBox.shrink();
        return GestureDetector(
          key: const ValueKey('player'),
          onTap: controller.togglePlayback,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: player.value.size.width,
              height: player.value.size.height,
              child: VideoPlayer(player),
            ),
          ),
        );
      case VideoMessageRecorderPhase.initializing:
      case VideoMessageRecorderPhase.recording:
      case VideoMessageRecorderPhase.stopping:
        final camera = controller.cameraController;
        if (camera == null || !camera.value.isInitialized) {
          return const Center(
            key: ValueKey('loading'),
            child: CircularProgressIndicator.adaptive(),
          );
        }
        final previewSize = camera.value.previewSize;
        return GestureDetector(
          key: const ValueKey('camera'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => controller.onZoomStart(),
          onScaleUpdate: (details) => controller.onZoomUpdate(details.scale),
          onScaleEnd: (_) => controller.onZoomEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  // previewSize is in sensor (landscape) orientation.
                  width: previewSize?.height ?? 1080,
                  height: previewSize?.width ?? 1920,
                  child: CameraPreview(camera),
                ),
              ),
              // Cover instantly when switching, fade out once the new
              // camera's preview is settled.
              AnimatedOpacity(
                duration: controller.switchingCamera
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                opacity: controller.switchingCamera ? 1 : 0,
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          ),
        );
    }
  }
}

class _TimerChip extends StatelessWidget {
  final VideoMessageRecorderController controller;

  const _TimerChip(this.controller);

  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = controller.isTimeRunningOut;
    // Pulse the recording dot, faster when the time is running out.
    final period = warning ? 500 : 1000;
    final t = (controller.elapsed.inMilliseconds % period) / period;
    final dotOpacity = 0.4 + 0.6 * (0.5 + 0.5 * cos(t * 2 * pi));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withAlpha(204),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: dotOpacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_format(controller.elapsed)} / ${_format(controller.maxDuration)}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: warning
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrimArea extends StatelessWidget {
  final VideoMessageRecorderController controller;

  const _TrimArea(this.controller);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = controller.recordedPath;
    if (path == null) return const SizedBox.shrink();
    final d = controller.trimmedDuration;
    final label =
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'
        ' • ${controller.estimatedTrimmedSize.toDouble().sizeString}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: controller.phase == VideoMessageRecorderPhase.rendering,
            child: VideoTrimBar(
              videoPath: path,
              duration: controller.videoDuration,
              start: controller.trimStart,
              end: controller.trimEnd,
              position: controller.playbackPosition,
              onChanged: controller.onTrimChanged,
              onChangeEnd: controller.onTrimChangeEnd,
              onSeek: controller.onSeek,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final VideoMessageRecorderController controller;
  final ThemeData theme;

  const _Controls({super.key, required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final phase = controller.phase;
    final busy =
        phase == VideoMessageRecorderPhase.rendering ||
        phase == VideoMessageRecorderPhase.stopping;

    final discardButton = IconButton.filledTonal(
      tooltip: l10n.delete,
      iconSize: 28,
      padding: const EdgeInsets.all(12),
      onPressed: busy ? null : controller.discard,
      icon: const Icon(Icons.delete_outline),
    );

    final List<Widget> children;
    if (phase == VideoMessageRecorderPhase.editing ||
        phase == VideoMessageRecorderPhase.rendering) {
      final isPlaying = controller.isPlaying;
      children = [
        discardButton,
        IconButton.filledTonal(
          tooltip: controller.muted ? l10n.unmute : l10n.mute,
          iconSize: 28,
          padding: const EdgeInsets.all(12),
          isSelected: controller.muted,
          onPressed: busy ? null : controller.toggleMute,
          icon: const Icon(Icons.volume_up_outlined),
          selectedIcon: const Icon(Icons.volume_off_outlined),
        ),
        IconButton.filledTonal(
          tooltip: isPlaying ? l10n.pause : l10n.play,
          iconSize: 28,
          padding: const EdgeInsets.all(12),
          onPressed: busy ? null : controller.togglePlayback,
          icon: Icon(
            isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
          ),
        ),
        IconButton.filled(
          tooltip: l10n.send,
          iconSize: 28,
          padding: const EdgeInsets.all(12),
          onPressed: busy ? null : controller.send,
          icon: const Icon(Icons.send_outlined),
        ),
      ];
    } else {
      final flipIcon = PlatformInfos.isIOS
          ? Icons.flip_camera_ios_outlined
          : Icons.flip_camera_android_outlined;
      children = [
        discardButton,
        FloatingActionButton.large(
          heroTag: null,
          tooltip: l10n.stopRecording,
          onPressed: phase == VideoMessageRecorderPhase.recording
              ? controller.stopRecording
              : null,
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          shape: const CircleBorder(),
          child: const Icon(Icons.stop_rounded, size: 40),
        ),
        IconButton.filledTonal(
          tooltip: l10n.switchCamera,
          iconSize: 28,
          padding: const EdgeInsets.all(12),
          onPressed: controller.canSwitchCamera
              ? controller.switchCamera
              : null,
          icon: Icon(flipIcon),
        ),
      ];
    }

    if (phase == VideoMessageRecorderPhase.error) {
      return Center(
        child: FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.close),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }
}

class _ZoomChip extends StatelessWidget {
  final VideoMessageRecorderController controller;

  const _ZoomChip(this.controller);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zoomed = controller.zoom > controller.minZoom + 0.05;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: controller.isZooming || zoomed ? 1 : 0.6,
      child: Material(
        color: theme.colorScheme.surfaceContainer.withAlpha(204),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tap resets the zoom.
          onTap: zoomed ? () => controller.setZoom(controller.minZoom) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${controller.zoom.toStringAsFixed(1)}×',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
