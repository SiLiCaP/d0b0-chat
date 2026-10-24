// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

enum HomeTab { chats, spaces, you }

/// The bottom navigation on compact windows: a floating pill, 16 from the
/// edges. The active tab is a Deep pill with its label; the others are
/// icons only, with a Signal dot for unread.
class D0b0NavPill extends StatelessWidget {
  final HomeTab current;
  final void Function(HomeTab tab) onSelect;
  final bool spacesUnread;

  const D0b0NavPill({
    required this.current,
    required this.onSelect,
    this.spacesUnread = false,
    super.key,
  });

  static const double height = 64;
  static const double margin = 16;

  /// Space the pill takes at the bottom of the screen, safe area excluded.
  static const double occupiedHeight = height + margin * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tabs = [
      (HomeTab.chats, Symbols.chat_bubble_rounded, l10n.navChats, false),
      (
        HomeTab.spaces,
        Symbols.workspaces_rounded,
        l10n.navSpaces,
        spacesUnread,
      ),
      (HomeTab.you, Symbols.tune_rounded, l10n.navYou, false),
    ];
    final index = tabs.indexWhere((tab) => tab.$1 == current);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(margin),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // The Deep pill slides to the new tab instead of fading.
                AnimatedAlign(
                  duration: D0b0Motion.move,
                  curve: D0b0Motion.standard,
                  alignment: Alignment(index - 1.0, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / tabs.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: theme.d0b0.brand,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (tab, icon, label, unread) in tabs)
                      Expanded(
                        child: _NavPillItem(
                          icon: icon,
                          label: label,
                          selected: tab == current,
                          unread: unread,
                          onTap: () => onSelect(tab),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool unread;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.d0b0.onBrand
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: selected ? '' : label,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Center(
            child: Row(
              mainAxisSize: .min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The fill axis animates with the indicator.
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: selected ? 1 : 0),
                      duration: D0b0Motion.state,
                      builder: (_, fill, _) =>
                          Icon(icon, fill: fill, color: color),
                    ),
                    if (unread && !selected)
                      Positioned(
                        top: -1,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.d0b0.signal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                // The label fades in after the pill lands.
                AnimatedSize(
                  duration: D0b0Motion.move,
                  curve: D0b0Motion.standard,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: D0b0Motion.state,
                            builder: (_, opacity, child) =>
                                Opacity(opacity: opacity, child: child),
                            child: Text(
                              label,
                              maxLines: 1,
                              style: D0b0Type.label.copyWith(color: color),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
