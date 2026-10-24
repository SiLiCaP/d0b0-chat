// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/new_sheet.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 56 high, Mint, no shadow. Collapses to a circle when the list scrolls
/// down and expands again on scroll up.
class StartChatFab extends StatelessWidget {
  final bool extended;
  const StartChatFab({this.extended = false, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FloatingActionButton.extended(
      heroTag: 'start_chat_fab',
      tooltip: l10n.newChat,
      onPressed: () => showNewSheet(context),
      extendedIconLabelSpacing: extended ? 8 : 0,
      extendedPadding: EdgeInsets.symmetric(horizontal: extended ? 20 : 16),
      label: AnimatedSize(
        alignment: Alignment.centerLeft,
        duration: D0b0Motion.move,
        curve: D0b0Motion.standard,
        child: extended ? Text(l10n.newChat) : const SizedBox.shrink(),
      ),
      icon: const Icon(Symbols.edit_rounded),
    );
  }
}
