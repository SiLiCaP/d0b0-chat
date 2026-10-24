// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A row in a sheet or settings group: 56 high, or 72 with a description.
class D0b0SheetRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// The one primary row of a sheet gets a Mint icon tile.
  final bool primary;

  /// Destructive rows are Coral.
  final bool destructive;

  const D0b0SheetRow({
    this.icon,
    this.leading,
    required this.title,
    this.description,
    this.onTap,
    this.trailing,
    this.primary = false,
    this.destructive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = this.description;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final icon = this.icon;
    final leading =
        this.leading ??
        (icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: primary
                      ? scheme.onPrimary
                      : destructive
                      ? scheme.error
                      : scheme.onSurface,
                ),
              ));
    return InkWell(
      onTap: onTap,
      hoverColor: scheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: description == null ? 56 : 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      title,
                      style: D0b0Type.body.copyWith(color: foreground),
                    ),
                    if (description != null)
                      Text(
                        description,
                        style: D0b0Type.bodyS.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
