// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'chat.dart';

/// The strip above the composer while replying or editing: a Moss pill
/// with what you are answering, and an ✕ to drop it.
class ReplyDisplay extends StatelessWidget {
  final ChatController controller;
  const ReplyDisplay(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final replyEvent = controller.replyEvent;
    final editEvent = controller.editEvent;
    final timeline = controller.timeline;

    Widget? strip;
    if (replyEvent != null || editEvent != null) {
      final event = (replyEvent ?? editEvent)!;
      final displayEvent = timeline == null
          ? event
          : event.getDisplayEvent(timeline);
      final title = replyEvent != null
          ? l10n.replyingTo(
              displayEvent.senderFromMemoryOrFallback.calcDisplayname(),
            )
          : l10n.editingMessage;
      final excerpt = displayEvent
          .calcLocalizedBodyFallback(
            MatrixLocals(l10n),
            withSenderNamePrefix: false,
            hideReply: true,
            plaintextBody: true,
          )
          .trim()
          .replaceAll('\n', ' ');
      strip = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: ShapeDecoration(
            color: theme.colorScheme.surfaceContainer,
            shape: const StadiumBorder(),
          ),
          child: Row(
            children: [
              Icon(
                replyEvent != null
                    ? Symbols.reply_rounded
                    : Symbols.edit_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.label.copyWith(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      excerpt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: D0b0Type.bodyS.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.close,
                icon: const Icon(Symbols.close_rounded),
                onPressed: controller.cancelReplyEventAction,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: D0b0Motion.move,
      curve: D0b0Motion.standard,
      clipBehavior: Clip.hardEdge,
      child: strip ?? const SizedBox.shrink(),
    );
  }
}
