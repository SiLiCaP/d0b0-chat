<!--
SPDX-FileCopyrightText: 2019-Present Christian Kußowski
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
SPDX-FileCopyrightText: 2026-Present Contributors to d0b0 chat

SPDX-License-Identifier: AGPL-3.0-or-later
-->

<img src="assets/logo/img/banner.png" alt="d0b0 chat">

**d0b0 chat** is the [Matrix](https://matrix.org) client for the
[d0b0.lv](https://d0b0.lv) server — chat, voice and video calls, end-to-end
encrypted, on Android, iOS, desktop and the web.

## Download

[![Android APK](https://img.shields.io/badge/Android-download%20APK-3fd82f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/SiLiCaP/d0b0-chat/releases/latest/download/d0b0-chat-android.apk)
[![Linux](https://img.shields.io/badge/Linux-x64%20.tar.gz-3fd82f?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/SiLiCaP/d0b0-chat/releases/latest/download/d0b0-chat-linux-x64.tar.gz)
[![Web](https://img.shields.io/badge/Web-open%20chat.d0b0.lv-3fd82f?style=for-the-badge&logo=googlechrome&logoColor=white)](https://chat.d0b0.lv)

[![Latest release](https://img.shields.io/github/v/release/SiLiCaP/d0b0-chat?style=flat-square&color=3fd82f)](https://github.com/SiLiCaP/d0b0-chat/releases/latest)
· every build: [Releases](https://github.com/SiLiCaP/d0b0-chat/releases)
· iOS and Windows/macOS builds are coming.

The buttons always point at the newest release. On Android, allow installs from
your browser once, then open the APK.

## Features

- 📩 Messages, images, files and voice messages
- 🤙 Voice and video calls (Matrix RTC)
- 🔔 Push notifications through d0b0's own push gateway
- 🔐 End-to-end encryption, encrypted chat backup, emoji verification
- 🌌 Spaces, group chats and moderation
- 🎨 The d0b0 look — green themes, light and dark

## Build it yourself

You need [Flutter](https://flutter.dev) and [Rust](https://www.rust-lang.org/tools/install).

```sh
git clone https://github.com/SiLiCaP/d0b0-chat.git
cd d0b0-chat
flutter run
```

- Web: run `./scripts/prepare-web.sh` once before building.
- Android push via FCM: see [`D0B0_SERVER_PUSH.md`](D0B0_SERVER_PUSH.md)
  (needs a `google-services.json`; without it the app builds Google-free and
  uses UnifiedPush).
- Releases: GitHub → Actions → **Release** → Run workflow; CI builds and
  attaches the files.

Integration tests (Docker needed):

```sh
./scripts/prepare_integration_test.sh
flutter test integration_test/mobile_test.dart
```

## Based on FluffyChat

d0b0 chat is a fork of [FluffyChat](https://github.com/krille-chan/fluffychat)
by Christian Kußowski and contributors, licensed AGPL-3.0-or-later — so is
this fork. Thanks to them, to everyone who translated FluffyChat, and to the
Matrix Foundation for the
[emoji translations](https://github.com/matrix-org/matrix-spec/blob/main/data-definitions/sas-emoji.json)
used for verification (Apache 2.0).
