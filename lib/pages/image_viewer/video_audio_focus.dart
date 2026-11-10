// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Holds *transient* Android audio focus while a video plays.
///
/// The video player asks for permanent focus by default. Other apps then treat
/// their loss as final and never resume their music. With a transient request
/// they pause, and resume once focus is given back.
///
/// The player has to be created with `mixWithOthers: true`, otherwise it takes
/// its own permanent focus on top of this one.
class VideoAudioFocus {
  final VoidCallback onInterrupted;

  VideoAudioFocus({required this.onInterrupted});

  bool _wanted = false;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;

  // Focus changes are applied one after another, in the order they were asked.
  Future<void> _queue = Future.value();

  /// Takes ([held] true) or gives back ([held] false) the audio focus.
  void setHeld(bool held) {
    if (_wanted == held) return;
    _wanted = held;
    _queue = _queue.then((_) => _apply(held));
  }

  Future<void> _apply(bool held) async {
    try {
      final session = await AudioSession.instance;
      if (held) {
        await session.configure(
          const AudioSessionConfiguration(
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.movie,
              usage: AndroidAudioUsage.media,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          ),
        );
        _interruptions ??= session.interruptionEventStream.listen((event) {
          // Another app (a call, an alarm) took over. Ducking is fine.
          if (event.begin && event.type != AudioInterruptionType.duck) {
            onInterrupted();
          }
        });
        await session.setActive(true);
      } else {
        await _interruptions?.cancel();
        _interruptions = null;
        await session.setActive(false);
        // Back to the default for other audio users, like voice messages.
        await session.configure(const AudioSessionConfiguration.music());
      }
    } catch (e, s) {
      Logs().w('Unable to change the audio focus', e, s);
    }
  }
}
