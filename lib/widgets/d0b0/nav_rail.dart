// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/d0b0/d0b0_mark.dart';
import 'package:fluffychat/widgets/d0b0/nav_pill.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The navigation rail on medium windows and up: the mark, the FAB on top,
/// Chats, Spaces and You, and the account at the bottom. Replaces the
/// bottom nav pill.
class D0b0NavRail extends StatelessWidget {
  final HomeTab current;
  final void Function(HomeTab tab) onSelect;
  final bool spacesUnread;

  /// The FAB; hidden when null.
  final VoidCallback? onNewChat;

  /// The account avatar at the bottom.
  final Widget? account;

  const D0b0NavRail({
    required this.current,
    required this.onSelect,
    this.spacesUnread = false,
    this.onNewChat,
    this.account,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final onNewChat = this.onNewChat;
    final account = this.account;
    return Container(
      width: FluffyThemes.navRailWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 24),
            D0b0Mark(height: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 26),
            if (onNewChat != null)
              FloatingActionButton(
                heroTag: 'rail_new_chat',
                tooltip: l10n.newChat,
                shape: const CircleBorder(),
                onPressed: onNewChat,
                child: const Icon(Symbols.edit_rounded),
              )
            else
              const SizedBox(height: 56),
            const SizedBox(height: 36),
            _RailItem(
              icon: Symbols.chat_bubble_rounded,
              label: l10n.navChats,
              selected: current == HomeTab.chats,
              onTap: () => onSelect(HomeTab.chats),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Symbols.workspaces_rounded,
              label: l10n.navSpaces,
              selected: current == HomeTab.spaces,
              unread: spacesUnread,
              onTap: () => onSelect(HomeTab.spaces),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Symbols.tune_rounded,
              label: l10n.navYou,
              selected: current == HomeTab.you,
              onTap: () => onSelect(HomeTab.you),
            ),
            const Spacer(),
            ?account,
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool unread;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.d0b0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: FluffyThemes.navRailWidth,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: D0b0Motion.state,
                    width: 56,
                    height: 32,
                    decoration: ShapeDecoration(
                      color: selected ? colors.brand : Colors.transparent,
                      shape: const StadiumBorder(),
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: selected ? 1 : 0),
                      duration: D0b0Motion.state,
                      builder: (_, fill, _) => Icon(
                        icon,
                        fill: fill,
                        size: 22,
                        color: selected
                            ? colors.onBrand
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (unread && !selected)
                    Positioned(
                      top: 4,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.signal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: D0b0Type.label.copyWith(
                  fontSize: 12,
                  letterSpacing: 0,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
