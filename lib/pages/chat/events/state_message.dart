// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/utd_dialog.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class StateMessage extends StatelessWidget {
  final Event event;
  final void Function()? onExpand;
  final bool isCollapsed;
  const StateMessage(
    this.event, {
    this.onExpand,
    this.isCollapsed = false,
    super.key,
  });

  /// System events use icons, not emoji.
  static IconData _icon(Event event) {
    switch (event.type) {
      case EventTypes.RoomMember:
        return switch (event.content.tryGet<String>('membership')) {
          'join' => Symbols.person_add_rounded,
          'invite' => Symbols.person_add_rounded,
          'leave' => Symbols.person_remove_rounded,
          'ban' => Symbols.block_rounded,
          _ => Symbols.person_rounded,
        };
      case EventTypes.RoomName:
        return Symbols.edit_rounded;
      case EventTypes.RoomTopic:
        return Symbols.notes_rounded;
      case EventTypes.RoomAvatar:
        return Symbols.image_rounded;
      case EventTypes.RoomCreate:
        return Symbols.add_circle_rounded;
      case EventTypes.Encryption:
      case EventTypes.Encrypted:
        return Symbols.lock_rounded;
      case EventTypes.RoomPowerLevels:
        return Symbols.shield_rounded;
      case EventTypes.RoomPinnedEvents:
        return Symbols.keep_rounded;
      case EventTypes.CallInvite:
        return Symbols.call_rounded;
      default:
        return event.type.startsWith('m.call') ||
                event.type.startsWith('org.matrix.msc3401.call')
            ? Symbols.call_rounded
            : Symbols.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final color = theme.d0b0.text3;
    final style = D0b0Type.label.copyWith(
      fontSize: 13,
      letterSpacing: 0,
      color: color,
      decoration: event.redacted ? TextDecoration.lineThrough : null,
    );
    final undecryptable = event.type == EventTypes.Encrypted && !event.redacted;
    return AnimatedSize(
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      child: isCollapsed
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisSize: .min,
                children: [
                  Row(
                    mainAxisSize: .min,
                    children: [
                      Icon(_icon(event), size: 16, color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          undecryptable
                              ? l10n.messageNotDecryptable
                              : event.calcLocalizedBodyFallback(
                                  MatrixLocals(l10n),
                                ),
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                      ),
                      if (undecryptable)
                        IconButton(
                          tooltip: l10n.messageInfo,
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          color: color,
                          onPressed: () => UtdDialog.show(context, event),
                          icon: const Icon(Symbols.info_rounded),
                        ),
                    ],
                  ),
                  // 'More events' is a text pill, not a link.
                  if (onExpand != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TextButton(
                        onPressed: onExpand,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.colorScheme.primary,
                          textStyle: D0b0Type.label.copyWith(
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                        child: Text(l10n.moreEvents),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
