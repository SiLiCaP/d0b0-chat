import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'video_message_recorder_view.dart';

/// A recorded (and possibly trimmed) video message, ready to be sent.
class VideoMessageRecording {
  final String path;
  final Duration duration;
  final Size? size;

  const VideoMessageRecording({
    required this.path,
    required this.duration,
    this.size,
  });
}

enum VideoMessageRecorderPhase {
  initializing,
  recording,
  stopping,
  editing,
  rendering,
  error,
}

/// Opens the floating video message recorder card. Recording starts right
/// away. Returns the recording to send, or null if it was discarded.
Future<VideoMessageRecording?> showVideoMessageRecorder({
  required BuildContext context,
  required Room room,
}) => showGeneralDialog<VideoMessageRecording>(
  context: context,
  // Same navigator as the chat, so the router hands the back gesture to the
  // recorder's PopScope instead of closing the chat.
  useRootNavigator: false,
  barrierDismissible: false,
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, _, _) => VideoMessageRecorder(room: room),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);

class VideoMessageRecorder extends StatefulWidget {
  final Room room;

  const VideoMessageRecorder({required this.room, super.key});

  @override
  VideoMessageRecorderController createState() =>
      VideoMessageRecorderController();
}

class VideoMessageRecorderController extends State<VideoMessageRecorder>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _bitrate1080p = 8 * 1000 * 1000;
  static const int _bitrateMax = 16 * 1000 * 1000;
  static const int _audioBitrate = 128 * 1000;
  static const int _fallbackUploadSize = 100 * 1000 * 1000;
  static const Duration warningThreshold = Duration(seconds: 5);
  static const Duration _confirmDiscardAfter = Duration(seconds: 3);

  VideoMessageRecorderPhase phase = VideoMessageRecorderPhase.initializing;
  String? errorMessage;

  List<CameraDescription> _cameras = [];
  CameraController? cameraController;
  bool switchingCamera = false;
  bool canSwitchWhileRecording = true;

  double zoom = 1;
  double minZoom = 1;
  double maxZoom = 1;
  double _zoomAtScaleStart = 1;
  bool isZooming = false;

  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  Duration elapsed = Duration.zero;
  late final Duration maxDuration = Duration(
    seconds: AppSettings.videoMessageMaxDurationSeconds.value,
  );

  String? recordedPath;
  VideoPlayerController? videoPlayerController;
  Duration videoDuration = Duration.zero;
  Size? videoSize;
  int videoFileSize = 0;
  int? videoBitrate;
  bool muted = false;

  /// Whether the edit preview is playing. Tracked here because the player
  /// reports a stale state once it reaches the end of the video.
  bool isPlaying = false;
  bool _startingPlayback = false;
  Duration _lastPosition = Duration.zero;
  Duration trimStart = Duration.zero;
  Duration trimEnd = Duration.zero;
  Duration playbackPosition = Duration.zero;
  double? renderProgress;
  String? _renderTaskId;
  StreamSubscription<ProgressModel>? _renderProgressSub;

  bool get isRecording => phase == VideoMessageRecorderPhase.recording;

  bool get isEditing => phase == VideoMessageRecorderPhase.editing;

  bool get needsRender => isTrimmed || muted;

  bool get isTrimmed =>
      trimStart > Duration.zero ||
      (videoDuration - trimEnd).inMilliseconds > 50;

  double get recordingProgress =>
      elapsed.inMilliseconds / max(1, maxDuration.inMilliseconds);

  bool get isTimeRunningOut => maxDuration - elapsed <= warningThreshold;

  bool get canSwitchCamera =>
      _cameras.map((c) => c.lensDirection).toSet().length > 1 &&
      !switchingCamera &&
      (phase == VideoMessageRecorderPhase.recording && canSwitchWhileRecording);

  bool get isFrontCamera =>
      cameraController?.description.lensDirection == CameraLensDirection.front;

  Duration get trimmedDuration => trimEnd - trimStart;

  int get estimatedTrimmedSize => videoDuration.inMilliseconds == 0
      ? videoFileSize
      : (videoFileSize *
                trimmedDuration.inMilliseconds /
                videoDuration.inMilliseconds)
            .round();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _renderProgressSub?.cancel();
    final renderTaskId = _renderTaskId;
    if (renderTaskId != null) {
      ProVideoEditor.instance.cancel(renderTaskId);
    }
    cameraController?.dispose();
    videoPlayerController?.removeListener(_onPlayerUpdate);
    videoPlayerController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (isRecording) {
        stopRecording();
      } else if (isEditing) {
        pause();
      }
    }
  }

  CameraDescription? _cameraFor(CameraLensDirection direction) =>
      _cameras.where((c) => c.lensDirection == direction).firstOrNull;

  /// Video bitrate which keeps a recording of [maxDuration] below the
  /// homeserver's upload limit.
  Future<int> _calcVideoBitrate() async {
    final preferred = AppSettings.videoMessageQuality.value == 'max'
        ? _bitrateMax
        : _bitrate1080p;
    int uploadSize;
    try {
      final config = await widget.room.client.getConfig().timeout(
        const Duration(seconds: 3),
      );
      uploadSize = config.mUploadSize ?? _fallbackUploadSize;
    } catch (_) {
      uploadSize = _fallbackUploadSize;
    }
    final fitting =
        (0.9 * uploadSize * 8 / max(1, maxDuration.inSeconds)).floor() -
        _audioBitrate;
    return max(500 * 1000, min(preferred, fitting));
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e, s) {
      Logs().w('Unable to list cameras', e, s);
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      _setError(L10n.of(context).cameraNotAvailable);
      return;
    }
    final preferredDirection =
        AppSettings.videoMessageDefaultCamera.value == 'back'
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final description = _cameraFor(preferredDirection) ?? _cameras.first;

    final bitrate = await _calcVideoBitrate();
    if (!mounted) return;

    final controller = cameraController = CameraController(
      description,
      AppSettings.videoMessageQuality.value == 'max'
          ? ResolutionPreset.max
          : ResolutionPreset.veryHigh,
      enableAudio: true,
      videoBitrate: bitrate,
      audioBitrate: _audioBitrate,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();
    } on CameraException catch (e, s) {
      Logs().w('Unable to start video message recording', e, s);
      if (!mounted) return;
      _setError(
        e.code.contains('AccessDenied') || e.code.contains('AccessRestricted')
            ? L10n.of(context).cameraAccessRequired
            : L10n.of(context).oopsSomethingWentWrong,
      );
      return;
    }
    if (!mounted) return;
    await _loadZoomRange(controller);
    if (!mounted) return;
    await WakelockPlus.enable();
    HapticFeedback.mediumImpact();
    _stopwatch.start();
    _ticker.start();
    setState(() => phase = VideoMessageRecorderPhase.recording);
  }

  void _setError(String message) => setState(() {
    phase = VideoMessageRecorderPhase.error;
    errorMessage = message;
  });

  void _onTick(Duration _) {
    if (!isRecording) return;
    setState(() => elapsed = _stopwatch.elapsed);
    if (elapsed >= maxDuration) stopRecording();
  }

  Future<void> switchCamera() async {
    final controller = cameraController;
    if (controller == null || !canSwitchCamera) return;
    final target = _cameraFor(
      isFrontCamera ? CameraLensDirection.back : CameraLensDirection.front,
    );
    if (target == null) return;
    // Cover the preview while switching: the first frames of the new camera
    // arrive before the preview's mirroring and rotation are updated.
    setState(() => switchingCamera = true);
    try {
      await controller.setDescription(target);
      HapticFeedback.selectionClick();
      await _loadZoomRange(controller);
      await Future.delayed(const Duration(milliseconds: 350));
    } on CameraException catch (e, s) {
      Logs().w('Unable to switch camera while recording', e, s);
      canSwitchWhileRecording = false;
    } finally {
      if (mounted) setState(() => switchingCamera = false);
    }
  }

  Future<void> _loadZoomRange(CameraController controller) async {
    try {
      minZoom = await controller.getMinZoomLevel();
      maxZoom = await controller.getMaxZoomLevel();
      zoom = 1.0.clamp(minZoom, maxZoom);
      await controller.setZoomLevel(zoom);
    } on CameraException catch (e, s) {
      Logs().w('Unable to read camera zoom range', e, s);
      minZoom = maxZoom = zoom = 1;
    }
    if (mounted) setState(() {});
  }

  bool get canZoom => isRecording && maxZoom > minZoom && !switchingCamera;

  void onZoomStart() {
    _zoomAtScaleStart = zoom;
    setState(() => isZooming = true);
  }

  void onZoomUpdate(double scale) => setZoom(_zoomAtScaleStart * scale);

  void onZoomEnd() => setState(() => isZooming = false);

  Future<void> setZoom(double value) async {
    final controller = cameraController;
    if (controller == null || !canZoom) return;
    final clamped = value.clamp(minZoom, maxZoom);
    if (clamped == zoom) return;
    setState(() => zoom = clamped);
    try {
      await controller.setZoomLevel(clamped);
    } on CameraException catch (e, s) {
      Logs().w('Unable to set camera zoom', e, s);
    }
  }

  Future<void> stopRecording() async {
    final controller = cameraController;
    if (!isRecording || controller == null) return;
    _ticker.stop();
    _stopwatch.stop();
    setState(() {
      phase = VideoMessageRecorderPhase.stopping;
      elapsed = _stopwatch.elapsed;
    });
    HapticFeedback.mediumImpact();
    await WakelockPlus.disable();

    final XFile file;
    try {
      file = await controller.stopVideoRecording();
    } on CameraException catch (e, s) {
      Logs().w('Unable to stop video message recording', e, s);
      if (mounted) _setError(L10n.of(context).oopsSomethingWentWrong);
      return;
    }
    recordedPath = file.path;

    videoFileSize = await File(file.path).length();
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(file.path),
      );
      videoDuration = metadata.duration;
      videoSize = metadata.resolution;
      videoBitrate = metadata.bitrate > 0 ? metadata.bitrate : null;
    } catch (e, s) {
      Logs().w('Unable to read video message metadata', e, s);
    }

    final player = VideoPlayerController.file(File(file.path));
    try {
      await player.initialize();
    } catch (e, s) {
      Logs().w('Unable to play recorded video message', e, s);
      await player.dispose();
      if (mounted) _setError(L10n.of(context).oopsSomethingWentWrong);
      return;
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    try {
      final hasAudio = await ProVideoEditor.instance.hasAudioTrack(
        EditorVideo.file(file.path),
      );
      if (!hasAudio) Logs().w('Recorded video message has no audio track');
    } catch (_) {}
    if (videoDuration == Duration.zero) videoDuration = player.value.duration;
    if (videoDuration == Duration.zero) videoDuration = elapsed;
    videoSize ??= player.value.size;
    // Looping keeps the player from ever reaching its "ended" state, from
    // which it doesn't reliably resume. The end is detected in
    // [_onPlayerUpdate] instead.
    await player.setLooping(true);
    await player.setVolume(1);
    player.addListener(_onPlayerUpdate);

    // Removes the camera preview from the tree, so the camera controller can
    // be disposed safely afterwards.
    setState(() {
      videoPlayerController = player;
      trimStart = Duration.zero;
      trimEnd = videoDuration;
      phase = VideoMessageRecorderPhase.editing;
      cameraController = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    await play();
  }

  /// Plays the selected range from its start.
  Future<void> play() async {
    final player = videoPlayerController;
    if (player == null || _startingPlayback) return;
    _startingPlayback = true;
    try {
      // Only mark as playing once the seek is done: until then the player
      // still reports the old (end) position, which would stop it again.
      await player.pause();
      _lastPosition = trimStart;
      await player.seekTo(trimStart);
      if (!mounted) return;
      setState(() {
        isPlaying = true;
        playbackPosition = trimStart;
      });
      await player.play();
    } finally {
      _startingPlayback = false;
    }
  }

  Future<void> pause() async {
    if (mounted) setState(() => isPlaying = false);
    await videoPlayerController?.pause();
  }

  void _onPlayerUpdate() {
    final player = videoPlayerController;
    if (player == null || !mounted) return;
    final position = player.value.position;
    // The player wrapped around to the beginning of the file.
    final wrapped =
        position < _lastPosition - const Duration(milliseconds: 300);
    _lastPosition = position;
    // Stop at the end of the selected range and go back to its start.
    if (isPlaying && !_startingPlayback && (position >= trimEnd || wrapped)) {
      setState(() {
        isPlaying = false;
        playbackPosition = trimStart;
      });
      _lastPosition = trimStart;
      player.pause().then((_) => player.seekTo(trimStart));
      return;
    }
    if (position != playbackPosition) {
      setState(() => playbackPosition = position);
    }
  }

  void onTrimChanged(Duration start, Duration end, {required bool isStart}) {
    setState(() {
      trimStart = start;
      trimEnd = end;
    });
    final player = videoPlayerController;
    if (player == null) return;
    // Show the frame at the dragged handle while trimming.
    if (isPlaying) pause();
    final preview = isStart ? start : end;
    _lastPosition = preview;
    player.seekTo(preview);
    setState(() => playbackPosition = preview);
  }

  void onTrimChangeEnd() => play();

  void onSeek(Duration position) {
    final player = videoPlayerController;
    if (player == null) return;
    final clamped = position < trimStart
        ? trimStart
        : position > trimEnd
        ? trimEnd
        : position;
    _lastPosition = clamped;
    player.seekTo(clamped);
    setState(() => playbackPosition = clamped);
  }

  void togglePlayback() {
    final player = videoPlayerController;
    if (player == null) return;
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void toggleMute() {
    setState(() => muted = !muted);
    videoPlayerController?.setVolume(muted ? 0 : 1);
  }

  Future<void> discard() async {
    final hasContent =
        isEditing || (isRecording && elapsed > _confirmDiscardAfter);
    if (hasContent) {
      final wasPlaying = isPlaying;
      await pause();
      if (!mounted) return;
      final result = await showOkCancelAlertDialog(
        context: context,
        title: L10n.of(context).discardVideoMessage,
        okLabel: L10n.of(context).discard,
        cancelLabel: L10n.of(context).cancel,
        isDestructive: true,
      );
      if (result != OkCancelResult.ok) {
        if (wasPlaying) await play();
        return;
      }
    }
    if (isRecording) {
      _ticker.stop();
      try {
        final file = await cameraController?.stopVideoRecording();
        if (file != null) recordedPath = file.path;
      } catch (_) {}
    }
    await _deleteFile(recordedPath);
    if (mounted) Navigator.of(context).pop(null);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> send() async {
    final path = recordedPath;
    if (path == null || !isEditing) return;
    await pause();
    if (!mounted) return;

    if (!needsRender) {
      Navigator.of(context).pop(
        VideoMessageRecording(
          path: path,
          duration: videoDuration,
          size: videoSize,
        ),
      );
      return;
    }

    setState(() {
      phase = VideoMessageRecorderPhase.rendering;
      renderProgress = null;
    });
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/video_message_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final renderData = VideoRenderData(
      videoSegments: [
        VideoSegment(
          video: EditorVideo.file(path),
          startTime: trimStart,
          endTime: trimEnd,
        ),
      ],
      enableAudio: !muted,
      bitrate: videoBitrate,
      shouldOptimizeForNetworkUse: true,
    );
    _renderTaskId = renderData.id;
    _renderProgressSub = ProVideoEditor.instance
        .progressStreamById(renderData.id)
        .listen((p) {
          if (mounted) setState(() => renderProgress = p.progress);
        });
    try {
      await ProVideoEditor.instance.renderVideoToFile(outputPath, renderData);
    } catch (e, s) {
      Logs().w('Unable to trim video message', e, s);
      if (!mounted) return;
      setState(() => phase = VideoMessageRecorderPhase.editing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).oopsSomethingWentWrong)),
      );
      return;
    } finally {
      _renderTaskId = null;
      await _renderProgressSub?.cancel();
      _renderProgressSub = null;
    }
    await _deleteFile(path);
    if (!mounted) return;
    Navigator.of(context).pop(
      VideoMessageRecording(
        path: outputPath,
        duration: trimmedDuration,
        size: videoSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VideoMessageRecorderView(this);
}
