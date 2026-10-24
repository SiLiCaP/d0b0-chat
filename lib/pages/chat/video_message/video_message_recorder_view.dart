import 'dart:math';

import 'package:camera/camera.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/widgets/d0b0/glass.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'time_left_border_painter.dart';
import 'video_message_recorder.dart';
import 'video_trim_bar.dart';

class VideoMessageRecorderView extends StatelessWidget {
  final VideoMessageRecorderController controller;

  static const double _cardRadius = 28;
  static const double _borderWidth = 3;
  static const double _controlsHeight = 104;

  /// Size label, trim strip and caption field below the preview in review.
  static const double _trimAreaHeight = VideoTrimBar.height + 48 + 64;

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
                trackColor: theme.colorScheme.outline,
                // The only Coral while recording is the live dot.
                progressColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        if (phase != VideoMessageRecorderPhase.rendering)
          Positioned(
            top: 12,
            left: 12,
            child: GlassIconButton(
              icon: Symbols.close_rounded,
              tooltip: L10n.of(context).close,
              onPressed: controller.discard,
            ),
          ),
        if (phase == VideoMessageRecorderPhase.recording ||
            phase == VideoMessageRecorderPhase.stopping)
          Positioned(top: 16, right: 16, child: _TimerChip(controller)),
        // Review: play and pause sit on the preview itself.
        if (phase == VideoMessageRecorderPhase.editing)
          Center(
            child: GlassIconButton(
              icon: controller.isPlaying
                  ? Symbols.pause_rounded
                  : Symbols.play_arrow_rounded,
              filledIcon: true,
              size: 56,
              tooltip: controller.isPlaying
                  ? L10n.of(context).pause
                  : L10n.of(context).play,
              onPressed: controller.togglePlayback,
            ),
          ),
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
              child: const GlassPill(
                height: 32,
                child: Icon(Symbols.volume_off_rounded, size: 18),
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
                  Symbols.videocam_off_rounded,
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
    const period = 1000;
    final t = (controller.elapsed.inMilliseconds % period) / period;
    final dotOpacity = 0.4 + 0.6 * (0.5 + 0.5 * cos(t * 2 * pi));

    // Elapsed time only; the outline shows what is left. The live dot
    // pulses at 1 Hz, opacity only.
    return GlassPill(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: dotOpacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _format(controller.elapsed),
            style: D0b0Type.monoStyle.copyWith(color: D0b0Palette.green100),
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
        ' · ${controller.estimatedTrimmedSize.toDouble().sizeString}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: D0b0Type.monoStyle.copyWith(
              color: theme.colorScheme.onSurface,
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
          const SizedBox(height: 16),
          // An optional caption; it goes out with the video as one message.
          TextField(
            controller: controller.captionController,
            enabled: controller.phase != VideoMessageRecorderPhase.rendering,
            minLines: 1,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            style: D0b0Type.body.copyWith(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: L10n.of(context).addCaption,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
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

    Widget tonal({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
      IconData? selectedIcon,
      bool? isSelected,
    }) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: isSelected,
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
        fixedSize: const Size.square(56),
      ),
      icon: Icon(icon),
      selectedIcon: selectedIcon == null ? null : Icon(selectedIcon),
    );

    final discardButton = tonal(
      icon: Symbols.delete_rounded,
      tooltip: l10n.delete,
      onPressed: busy ? null : controller.discard,
    );

    final List<Widget> children;
    if (phase == VideoMessageRecorderPhase.editing ||
        phase == VideoMessageRecorderPhase.rendering) {
      // Send is the only filled button.
      children = [
        discardButton,
        tonal(
          icon: Symbols.volume_up_rounded,
          selectedIcon: Symbols.volume_off_rounded,
          isSelected: controller.muted,
          tooltip: controller.muted ? l10n.unmute : l10n.mute,
          onPressed: busy ? null : controller.toggleMute,
        ),
        IconButton(
          tooltip: l10n.send,
          onPressed: busy ? null : controller.send,
          iconSize: 26,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            fixedSize: const Size.square(56),
          ),
          icon: const Icon(Symbols.arrow_upward_rounded),
        ),
      ];
    } else {
      final flipIcon = PlatformInfos.isIOS
          ? Symbols.flip_camera_ios_rounded
          : Symbols.flip_camera_android_rounded;
      children = [
        discardButton,
        // Stop is Mint, 72: going is Mint, Coral is only the live dot.
        Semantics(
          button: true,
          label: l10n.stopRecording,
          child: Material(
            color: phase == VideoMessageRecorderPhase.recording
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: phase == VideoMessageRecorderPhase.recording
                  ? controller.stopRecording
                  : null,
              child: SizedBox.square(
                dimension: 72,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        tonal(
          icon: flipIcon,
          tooltip: l10n.switchCamera,
          onPressed: controller.canSwitchCamera
              ? controller.switchCamera
              : null,
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
      mainAxisAlignment: MainAxisAlignment.center,
      spacing:
          phase == VideoMessageRecorderPhase.editing ||
              phase == VideoMessageRecorderPhase.rendering
          ? 28
          : 40,
      children: children,
    );
  }
}

class _ZoomChip extends StatelessWidget {
  final VideoMessageRecorderController controller;

  const _ZoomChip(this.controller);

  @override
  Widget build(BuildContext context) {
    final zoomed = controller.zoom > controller.minZoom + 0.05;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: controller.isZooming || zoomed ? 1 : 0.6,
      child: GestureDetector(
        // Tap resets the zoom.
        onTap: zoomed ? () => controller.setZoom(controller.minZoom) : null,
        child: GlassPill(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${controller.zoom.toStringAsFixed(1)}×',
            style: D0b0Type.monoS.copyWith(
              fontSize: 12,
              color: D0b0Palette.green100,
            ),
          ),
        ),
      ),
    );
  }
}
