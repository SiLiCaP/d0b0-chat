// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_list_tile.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_title.dart';
import 'package:fluffychat/pages/chat/chat_event_list.dart';
import 'package:fluffychat/pages/chat/pinned_events.dart';
import 'package:fluffychat/pages/chat/reply_display.dart';
import 'package:fluffychat/utils/account_config.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/matrix_live_kit_call.dart';
import 'package:fluffychat/widgets/chat_settings_popup_menu.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import '../../utils/stream_extension.dart';
import 'chat_emoji_picker.dart';
import 'chat_input_row.dart';

enum _EventContextAction { info, report }

class ChatView extends StatelessWidget {
  final ChatController controller;

  const ChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveGroupCall = controller.room.hasActiveMatrixRtcCall;

    const bottomSheetPadding = 16.0;
    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    final accountConfig = Matrix.of(context).client.applicationAccountConfig;

    return PopScope(
      canPop:
          controller.selectedEvents.isEmpty &&
          !controller.showEmojiPicker &&
          controller.activeThreadId == null,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (controller.selectedEvents.isNotEmpty) {
          controller.clearSelectedEvents();
        } else if (controller.showEmojiPicker) {
          controller.emojiPickerAction();
        } else if (controller.activeThreadId != null) {
          controller.closeThread();
        }
      },
      child: StreamBuilder(
        stream: controller.room.client.onRoomState.stream
            .where((update) => update.roomId == controller.room.id)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, snapshot) => FutureBuilder(
          future: controller.loadTimelineFuture,
          builder: (BuildContext context, snapshot) {
            var appbarBottomHeight = 0.0;
            final activeThreadId = controller.activeThreadId;
            if (activeThreadId != null) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            if (controller.room.pinnedEventIds.isNotEmpty &&
                activeThreadId == null) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            if (scrollUpBannerEventId != null && activeThreadId == null) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            // App bars are opaque Night; the selection bar is the only Deep
            // one, so selection mode is unmistakable.
            final selectionColors = theme.d0b0;
            return Scaffold(
              key: Key('chat_page'),
              appBar: AppBar(
                toolbarHeight: 64,
                shape: Border(
                  bottom: BorderSide(
                    color: controller.selectMode
                        ? selectionColors.brand
                        : theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                iconTheme: IconThemeData(
                  color: controller.selectMode
                      ? selectionColors.onBrand
                      : theme.colorScheme.onSurface,
                ),
                actionsIconTheme: IconThemeData(
                  color: controller.selectMode
                      ? selectionColors.onBrand
                      : theme.colorScheme.onSurface,
                ),
                backgroundColor: controller.selectMode
                    ? selectionColors.brand
                    : theme.colorScheme.surface,
                systemOverlayStyle: controller.selectMode
                    ? theme.appBarTheme.systemOverlayStyle?.copyWith(
                        statusBarIconBrightness: Brightness.light,
                        statusBarBrightness: Brightness.dark,
                      )
                    : null,
                automaticallyImplyLeading: false,
                leadingWidth: 56,
                leading: controller.selectMode
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton(
                          icon: const Icon(Symbols.close_rounded),
                          onPressed: controller.clearSelectedEvents,
                          tooltip: L10n.of(context).close,
                          color: selectionColors.onBrand,
                        ),
                      )
                    : activeThreadId != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton(
                          icon: const Icon(Symbols.close_rounded),
                          onPressed: controller.closeThread,
                          tooltip: L10n.of(context).backToMainChat,
                        ),
                      )
                    : FluffyThemes.isColumnMode(context)
                    ? null
                    : const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: BackButton(),
                      ),
                titleSpacing: FluffyThemes.isColumnMode(context) ? 24 : 4,
                title: ChatAppBarTitle(controller),
                actions: [
                  if (controller.selectMode) ...[
                    if (controller.selectedEvents.length == 1 &&
                        controller.selectedEvents.single.status.isSent &&
                        controller.room.canSendDefaultMessages)
                      IconButton(
                        icon: const Icon(Symbols.reply_rounded),
                        tooltip: L10n.of(context).reply,
                        onPressed: controller.replyAction,
                      ),
                    IconButton(
                      icon: const Icon(Symbols.content_copy_rounded),
                      tooltip: L10n.of(context).copyText,
                      onPressed: controller.copyEventsAction,
                    ),
                    if (controller.canEditSelectedEvents)
                      IconButton(
                        icon: const Icon(Symbols.edit_rounded),
                        tooltip: L10n.of(context).edit,
                        onPressed: controller.editSelectedEventAction,
                      ),
                    if (controller.canRedactSelectedEvents)
                      IconButton(
                        icon: const Icon(Symbols.delete_rounded),
                        tooltip: L10n.of(context).delete,
                        onPressed: controller.redactEventsAction,
                      )
                    else if (controller.selectedEvents.every(
                      (event) => event.status.isError,
                    ))
                      IconButton(
                        icon: const Icon(Symbols.delete_rounded),
                        tooltip: L10n.of(context).delete,
                        onPressed: controller.deleteErrorEventsAction,
                      ),
                    PopupMenuButton<_EventContextAction>(
                      useRootNavigator: true,
                      icon: const Icon(Symbols.more_vert_rounded),
                      onSelected: (action) {
                        switch (action) {
                          case _EventContextAction.info:
                            controller.showEventInfo();
                            controller.clearSelectedEvents();
                            break;
                          case _EventContextAction.report:
                            controller.reportEventAction();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: controller.forwardEventsAction,
                          value: null,
                          child: Row(
                            mainAxisSize: .min,
                            children: [
                              const Icon(Symbols.forward_rounded),
                              const SizedBox(width: 12),
                              Text(L10n.of(context).forward),
                            ],
                          ),
                        ),
                        if (controller.selectedEvents.length == 1 &&
                            controller.activeThreadId == null &&
                            controller.room.canSendDefaultMessages)
                          PopupMenuItem(
                            onTap: () => controller.enterThread(
                              controller.selectedEvents.single.eventId,
                            ),
                            value: null,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                const Icon(Symbols.forum_rounded),
                                const SizedBox(width: 12),
                                Text(L10n.of(context).replyInThread),
                              ],
                            ),
                          ),
                        if (controller.canPinSelectedEvents)
                          PopupMenuItem(
                            onTap: controller.pinEvent,
                            value: null,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                const Icon(Symbols.keep_rounded),
                                const SizedBox(width: 12),
                                Text(L10n.of(context).pinMessage),
                              ],
                            ),
                          ),
                        if (controller.canSaveSelectedEvent)
                          PopupMenuItem(
                            onTap: () => controller.saveSelectedEvent(context),
                            value: null,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                const Icon(Symbols.download_rounded),
                                const SizedBox(width: 12),
                                Text(L10n.of(context).downloadFile),
                                if (controller.selectedEventSizeString
                                    case final size?)
                                  Text(' ($size)'),
                              ],
                            ),
                          ),
                        if (controller.selectedEvents.length == 1)
                          PopupMenuItem(
                            value: _EventContextAction.info,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                const Icon(Symbols.info_rounded),
                                const SizedBox(width: 12),
                                Text(L10n.of(context).messageInfo),
                              ],
                            ),
                          ),
                        if (controller.selectedEvents.length == 1 &&
                            controller.selectedEvents.single.status.isSent)
                          PopupMenuItem(
                            value: _EventContextAction.report,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                Icon(
                                  Symbols.flag_rounded,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Text(L10n.of(context).reportMessage),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ] else if (!controller.room.isArchived) ...[
                    if (hasActiveGroupCall)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: TextButton.icon(
                          icon: Icon(
                            switch (controller.room.activeMatrixRtcCallIntent) {
                              .voice => Symbols.video_call_rounded,
                              _ => Symbols.mic_rounded,
                            },
                          ),
                          label: Text(
                            controller.room
                                .getActiveMatrixRtcMembers()
                                .length
                                .toString(),
                          ),
                          onPressed:
                              controller.room.hasPermissionForMatrixRtcCall
                              ? controller.startOrJoinVideoCall
                              : null,
                          style: TextButton.styleFrom(
                            backgroundColor: selectionColors.brand,
                            foregroundColor: selectionColors.onBrand,
                          ),
                        ),
                      )
                    else if (controller.room.hasPermissionForMatrixRtcCall &&
                        controller.supportLiveKitCalls)
                      IconButton(
                        icon: Icon(Symbols.call_rounded),
                        tooltip: L10n.of(context).startCall,
                        onPressed: controller.startOrJoinVideoCall,
                      ),
                    ChatSettingsPopupMenu(controller.room, true),
                    const SizedBox(width: 4),
                  ],
                ],
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(appbarBottomHeight),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      PinnedEvents(controller),
                      if (activeThreadId != null)
                        SizedBox(
                          height: ChatAppBarListTile.fixedHeight,
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () =>
                                  controller.scrollToEventId(activeThreadId),
                              icon: const Icon(Symbols.message_rounded),
                              label: Text(L10n.of(context).replyInThread),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    theme.colorScheme.onSecondaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (scrollUpBannerEventId != null &&
                          activeThreadId == null)
                        ChatAppBarListTile(
                          leading: IconButton(
                            color: theme.colorScheme.onSurfaceVariant,
                            icon: const Icon(Symbols.close_rounded),
                            tooltip: L10n.of(context).close,
                            onPressed: () {
                              controller.discardScrollUpBannerEventId();
                              controller.setReadMarker();
                            },
                          ),
                          title: L10n.of(context).jumpToLastReadMessage,
                          trailing: TextButton(
                            onPressed: () {
                              controller.scrollToEventId(scrollUpBannerEventId);
                              controller.discardScrollUpBannerEventId();
                            },
                            child: Text(L10n.of(context).jump),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              floatingActionButton:
                  controller.showScrollDownButton &&
                      controller.selectedEvents.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: theme.appBarTheme.toolbarHeight ?? 56,
                      ),
                      child: FloatingActionButton(
                        onPressed: controller.scrollDown,
                        heroTag: null,
                        mini: true,
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                        child: const Icon(Symbols.arrow_downward_rounded),
                      ),
                    )
                  : null,
              body: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (SizeChangedLayoutNotification notification) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => controller.updateInputBarHeight(),
                  );
                  return true;
                },
                child: DropTarget(
                  onDragDone: controller.onDragDone,
                  onDragEntered: controller.onDragEntered,
                  onDragExited: controller.onDragExited,
                  child: SafeArea(
                    top: false,
                    child: Stack(
                      children: <Widget>[
                        if (accountConfig.wallpaperUrl != null)
                          Opacity(
                            opacity: accountConfig.wallpaperOpacity ?? 0.5,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: accountConfig.wallpaperBlur ?? 0.0,
                                sigmaY: accountConfig.wallpaperBlur ?? 0.0,
                              ),
                              child: MxcImage(
                                cacheKey: accountConfig.wallpaperUrl.toString(),
                                uri: accountConfig.wallpaperUrl,
                                fit: BoxFit.cover,
                                height: MediaQuery.sizeOf(context).height,
                                width: MediaQuery.sizeOf(context).width,
                                isThumbnail: false,
                                placeholder: (_) => Container(),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: controller.clearSingleSelectedEvent,
                          child: ChatEventList(controller: controller),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SizeChangedLayoutNotifier(
                            child: Container(
                              key: controller.inputBarKey,
                              color: theme.colorScheme.surface,
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: bottomSheetPadding,
                                  vertical: 12,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: FluffyThemes.maxTimelineWidth,
                                ),
                                child: controller.room.isExtinct
                                    ? ElevatedButton.icon(
                                        icon: const Icon(
                                          Symbols.chevron_right_rounded,
                                        ),
                                        label: Text(
                                          L10n.of(context).enterNewChat,
                                        ),
                                        onPressed: controller.goToNewRoomAction,
                                      )
                                    : !controller.room.canSendDefaultMessages &&
                                          controller.room.membership !=
                                              Membership.invite
                                    ? const SizedBox.shrink()
                                    // Selection mode moves every action into
                                    // the bar, so the composer goes away.
                                    : controller.selectMode
                                    ? const SizedBox.shrink()
                                    : Material(
                                        clipBehavior: Clip.hardEdge,
                                        color:
                                            controller.room.membership ==
                                                    .invite ||
                                                controller
                                                        .room
                                                        .isAbandonedDMRoom ==
                                                    true
                                            ? theme.colorScheme.surfaceContainer
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          D0b0Radius.card,
                                        ),
                                        child:
                                            controller.room.membership ==
                                                .invite
                                            ? Row(
                                                children: [
                                                  Expanded(
                                                    child: TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        foregroundColor: theme
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                      icon: const Icon(
                                                        Symbols.cancel_rounded,
                                                      ),
                                                      onPressed:
                                                          controller.leaveChat,
                                                      label: Text(
                                                        L10n.of(
                                                          context,
                                                        ).decline,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                      ),
                                                      icon: const Icon(
                                                        Symbols.check_rounded,
                                                      ),
                                                      onPressed:
                                                          controller.joinChat,
                                                      label: Text(
                                                        L10n.of(context).accept,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : controller
                                                      .room
                                                      .isAbandonedDMRoom ==
                                                  true
                                            ? Row(
                                                children: [
                                                  Expanded(
                                                    child: TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        foregroundColor: theme
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                      icon: const Icon(
                                                        Symbols.archive_rounded,
                                                      ),
                                                      onPressed:
                                                          controller.leaveChat,
                                                      label: Text(
                                                        L10n.of(context).leave,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                      ),
                                                      icon: const Icon(
                                                        Symbols.forum_rounded,
                                                      ),
                                                      onPressed: controller
                                                          .recreateChat,
                                                      label: Text(
                                                        L10n.of(
                                                          context,
                                                        ).reopenChat,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                mainAxisSize: .min,
                                                children: [
                                                  ReplyDisplay(controller),
                                                  ChatInputRow(controller),
                                                  ChatEmojiPicker(controller),
                                                ],
                                              ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        if (controller.dragging)
                          Container(
                            color: theme.scaffoldBackgroundColor.withAlpha(230),
                            alignment: Alignment.center,
                            child: const Icon(
                              Symbols.upload_rounded,
                              size: 100,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
