// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Saves files to the user's Downloads folder without asking where, into a
/// "d0b0 chat" folder.
///
/// On iOS there is no shared Downloads folder, so files go to the app's
/// documents folder, which the Files app shows as "d0b0 chat".
abstract class DownloadsSaver {
  static const String folder = 'd0b0 chat';

  static const MethodChannel _channel = MethodChannel('lv.d0b0.chat/downloads');

  /// Copies [file] to the Downloads folder as [name]. Returns false if
  /// permission was denied.
  static Future<bool> save(File file, String name, String? mimeType) async {
    name = name.replaceAll(RegExp(r'[/\\]'), '_');
    if (PlatformInfos.isAndroid) {
      // Android 9 and older need the storage permission, which Gal asks for.
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) return false;
      await _channel.invokeMethod<String>('save', {
        'path': file.path,
        'name': name,
        'mimeType': mimeType,
        'folder': folder,
      });
      return true;
    }
    final Directory directory;
    if (PlatformInfos.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) return false;
      directory = Directory('${downloads.path}/$folder');
    }
    await directory.create(recursive: true);
    await file.copy(await _uniquePath(directory, name));
    return true;
  }

  /// Appends " (1)", " (2)", … before the extension until the name is free.
  static Future<String> _uniquePath(Directory directory, String name) async {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var path = '${directory.path}/$name';
    for (var i = 1; await File(path).exists(); i++) {
      path = '${directory.path}/$base ($i)$extension';
    }
    return path;
  }
}
