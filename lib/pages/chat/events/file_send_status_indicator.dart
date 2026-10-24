// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class FileSendStatusIndicator extends StatelessWidget {
  final FileSendingStatus fileSendingStatus;
  const FileSendStatusIndicator({super.key, required this.fileSendingStatus});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      child: Stack(
        alignment: Alignment.center,
        children: [
          switch (fileSendingStatus) {
            FileSendingStatus.generatingThumbnail => Icon(
              Symbols.compress_rounded,
              size: 18,
            ),
            FileSendingStatus.encrypting => Icon(
              Symbols.lock_rounded,
              size: 18,
            ),
            FileSendingStatus.uploading => Icon(
              Symbols.upload_rounded,
              size: 18,
            ),
          },
          const CircularProgressIndicator(strokeWidth: 3),
        ],
      ),
    );
  }
}
