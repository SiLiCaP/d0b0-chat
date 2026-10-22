// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/media_download.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:material_ui/material_ui.dart';

/// Length, progress, size and time left of a [MediaDownload].
class VideoDownloadStatus extends StatelessWidget {
  final MediaDownload download;
  final Duration? videoDuration;

  const VideoDownloadStatus({
    required this.download,
    this.videoDuration,
    super.key,
  });

  static String formatDuration(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  static String formatTimeLeft(BuildContext context, Duration timeLeft) {
    final l10n = L10n.of(context);
    final seconds = timeLeft.inSeconds + 1;
    return l10n.timeLeft(
      seconds < 60
          ? l10n.secondsShort(seconds)
          : l10n.minutesShort((seconds / 60).ceil()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white, fontSize: 13);
    return ListenableBuilder(
      listenable: download,
      builder: (context, _) {
        final videoDuration = this.videoDuration;
        final progress = download.progress;
        final timeLeft = download.timeLeft;
        final fileSize = download.fileSize;
        final downloadedBytes = download.downloadedBytes;
        return Container(
          constraints: const BoxConstraints(maxWidth: 220),
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
          child: Column(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              if (videoDuration != null)
                Row(
                  mainAxisSize: .min,
                  spacing: 4,
                  children: [
                    const Icon(
                      Icons.videocam_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(formatDuration(videoDuration), style: textStyle),
                  ],
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
              if (fileSize != null)
                Text(
                  progress != null && downloadedBytes != null
                      ? '${downloadedBytes.sizeString} / ${fileSize.sizeString}'
                            ' · ${(progress * 100).floor()}%'
                      : fileSize.sizeString,
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              if (timeLeft != null)
                Text(formatTimeLeft(context, timeLeft), style: textStyle),
            ],
          ),
        );
      },
    );
  }
}
