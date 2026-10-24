// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A row in a sheet.
///
/// Choices (the New sheet) are 64 high with a 40 icon tile, a subtitle and
/// a description. Plain items (the account sheet) are 52 high with a bare
/// icon in text-2.
class D0b0SheetRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// The one primary choice of a sheet gets a Mint icon tile.
  final bool primary;

  /// Destructive rows are Coral.
  final bool destructive;

  /// A 52 high item with a bare icon instead of a 64 high choice.
  final bool plain;

  const D0b0SheetRow({
    this.icon,
    this.leading,
    required this.title,
    this.description,
    this.onTap,
    this.trailing,
    this.primary = false,
    this.destructive = false,
    this.plain = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = this.description;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final icon = this.icon;
    final Widget? leading;
    if (this.leading != null) {
      leading = this.leading;
    } else if (icon == null) {
      leading = null;
    } else if (plain) {
      leading = Icon(
        icon,
        size: 22,
        color: destructive ? scheme.error : scheme.onSurfaceVariant,
      );
    } else {
      leading = Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? scheme.primary : scheme.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: primary
              ? scheme.onPrimary
              : destructive
              ? scheme.error
              : scheme.onSurface,
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      hoverColor: scheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: plain ? 52 : 64),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: plain ? 4 : 8,
          ),
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
                      style: (plain ? D0b0Type.body : D0b0Type.subtitle)
                          .copyWith(color: foreground),
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
