// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:matrix/matrix.dart';

/// The one-line preview of a room's last event in the chat list.
///
/// 'You:' for own messages, 'Name:' in groups. Media shows a word, not an
/// emoji ('Photo', 'Video', 'Voice · 0:14'). Raw event types never appear.
class RoomPreview {
  /// The sender prefix without the trailing space, or null.
  final String? sender;
  final String body;

  const RoomPreview(this.body, {this.sender});

  static RoomPreview? of(Room room, L10n l10n) {
    final event = room.lastEvent;
    if (event == null) return null;
    final isMessage = {
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.Encrypted,
      PollEventContent.startType,
    }.contains(event.type);
    final body = _body(event, l10n);
    if (!isMessage || event.redacted) return RoomPreview(body);
    final String? name;
    if (event.senderId == room.client.userID) {
      name = l10n.you;
    } else if (!room.isDirectChat) {
      name = event.senderFromMemoryOrFallback.calcDisplayname(
        i18n: MatrixLocals(l10n),
      );
    } else {
      name = null;
    }
    return RoomPreview(
      body,
      sender: name == null ? null : l10n.previewSender(name),
    );
  }

  static String _body(Event event, L10n l10n) {
    if (!event.redacted && event.type == EventTypes.Sticker) {
      return l10n.previewSticker;
    }
    if (!event.redacted && event.type == EventTypes.Message) {
      switch (event.messageType) {
        case MessageTypes.Image:
          return l10n.previewPhoto;
        case MessageTypes.Video:
          return l10n.previewVideo;
        case MessageTypes.Audio:
          final duration = event.content
              .tryGetMap<String, Object?>('info')
              ?.tryGet<int>('duration');
          final isVoice =
              event.content.containsKey('org.matrix.msc3245.voice') ||
              event.content.containsKey('m.voice');
          if (!isVoice) return l10n.previewAudio;
          if (duration == null) return l10n.voiceMessage;
          return l10n.previewVoice(_formatDuration(duration));
        case MessageTypes.File:
          return l10n.previewFile;
        case MessageTypes.Location:
          return l10n.previewLocation;
      }
    }
    if (!event.redacted && event.type == PollEventContent.startType) {
      return l10n.previewPoll;
    }
    return event
        .calcLocalizedBodyFallback(
          MatrixLocals(l10n),
          hideReply: true,
          hideEdit: true,
          plaintextBody: true,
          removeMarkdown: true,
        )
        .trim()
        .replaceAll('\n', ' ');
  }

  static String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
