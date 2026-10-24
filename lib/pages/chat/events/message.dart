// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/lift.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/member_actions_popup_menu_button.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:swipe_to_action/swipe_to_action.dart';

import 'bubble.dart';
import 'message_content.dart';
import 'message_reactions.dart';
import 'reply_content.dart';
import 'state_message.dart';

class Message extends StatelessWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final void Function(Event) onSelect;
  final void Function(Event) onInfoTab;
  final void Function(String) scrollToEventId;
  final void Function() onSwipe;
  final void Function() onMention;
  final void Function() onEdit;
  final void Function(String eventId)? enterThread;
  final bool longPressSelect;
  final bool selected;
  final bool singleSelected;
  final Timeline timeline;
  final bool highlightMarker;
  final bool animateIn;
  final bool wallpaperMode;
  final ScrollController scrollController;

  /// Someone else has read up to here; shown as 'read' on own messages.
  final bool read;

  /// Long-press (or right-click) opens the message actions.
  /// Long-press, right-click or the hover pill: with a copy of the bubble
  /// to lift on touch, or where to anchor the menu on wide screens.
  final void Function(Event event, {LiftedBubble? lifted, Rect? anchor})
  onLongPress;
  final void Function()? onExpand;
  final bool isCollapsed;
  final Set<String> bigEmojis;

  const Message(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.longPressSelect = false,
    required this.bigEmojis,
    required this.onSelect,
    required this.onInfoTab,
    required this.scrollToEventId,
    required this.onSwipe,
    this.selected = false,
    required this.onEdit,
    required this.singleSelected,
    required this.timeline,
    this.highlightMarker = false,
    this.animateIn = false,
    this.wallpaperMode = false,
    required this.onMention,
    required this.scrollController,
    required this.onLongPress,
    this.read = false,
    this.onExpand,
    required this.enterThread,
    this.isCollapsed = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!{
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.CallInvite,
      PollEventContent.startType,
    }.contains(event.type)) {
      if (event.type.startsWith('m.call.')) {
        return const SizedBox.shrink();
      }
      return StateMessage(event, onExpand: onExpand, isCollapsed: isCollapsed);
    }

    if (event.type == EventTypes.Message &&
        event.messageType == EventTypes.KeyVerificationRequest) {
      return StateMessage(event);
    }

    final client = Matrix.of(context).client;
    final colors = theme.d0b0;
    final l10n = L10n.of(context);
    final ownMessage = event.senderId == client.userID;
    final isGroup = !event.room.isDirectChat;

    // Events are newest first: nextEvent is the older one above, previousEvent
    // the newer one below.
    final nextEventSameSender =
        nextEvent != null &&
        {EventTypes.Message, EventTypes.Sticker}.contains(nextEvent!.type) &&
        nextEvent!.senderId == event.senderId &&
        nextEvent!.originServerTs.sameEnvironment(event.originServerTs);

    final previousEventSameSender =
        previousEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
        }.contains(previousEvent!.type) &&
        previousEvent!.senderId == event.senderId &&
        previousEvent!.originServerTs.sameEnvironment(event.originServerTs);

    // Grouping does the work ticks and timestamps used to do: the stem on
    // the first bubble, one meta line after the last.
    final firstInGroup = !nextEventSameSender;
    final lastInGroup = !previousEventSameSender;

    final displayEvent = event.getDisplayEvent(timeline);
    final noBubble =
        ({
          MessageTypes.Video,
          MessageTypes.Image,
          MessageTypes.Sticker,
        }.contains(event.messageType) &&
        event.fileDescription == null &&
        !event.redacted);

    final bubbleState = event.redacted
        ? BubbleState.deleted
        : ownMessage && displayEvent.status.isError
        ? BubbleState.error
        : ownMessage && displayEvent.status.isSending
        ? BubbleState.sending
        : noBubble
        ? BubbleState.bare
        : BubbleState.sent;

    final textColor = switch (bubbleState) {
      BubbleState.sending => theme.colorScheme.primary,
      BubbleState.deleted => colors.text3,
      BubbleState.error => theme.colorScheme.onSurface,
      _ => ownMessage ? colors.onBubbleMine : colors.onBubbleTheirs,
    };
    final linkColor = theme.colorScheme.primary;

    final hasReactions = event.hasAggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );
    final threadChildren = event.aggregatedEvents(
      timeline,
      RelationshipTypes.thread,
    );
    final isEdited = event.hasAggregatedEvents(
      timeline,
      RelationshipTypes.edit,
    );

    final enterThread = this.enterThread;
    final sender = event.senderFromMemoryOrFallback;
    // Hovering a bubble shows a small action pill beside its top edge,
    // toward the centre of the pane.
    final showHoverPill =
        !PlatformInfos.isMobile &&
        !longPressSelect &&
        event.status.isSent &&
        !event.redacted;
    final showAvatar = isGroup && !ownMessage;
    const avatarSize = 32.0;
    const avatarGap = 8.0;

    final metaStyle = D0b0Type.monoS.copyWith(color: colors.text3);
    final meta = <String>[
      if (event.status.isSent) event.originServerTs.localizedTimeOfDay(context),
      if (isEdited) l10n.editedLabel,
      if (event.status.isSending)
        switch (event.fileSendingStatus) {
          null => l10n.sendingEllipsis,
          FileSendingStatus.generatingThumbnail => l10n.generatingThumbnail,
          FileSendingStatus.encrypting => l10n.encrypting,
          FileSendingStatus.uploading => l10n.uploading,
        },
      if (ownMessage && read && event.status.isSent) l10n.readLabel,
    ];

    Future<void> doubleTapReact() async {
      HapticFeedback.lightImpact();
      final emoji = AppSettings.doubleTapReaction.value;
      final existingReaction = event
          .aggregatedEvents(timeline, RelationshipTypes.reaction)
          .firstWhereOrNull(
            (e) =>
                e.senderId == event.room.client.userID &&
                e.content
                        .tryGetMap<String, Object?>('m.relates_to')
                        ?.tryGet<String>('key') ==
                    emoji,
          );
      if (existingReaction != null) {
        await existingReaction.redactEvent();
      } else {
        await event.room.sendReaction(event.eventId, emoji);
      }
    }

    final bubble = D0b0Bubble(
      mine: ownMessage,
      firstInGroup: firstInGroup,
      state: bubbleState,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (event.inReplyToEventId(includingFallback: false) != null &&
              !event.redacted)
            FutureBuilder<Event?>(
              future: event.getReplyEvent(timeline),
              builder: (BuildContext context, snapshot) {
                final replyEvent = snapshot.hasData
                    ? snapshot.data!
                    : Event(
                        eventId: event.inReplyToEventId() ?? '\$fake_event_id',
                        content: {'msgtype': 'm.text', 'body': '...'},
                        senderId: event.senderId,
                        type: 'm.room.message',
                        room: event.room,
                        status: EventStatus.sent,
                        originServerTs: DateTime.now(),
                      );
                return Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 11),
                  child: InkWell(
                    borderRadius: ReplyContent.borderRadius,
                    onTap: () => scrollToEventId(replyEvent.eventId),
                    child: AbsorbPointer(
                      child: ReplyContent(
                        replyEvent,
                        ownMessage: ownMessage,
                        timeline: timeline,
                      ),
                    ),
                  ),
                );
              },
            ),
          MessageContent(
            displayEvent,
            textColor: textColor,
            linkColor: linkColor,
            onInfoTab: onInfoTab,
            borderRadius: D0b0Bubble.borderRadius(
              mine: ownMessage,
              firstInGroup: firstInGroup,
            ),
            timeline: timeline,
            selected: selected,
            bigEmojis: bigEmojis,
          ),
        ],
      ),
    );

    return Center(
      child: Swipeable(
        key: ValueKey(event.transactionId ?? event.eventId),
        background: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: AppSettings.swipeRightToLeftToReply.value
                ? .centerRight
                : .centerLeft,
            child: Icon(
              Symbols.reply_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        direction: AppSettings.swipeRightToLeftToReply.value
            ? SwipeDirection.endToStart
            : SwipeDirection.startToEnd,
        onSwipe: (_) {
          HapticFeedback.lightImpact();
          onSwipe();
        },
        child: Material(
          color: selected || highlightMarker
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.transparent,
          child: InkWell(
            hoverColor: longPressSelect ? Colors.transparent : null,
            onTap: longPressSelect ? () => onSelect(event) : null,
            onLongPress: longPressSelect
                ? () => onSelect(event)
                : () {
                    HapticFeedback.lightImpact();
                    onLongPress(event, lifted: LiftedBubble.capture(context));
                  },
            onSecondaryTapUp: longPressSelect
                ? null
                : (details) => onLongPress(
                    event,
                    anchor: details.globalPosition & Size.zero,
                  ),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: FluffyThemes.maxTimelineWidth,
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 2,
                bottom: lastInGroup ? 14 : 2,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Bubbles keep the width of a phone layout and cap at 520.
                  // Pointer devices keep room for the hover pill beside it.
                  final maxBubbleWidth = min(
                    D0b0Room.maxBubbleWidth,
                    constraints.maxWidth -
                        58 -
                        (showHoverPill ? _HoverPill.width + 8 : 0),
                  );
                  final hoverPill = Padding(
                    padding: EdgeInsets.only(
                      top: firstInGroup && bubbleState == BubbleState.sent
                          ? D0b0Bubble.stemSpace
                          : 0,
                      left: ownMessage ? 0 : 8,
                      right: ownMessage ? 8 : 0,
                    ),
                    child: _HoverPill(
                      onReact: (anchor) => onLongPress(event, anchor: anchor),
                      onReply: onSwipe,
                      onMore: (anchor) => onLongPress(event, anchor: anchor),
                    ),
                  );
                  final selectOffset = longPressSelect ? 40.0 : 0.0;
                  final leadingOffset =
                      selectOffset + (showAvatar ? avatarSize + avatarGap : 0);
                  return Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: ownMessage ? .end : .start,
                    children: <Widget>[
                      if (showAvatar && firstInGroup)
                        Padding(
                          padding: EdgeInsets.only(
                            left: leadingOffset + 2,
                            bottom: 4,
                          ),
                          child: Text(
                            sender.calcDisplayname(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: D0b0Type.label.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      HoverBuilder(
                        builder: (context, hovered) => Row(
                          crossAxisAlignment: .start,
                          mainAxisAlignment: ownMessage ? .end : .start,
                          children: [
                            if (longPressSelect)
                              SizedBox(
                                width: 40,
                                height: 45,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Icon(
                                    selected
                                        ? Symbols.check_circle_rounded
                                        : Symbols
                                              .radio_button_unchecked_rounded,
                                    fill: selected ? 1 : 0,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    semanticLabel: l10n.select,
                                  ),
                                ),
                              ),
                            if (ownMessage && longPressSelect) const Spacer(),
                            if (showAvatar)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: firstInGroup ? D0b0Bubble.stemSpace : 0,
                                  right: avatarGap,
                                ),
                                child: firstInGroup
                                    ? FutureBuilder<User?>(
                                        future: event.fetchSenderUser(),
                                        builder: (context, snapshot) {
                                          final user = snapshot.data ?? sender;
                                          return Avatar(
                                            mxContent: user.avatarUrl,
                                            name: user.calcDisplayname(),
                                            toneSeed: user.id,
                                            size: avatarSize,
                                            onTap: () =>
                                                showMemberActionsPopupMenu(
                                                  context: context,
                                                  user: user,
                                                  onMention: onMention,
                                                ),
                                          );
                                        },
                                      )
                                    : const SizedBox(width: avatarSize),
                              ),
                            if (ownMessage && hovered) hoverPill,
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxBubbleWidth,
                              ),
                              child: GestureDetector(
                                onDoubleTap:
                                    !longPressSelect &&
                                        AppSettings.doubleTapToReact.value &&
                                        event.room.canSendDefaultMessages
                                    ? doubleTapReact
                                    : null,
                                child: _AnimateIn(
                                  key: ValueKey(
                                    event.transactionId ?? event.eventId,
                                  ),
                                  animateIn: animateIn,
                                  child: LiftSource(child: bubble),
                                ),
                              ),
                            ),
                            if (!ownMessage && hovered) hoverPill,
                          ],
                        ),
                      ),
                      if (hasReactions)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            left: ownMessage ? 0 : leadingOffset,
                          ),
                          child: MessageReactions(event, timeline),
                        ),
                      if (enterThread != null && threadChildren.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            left: ownMessage ? 0 : leadingOffset,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxBubbleWidth,
                            ),
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                foregroundColor: theme.colorScheme.primary,
                              ),
                              onPressed: () => enterThread(event.eventId),
                              icon: const Icon(Symbols.forum_rounded, size: 18),
                              label: Text(
                                '${l10n.countReplies(threadChildren.length)} · ${threadChildren.first.calcLocalizedBodyFallback(MatrixLocals(l10n), withSenderNamePrefix: true)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      if (lastInGroup || event.status.isError)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            left: ownMessage ? 0 : leadingOffset + 8,
                            right: ownMessage ? 8 : 0,
                          ),
                          child: event.status.isError
                              ? Text(
                                  l10n.couldNotBeSent,
                                  style: metaStyle.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                )
                              : Text(meta.join(' · '), style: metaStyle),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// react · reply · more, shown while a pointer hovers a bubble.
class _HoverPill extends StatelessWidget {
  /// Open the actions, anchored to the pill.
  final void Function(Rect? anchor) onReact;
  final VoidCallback onReply;
  final void Function(Rect? anchor) onMore;

  const _HoverPill({
    required this.onReact,
    required this.onReply,
    required this.onMore,
  });

  static const double width = 3 * 36 + 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: 20,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(36),
            fixedSize: const Size.square(36),
            padding: EdgeInsets.zero,
            foregroundColor: scheme.onSurfaceVariant,
          ),
          icon: Icon(icon),
        );
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainer,
        shape: StadiumBorder(
          side: BorderSide(color: scheme.outline, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          button(
            Symbols.add_reaction_rounded,
            l10n.customReaction,
            () => onReact(d0b0AnchorOf(context)),
          ),
          button(Symbols.reply_rounded, l10n.reply, onReply),
          button(
            Symbols.more_vert_rounded,
            l10n.more,
            () => onMore(d0b0AnchorOf(context)),
          ),
        ],
      ),
    );
  }
}

/// Room layout constants shared by the timeline and the composer.
abstract class D0b0Room {
  /// Bubbles cap at 520 on wide windows.
  static const double maxBubbleWidth = 520;
}

/// '2 new' marks where unread messages start: an outline pill on a hairline
/// (outline = not yet read).
class NewMessagesMarker extends StatelessWidget {
  final int count;

  const NewMessagesMarker({required this.count, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outline)),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: scheme.surface,
              shape: StadiumBorder(
                side: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
            child: Text(
              L10n.of(context).countNew(count),
              style: D0b0Type.label.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: scheme.primary,
              ),
            ),
          ),
          Expanded(child: Divider(color: scheme.outline)),
        ],
      ),
    );
  }
}

class _AnimateIn extends StatefulWidget {
  final bool animateIn;
  final Widget child;
  const _AnimateIn({required this.animateIn, required this.child, super.key});

  @override
  State<_AnimateIn> createState() => __AnimateInState();
}

class __AnimateInState extends State<_AnimateIn> {
  bool _animationFinished = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.animateIn) return widget.child;
    if (!_animationFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _animationFinished = true;
        });
      });
    }

    return AnimatedSize(
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      child: _animationFinished ? widget.child : const SizedBox.shrink(),
    );
  }
}
