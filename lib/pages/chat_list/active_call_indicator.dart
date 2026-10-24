// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class ActiveCallIndicator extends StatelessWidget {
  final Room room;
  const ActiveCallIndicator({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).d0b0;
    // A call running here: a Deep pill with the people in it. Nothing in a
    // call is red except leaving.
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: colors.brand,
        shape: const StadiumBorder(),
      ),
      child: Row(
        spacing: 4.0,
        mainAxisSize: .min,
        children: [
          Icon(
            switch (room.activeMatrixRtcCallIntent) {
              .video => Symbols.videocam_rounded,
              _ => Symbols.call_rounded,
            },
            size: 14,
            fill: 1,
            color: colors.onBrand,
          ),
          Text(
            room.getActiveMatrixRtcMembers().length.toString(),
            style: D0b0Type.monoS.copyWith(color: colors.onBrand),
          ),
        ],
      ),
    );
  }
}
