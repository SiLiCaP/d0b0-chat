// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../../widgets/blur_hash.dart';

class ImageBubble extends StatelessWidget {
  final Event event;
  final bool tapToView;
  final BoxFit fit;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? linkColor;
  final bool thumbnailOnly;
  final bool animated;
  final double width;
  final double height;
  final void Function()? onTap;
  final BorderRadius? borderRadius;
  final Timeline? timeline;

  const ImageBubble(
    this.event, {
    this.tapToView = true,
    this.backgroundColor,
    this.fit = BoxFit.contain,
    this.thumbnailOnly = true,
    this.width = 400,
    this.height = 300,
    this.animated = false,
    this.onTap,
    this.borderRadius,
    this.timeline,
    this.textColor,
    this.linkColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var borderRadius =
        this.borderRadius ?? BorderRadius.circular(AppConfig.borderRadius);

    final fileDescription = event.fileDescription;
    final textColor = this.textColor;

    if (fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
    }

    // Very narrow images would squeeze the caption to a letter or two per
    // line, so with a caption the image box gets a minimum width and the
    // image is scaled up to fill it, growing taller. Height is capped; past
    // the cap the image is letterboxed (BoxFit.contain), never cropped.
    const minCaptionWidth = 160.0;
    const maxCaptionedHeight = 640.0;
    var boxWidth = width;
    var boxHeight = height;
    var boxFit = fit;
    if (fileDescription != null && width < minCaptionWidth) {
      final info = event.content.tryGetMap<String, Object?>('info');
      final w = info?.tryGet<int>('w');
      final h = info?.tryGet<int>('h');
      final aspect = w != null && h != null && w > 0 && h > 0
          ? w / h
          : width / height;
      boxWidth = minCaptionWidth;
      boxHeight = min(minCaptionWidth / aspect, maxCaptionedHeight);
      boxFit = BoxFit.contain;
    }

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: event.messageType == MessageTypes.Sticker
                  ? Colors.transparent
                  : theme.dividerColor,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: event.eventId,
                  child: AppSettings.showThumbnailsInTimeline.value
                      ? MxcImage(
                          cacheKey: event.transactionId ?? event.eventId,
                          cacheName: event.room.id,
                          event: event,
                          width: boxWidth,
                          height: boxHeight,
                          fit: boxFit,
                          animated: animated,
                          isThumbnail: thumbnailOnly,
                          placeholder: event.messageType == MessageTypes.Sticker
                              ? null
                              : (_) => _ImageBubblePlaceholder(
                                  event: event,
                                  width: boxWidth,
                                  height: boxHeight,
                                  fit: boxFit,
                                ),
                        )
                      : _ImageBubblePlaceholder(
                          event: event,
                          width: boxWidth,
                          height: boxHeight,
                          fit: boxFit,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (fileDescription != null && textColor != null)
          SizedBox(
            width: boxWidth,
            child: Padding(
              // The same padding as the text of any other bubble.
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Linkify(
                text: fileDescription,
                textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
                style: TextStyle(
                  color: textColor,
                  fontSize: AppConfig.messageFontSize,
                ),
                options: const LinkifyOptions(humanize: false),
                linkStyle: TextStyle(
                  color: linkColor,
                  fontSize: AppConfig.messageFontSize,
                  decoration: TextDecoration.underline,
                  decorationColor: linkColor,
                ),
                onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageBubblePlaceholder extends StatelessWidget {
  final Event event;
  final double width, height;
  final BoxFit fit;

  const _ImageBubblePlaceholder({
    required this.event,
    required this.width,
    required this.height,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final blurHashString =
        event.infoMap.tryGet<String>('xyz.amorgan.blurhash') ??
        'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    return SizedBox(
      width: width,
      height: height,
      child: BlurHash(
        blurhash: blurHashString,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
}
