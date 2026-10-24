// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' show ImageFilter;

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/media_download.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/widgets/blur_hash.dart';
import 'package:fluffychat/widgets/d0b0/glass.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:fluffychat/widgets/video_download_status.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../image_viewer/image_viewer.dart';

class EventVideoPlayer extends StatefulWidget {
  final Event event;
  final Timeline? timeline;
  final Color? textColor;
  final Color? linkColor;

  const EventVideoPlayer(
    this.event, {
    this.timeline,
    this.textColor,
    this.linkColor,
    super.key,
  });

  @override
  State<EventVideoPlayer> createState() => _EventVideoPlayerState();
}

class _EventVideoPlayerState extends State<EventVideoPlayer> {
  static const String fallbackBlurHash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';

  final supportsVideoPlayer = PlatformInfos.supportsVideoPlayer;

  late MediaDownload _download = MediaDownload.of(widget.event);

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(EventVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final download = MediaDownload.of(widget.event);
    if (download != _download) {
      _download.cancelAutoDownload();
      _download = download;
      _prepare();
    }
  }

  @override
  void dispose() {
    _download.cancelAutoDownload();
    super.dispose();
  }

  void _prepare() {
    if (!supportsVideoPlayer) return;
    _download.checkLocal();
    _download.autoDownload();
  }

  void _openViewer() => showDialog(
    context: context,
    builder: (_) =>
        ImageViewer(event, timeline: widget.timeline, outerContext: context),
  );

  Future<void> _startDownload() async {
    try {
      await _download.download();
    } catch (e, s) {
      if (!mounted) return;
      ErrorReporter(context, 'Unable to download video').onErrorCallback(e, s);
    }
  }

