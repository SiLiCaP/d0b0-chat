// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/media_download.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Starts [MediaDownload.autoDownload] for [event] once it is shown.
class MediaAutoDownload extends StatefulWidget {
  final Event event;
  final Widget child;

  /// Also look for a local copy when automatic downloads are off, for
  /// children that show whether the attachment is downloaded.
  final bool checkLocal;

  const MediaAutoDownload({
    required this.event,
    required this.child,
    this.checkLocal = false,
    super.key,
  });

  @override
  State<MediaAutoDownload> createState() => _MediaAutoDownloadState();
}

class _MediaAutoDownloadState extends State<MediaAutoDownload> {
  void _start() {
    final download = MediaDownload.of(widget.event);
    if (widget.checkLocal) download.checkLocal();
    download.autoDownload();
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(MediaAutoDownload oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      MediaDownload.of(oldWidget.event).cancelAutoDownload();
      _start();
    }
  }

  @override
  void dispose() {
    MediaDownload.of(widget.event).cancelAutoDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
