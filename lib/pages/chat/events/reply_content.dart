// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../../config/d0b0_theme.dart';

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool ownMessage;
  final Timeline? timeline;

  const ReplyContent(
    this.replyEvent, {
    this.ownMessage = false,
    super.key,
    this.timeline,
  });

  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final timeline = this.timeline;
    final displayEvent = timeline != null
        ? replyEvent.getDisplayEvent(timeline)
        : replyEvent;

    // Replies quote inside the bubble on a surface-high pill, the name in
    // accent and one line of text-2.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: <Widget>[
          FutureBuilder<User?>(
            initialData: displayEvent.senderFromMemoryOrFallback,
            future: displayEvent.fetchSenderUser(),
            builder: (context, snapshot) => Text(
              snapshot.data?.calcDisplayname() ??
                  displayEvent.senderFromMemoryOrFallback.calcDisplayname(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: D0b0Type.label.copyWith(
                fontSize: 13,
                letterSpacing: 0,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayEvent
                .calcLocalizedBodyFallback(
                  MatrixLocals(L10n.of(context)),
                  withSenderNamePrefix: false,
                  hideReply: true,
                  plaintextBody: true,
                )
                .trim()
                .replaceAll('\n', ' '),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: D0b0Type.bodyS.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