  void _onTap() {
    if (!supportsVideoPlayer) {
      event.saveFile(context);
    } else if (_download.isDownloaded || _download.isDownloading) {
      _openViewer();
    } else {
      _startDownload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blurHash =
        (event.infoMap as Map<String, dynamic>).tryGet<String>(
          'xyz.amorgan.blurhash',
        ) ??
        fallbackBlurHash;
    final fileDescription = event.fileDescription;
    // Video bubbles keep their aspect between 9:16 and 16:9 and cap at
    // 240 wide; the footage is the bubble.
    const maxWidth = 240.0;
    const maxHeight = 320.0;
    final infoMap = event.content.tryGetMap<String, Object?>('info');
    final videoWidth = (infoMap?.tryGet<int>('w') ?? 9).toDouble();
    final videoHeight = (infoMap?.tryGet<int>('h') ?? 16).toDouble();
    final aspect = (videoWidth / videoHeight).clamp(9 / 16, 16 / 9);
    var width = maxWidth;
    var height = width / aspect;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }

    final durationInt = infoMap?.tryGet<int>('duration');
    final duration = durationInt == null
        ? null
        : Duration(milliseconds: durationInt);
    final sizeString = event.sizeString;
    final isSending = event.status.isSending;

    // With a caption the video sits inside a normal bubble, 4 px in, with
    // the radius stepping down to 18.
    final hasCaption =
        fileDescription != null &&
        widget.textColor != null &&
        widget.linkColor != null;
    final radius = BorderRadius.circular(
      hasCaption ? D0b0Radius.bubble - 4 : D0b0Radius.bubble,
    );

    final frame = ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: InkWell(
          onTap: isSending ? null : _onTap,
          child: SizedBox(
            width: width,
            height: height,
            child: Hero(
              tag: event.eventId,
              child: ListenableBuilder(
                listenable: _download,
                builder: (context, thumbnail) {
                  final isDownloaded =
                      supportsVideoPlayer && _download.isDownloaded;
                  return Stack(
                    children: [
                      // Blurred until the video is on this device, so it
                      // reads as "not here yet" at a glance.
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: isDownloaded || isSending ? 0 : 1),
                        duration: FluffyThemes.animationDuration,
                        curve: FluffyThemes.animationCurve,
                        child: thumbnail,
                        builder: (context, blur, thumbnail) => blur == 0
                            ? thumbnail!
                            : Container(
                                foregroundDecoration: BoxDecoration(
                                  color: Colors.black.withAlpha(
                                    (blur * 96).round(),
                                  ),
                                ),
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: blur * 16,
                                    sigmaY: blur * 16,
                                    tileMode: TileMode.clamp,
                                  ),
                                  child: thumbnail,
                                ),
                              ),
                      ),
                      Center(
                        child: AnimatedSwitcher(
                          duration: FluffyThemes.animationDuration,
                          child: isSending
                              ? _UploadingButton(event: event)
                              : isDownloaded
                              ? const GlassIconButton(
                                  icon: Symbols.play_arrow_rounded,
                                  filledIcon: true,
                                  size: 56,
                                  onPressed: null,
                                )
                              : _VideoDownloadButton(
                                  download: _download,
                                  sizeString: sizeString,
                                ),
                        ),
                      ),
                      if (duration != null)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: GlassPill(
                            height: 24,
                            child: Text(
                              VideoDownloadStatus.formatDuration(duration),
                              style: D0b0Type.monoS.copyWith(
                                color: D0b0Palette.green100,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                child: SizedBox(
                  width: width,
                  height: height,
                  child:
                      event.hasThumbnail &&
                          AppSettings.showThumbnailsInTimeline.value
                      ? MxcImage(
                          event: event,
                          cacheKey: event.transactionId ?? event.eventId,
                          cacheName: event.room.id,
                          isThumbnail: true,
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                          placeholder: (context) => BlurHash(
                            blurhash: blurHash,
                            width: width,
                            height: height,
                            fit: BoxFit.cover,
                          ),
                        )
                      : BlurHash(
                          blurhash: blurHash,
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!hasCaption) return frame;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Padding(padding: const EdgeInsets.all(4), child: frame),
        SizedBox(
          width: width + 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 11),
            child: Linkify(
              text: fileDescription,
              textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
              style: D0b0Type.body.copyWith(color: widget.textColor),
              options: const LinkifyOptions(humanize: false),
              linkStyle: D0b0Type.body.copyWith(
                color: widget.linkColor,
                decoration: TextDecoration.underline,
                decorationColor: widget.linkColor,
              ),
              onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
            ),
          ),
        ),
      ],
    );
  }
}

/// While the video uploads: a glass circle with a ring, ✕ cancels.
class _UploadingButton extends StatelessWidget {
  final Event event;

  const _UploadingButton({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GlassIconButton(
            icon: Symbols.close_rounded,
            size: 56,
            tooltip: L10n.of(context).cancel,
            onPressed: event.cancelSend,
          ),
          IgnorePointer(
            child: SizedBox.square(
              dimension: 53,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: scheme.primary,
                backgroundColor: scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Download arrow inside a ring that fills while downloading, next to the
/// size of the video.
class _VideoDownloadButton extends StatelessWidget {
  final MediaDownload download;
  final String? sizeString;

  const _VideoDownloadButton({required this.download, this.sizeString});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloading = download.isDownloading;
    final progress = download.progress;
    final downloadedBytes = download.downloadedBytes;
    final fileSize = download.fileSize;
    final timeLeft = isDownloading ? download.timeLeft : null;
    final label =
        isDownloading &&
            progress != null &&
            downloadedBytes != null &&
            fileSize != null
        ? '${downloadedBytes.sizeString} / ${fileSize.sizeString}'
        : sizeString;
    return IntrinsicWidth(
      child: GlassPill(
        height: 44,
        padding: EdgeInsets.fromLTRB(10, 0, label == null ? 10 : 16, 0),
        child: Row(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            SizedBox.square(
              dimension: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isDownloading)
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                        backgroundColor: D0b0Palette.green700,
                      ),
                    ),
                  const Icon(
                    Symbols.download_rounded,
                    color: D0b0Palette.green100,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (label != null)
              Flexible(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.monoStyle.copyWith(
                        color: D0b0Palette.green100,
                      ),
                    ),
                    if (timeLeft != null)
                      Text(
                        VideoDownloadStatus.formatTimeLeft(context, timeLeft),
                        maxLines: 1,
                        style: D0b0Type.monoS.copyWith(
                          color: D0b0Palette.green400,
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
