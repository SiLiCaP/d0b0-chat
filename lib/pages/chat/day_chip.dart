// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:material_ui/material_ui.dart';

/// A day: a Moss pill, label at 12 in text-2. Inline it opens a run of
/// messages; [floating] is the copy that stays at the top while scrolling.
class DayChip extends StatelessWidget {
  final DateTime date;
  final bool floating;

  const DayChip({required this.date, this.floating = false, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: floating
          ? const EdgeInsets.only(top: 8)
          : const EdgeInsets.only(top: 8, bottom: 12),
      child: Center(
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            // Over messages the pill needs an edge to stay readable.
            color: floating
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainer,
            shape: StadiumBorder(
              side: floating
                  ? BorderSide(color: scheme.outline)
                  : BorderSide.none,
            ),
          ),
          // widthFactor keeps the pill as wide as its text; an alignment on
          // the Container would stretch it to the full width.
          child: Center(
            widthFactor: 1,
            child: Text(
              date.localizedDate(context),
              style: D0b0Type.label.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
