// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

IconData _getIconFromName(String displayname) {
  final name = displayname.toLowerCase();
  if ({'android'}.any(name.contains)) {
    return Symbols.phone_android_rounded;
  }
  if ({'ios', 'ipad', 'iphone', 'ipod'}.any(name.contains)) {
    return Symbols.phone_iphone_rounded;
  }
  if ({
    'web',
    'http://',
    'https://',
    'firefox',
    'chrome',
    '/_matrix',
    'safari',
    'opera',
  }.any(name.contains)) {
    return Symbols.web_rounded;
  }
  if ({'desktop', 'windows', 'macos', 'linux', 'ubuntu'}.any(name.contains)) {
    return Symbols.desktop_mac_rounded;
  }
  return Symbols.device_unknown_rounded;
}

extension DeviceExtension on Device {
  String get displayname =>
      (displayName?.isNotEmpty ?? false) ? displayName! : 'Unknown device';

  IconData get icon => _getIconFromName(displayname);
}

extension DeviceKeysExtension on DeviceKeys {
  String get displayname => (deviceDisplayName?.isNotEmpty ?? false)
      ? deviceDisplayName!
      : 'Unknown device';

  IconData get icon => _getIconFromName(displayname);
}
