// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Settings are grouped cards with plain-language labels. A group starts
/// with a Mint overline label.
class D0b0SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const D0b0SectionLabel(this.label, {this.trailing, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: D0b0Type.overline.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A Moss card (radius 28) holding rows, with hairlines inset to the text.
class D0b0SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const D0b0SettingsGroup({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (final (i, child) in children.indexed) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),
        );
      }
      rows.add(child);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D0b0Radius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: .min, children: rows),
        ),
      ),
    );
  }
}

/// A row in a settings group: 56 high, or 72 with a description. The icon
/// is text-2; rows that open a page end in a chevron. Destructive rows are
/// Coral and sit alone at the bottom.
class D0b0SettingsTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  /// Marks the page that is open next to the list on wide windows.
  final bool selected;

  const D0b0SettingsTile({
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = this.subtitle;
    final icon = this.icon;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    return Material(
      color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.surfaceContainerHigh,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (leading != null)
                  SizedBox(width: 40, child: leading)
                else if (icon != null)
                  SizedBox(
                    width: 40,
                    child: Icon(
                      icon,
                      size: 22,
                      color: destructive
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        title,
                        style: D0b0Type.body.copyWith(color: foreground),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: D0b0Type.bodyS.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: trailing,
                  ),
                if (chevron)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Symbols.chevron_right_rounded,
                      size: 20,
                      color: theme.d0b0.text3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row with a switch: Mint when on, an outline when off. The
/// whole row toggles.
class D0b0SwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const D0b0SwitchTile({
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: D0b0SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
