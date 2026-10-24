// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// Renders the first frame of the splash marquee into the native splash
// images, so the system splash and the animated one line up exactly.
//
// Run after changing the marquee:
//   flutter test tool/generate_splash_frame.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/widgets/d0b0/splash_marquee.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _targets = <String, double>{
  'android/app/src/main/res/drawable-mdpi/splash.png': 1,
  'android/app/src/main/res/drawable-hdpi/splash.png': 1.5,
  'android/app/src/main/res/drawable-xhdpi/splash.png': 2,
  'android/app/src/main/res/drawable-xxhdpi/splash.png': 3,
  'android/app/src/main/res/drawable-xxxhdpi/splash.png': 4,
  'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 1,
  'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png': 2,
  'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png': 3,
  'web/splash/splash.png': 2,
};

void main() {
  testWidgets('generate splash frame', (tester) async {
    // The default test surface (800 × 600) is shorter than the band.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: D0b0Palette.deep,
            child: SplashBand(phase: AlwaysStoppedAnimation(0)),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    for (final MapEntry(key: path, value: ratio) in _targets.entries) {
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  });
}
