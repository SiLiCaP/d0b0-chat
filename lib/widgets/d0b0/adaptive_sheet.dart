// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:material_ui/material_ui.dart';

/// Sheets are for choices. On phones they rise from the bottom and settle
/// with the overshoot curve; from expanded windows up they open as a
/// centred panel, max 400 wide, on the same surface.
Future<T?> showD0b0Sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  if (FluffyThemes.isColumnMode(context)) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: builder(context),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    sheetAnimationStyle: const AnimationStyle(
      duration: D0b0Motion.move,
      curve: D0b0Motion.overshoot,
      reverseDuration: D0b0Motion.state,
      reverseCurve: D0b0Motion.exit,
    ),
    builder: builder,
  );
}
