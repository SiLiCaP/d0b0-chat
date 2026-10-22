// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/media_download.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/widgets/blur_hash.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:fluffychat/widgets/video_download_status.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
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
    const maxDimension = 300.0;
    final infoMap = event.content.tryGetMap<String, Object?>('info');
    final videoWidth = infoMap?.tryGet<int>('w') ?? maxDimension;
    final videoHeight = infoMap?.tryGet<int>('h') ?? maxDimension;

    final modifier = max(videoWidth, videoHeight) / maxDimension;
    final width = videoWidth / modifier;
    final height = videoHeight / modifier;

    final durationInt = infoMap?.tryGet<int>('duration');
    final duration = durationInt == null
        ? null
        : Duration(milliseconds: durationInt);
    final sizeString = event.sizeString;

    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Material(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          child: InkWell(
            onTap: _onTap,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
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
                          tween: Tween(end: isDownloaded ? 0 : 1),
                          duration: FluffyThemes.animationDuration,
                          curve: FluffyThemes.animationCurve,
                          child: thumbnail,
                          builder: (context, blur, thumbnail) => blur == 0
                              ? thumbnail!
                              // The blur paints past its bounds, so keep it
                              // off the caption below and the hero flight.
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppConfig.borderRadius,
                                  ),
                                  child: Container(
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
                        ),
                        Center(
                          child: AnimatedSwitcher(
                            duration: FluffyThemes.animationDuration,
                            child: isDownloaded
                                ? const CircleAvatar(
                                    child: Icon(Icons.play_arrow_outlined),
                                  )
                                : _VideoDownloadButton(
                                    download: _download,
                                    sizeString: sizeString,
                                  ),
                          ),
                        ),
                        if (duration != null)
                          Positioned(
                            bottom: 8,
                            left: 16,
                            child: Text(
                              VideoDownloadStatus.formatDuration(duration),
                              style: TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.black.withAlpha(32),
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
        if (fileDescription != null &&
            widget.textColor != null &&
            widget.linkColor != null)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Linkify(
                text: fileDescription,
                textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: AppConfig.messageFontSize,
                ),
                options: const LinkifyOptions(humanize: false),
                linkStyle: TextStyle(
                  color: widget.linkColor,
                  fontSize: AppConfig.messageFontSize,
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
    return Container(
      padding: EdgeInsets.fromLTRB(6, 6, label == null ? 6 : 14, 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(64),
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          SizedBox.square(
            dimension: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CircularProgressIndicator(
                    // An empty ring before the download, a spinning one
                    // while the size is unknown or the file is being written.
                    value: isDownloading ? progress : 0,
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                    backgroundColor: Colors.white.withAlpha(64),
                  ),
                ),
                const Icon(Icons.arrow_downward, color: Colors.white, size: 20),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (timeLeft != null)
                    Text(
                      VideoDownloadStatus.formatTimeLeft(context, timeLeft),
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withAlpha(192),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
