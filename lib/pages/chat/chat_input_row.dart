// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/locales/default_emoji_set_locale.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/recording_input_row.dart';
import 'package:fluffychat/pages/chat/recording_view_model.dart';
import 'package:fluffychat/pages/chat/video_message/record_mode_button.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/other_party_can_receive.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/d0b0/adaptive_sheet.dart';
import 'package:fluffychat/widgets/d0b0/sheet_row.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'chat.dart';
import 'input_bar.dart';

/// The composer: '+' opens the attach sheet, the field grows line by line
/// to 6, and the trailing button swaps by state: mic when empty, send when
/// there is text, check when editing. '+' and send stay pinned to the
/// bottom.
class ChatInputRow extends StatelessWidget {
  final ChatController controller;

  static const double height = 48.0;

  const ChatInputRow(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    if (!controller.room.otherPartyCanReceiveMessages) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            l10n.otherPartyNotLoggedIn,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RecordingViewModel(
      builder: (context, recordingViewModel) {
        if (recordingViewModel.isRecording) {
          return RecordingInputRow(
            state: recordingViewModel,
            onSend: controller.onVoiceMessageSend,
          );
        }
        final isEditing = controller.editEvent != null;
        final showRecord =
            PlatformInfos.platformCanRecord &&
            controller.sendController.text.isEmpty &&
            !isEditing;
        return Row(
          crossAxisAlignment: .end,
          children: <Widget>[
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: l10n.attach,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(height),
                  side: BorderSide(color: theme.colorScheme.outline, width: 2),
                ),
                icon: const Icon(Symbols.add_rounded),
                onPressed: () =>
                    _showAttachSheet(context, d0b0AnchorOf(buttonContext)),
              ),
            ),
            const SizedBox(width: 8),
            if (Matrix.of(context).isMultiAccount &&
                Matrix.of(context).hasComplexBundles &&
                Matrix.of(context).currentBundle!.length > 1)
              SizedBox(
                height: height,
                width: 40,
                child: _ChatAccountPicker(controller),
              ),
            Expanded(
              // The focused composer shows the Mint focus ring.
              child: ListenableBuilder(
                listenable: controller.inputFocus,
                builder: (context, child) => AnimatedContainer(
                  duration: D0b0Motion.state,
                  constraints: const BoxConstraints(minHeight: height),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: controller.inputFocus.hasFocus
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: child,
                ),
                child: Row(
                  crossAxisAlignment: .end,
                  children: [
                    Expanded(
                      child: InputBar(
                        room: controller.room,
                        minLines: 1,
                        maxLines: 6,
                        autofocus: !PlatformInfos.isMobile,
                        keyboardType: TextInputType.multiline,
                        textInputAction:
                            AppSettings.sendOnEnter.value == true &&
                                PlatformInfos.isMobile
                            ? TextInputAction.send
                            : null,
                        onSubmitted: controller.onInputBarSubmitted,
                        onSubmitImage: controller.sendImageFromClipBoard,
                        focusNode: controller.inputFocus,
                        controller: controller.sendController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(
                            left: 18,
                            right: 4,
                            top: 13,
                            bottom: 13,
                          ),
                          isDense: true,
                          counter: const SizedBox.shrink(),
                          hintText:
                              (PlatformInfos.isMobile
                              ? l10n.messageRoom
                              : l10n.composerDesktopHint)(
                                controller.room.getLocalizedDisplayname(
                                  MatrixLocals(l10n),
                                ),
                              ),
                          hintMaxLines: 1,
                          hintStyle: D0b0Type.body.copyWith(
                            color: theme.d0b0.text3,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onChanged: controller.onInputBarChanged,
                        suggestionEmojis:
                            getDefaultEmojiLocale(
                              AppSettings.emojiSuggestionLocale.value.isNotEmpty
                                  ? Locale(
                                      AppSettings.emojiSuggestionLocale.value,
                                    )
                                  : Localizations.localeOf(context),
                            ).fold(
                              [],
                              (emojis, category) =>
                                  emojis..addAll(category.emoji),
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.emojis,
                      color: theme.colorScheme.onSurfaceVariant,
                      icon: Icon(
                        controller.showEmojiPicker
                            ? Symbols.keyboard_rounded
                            : Symbols.sentiment_satisfied_rounded,
                        size: 22,
                        key: ValueKey(controller.showEmojiPicker),
                      ),
                      onPressed: controller.emojiPickerAction,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: height,
              child: showRecord
                  ? RecordModeButton(
                      size: height,
                      onVoiceMessage: () =>
                          recordingViewModel.startRecording(controller.room),
                      onVideoMessage: PlatformInfos.isMobile
                          ? controller.openVideoMessageRecorder
                          : null,
                    )
                  : IconButton(
                      key: const Key('send_button'),
                      tooltip: isEditing ? l10n.edit : l10n.send,
                      onPressed: controller.send,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        minimumSize: const Size.square(height),
                      ),
                      icon: Icon(
                        isEditing
                            ? Symbols.check_rounded
                            : Symbols.arrow_upward_rounded,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAttachSheet(BuildContext context, Rect? anchor) async {
    final l10n = L10n.of(context);
    final choice = await showD0b0Sheet<AddPopupMenuActions>(
      context: context,
      anchor: anchor,
      builder: (context) {
        Widget row(AddPopupMenuActions value, IconData icon, String title) =>
            D0b0SheetRow(
              icon: icon,
              title: title,
              onTap: () => Navigator.of(context).pop(value),
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                if (PlatformInfos.isMobile) ...[
                  row(
                    AddPopupMenuActions.photoCamera,
                    Symbols.photo_camera_rounded,
                    l10n.takeAPhoto,
                  ),
                  row(
                    AddPopupMenuActions.videoCamera,
                    Symbols.videocam_rounded,
                    l10n.recordAVideo,
                  ),
                ],
                row(
                  AddPopupMenuActions.image,
                  Symbols.image_rounded,
                  l10n.sendImage,
                ),
                row(
                  AddPopupMenuActions.video,
                  Symbols.movie_rounded,
                  l10n.sendVideo,
                ),
                row(
                  AddPopupMenuActions.file,
                  Symbols.attach_file_rounded,
                  l10n.sendFile,
                ),
                if (PlatformInfos.isMobile)
                  row(
                    AddPopupMenuActions.location,
                    Symbols.location_on_rounded,
                    l10n.shareLocation,
                  ),
                row(
                  AddPopupMenuActions.poll,
                  Symbols.ballot_rounded,
                  l10n.startPoll,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null) return;
    controller.onAddPopupMenuButtonSelected(choice);
  }
}

class _ChatAccountPicker extends StatelessWidget {
  final ChatController controller;

  const _ChatAccountPicker(this.controller);

  void _popupMenuButtonSelected(String mxid, BuildContext context) {
    final client = Matrix.of(
      context,
    ).currentBundle!.firstWhere((cl) => cl!.userID == mxid, orElse: () => null);
    if (client == null) {
      Logs().w('Attempted to switch to a non-existing client $mxid');
      return;
    }
    controller.setSendingClient(client);
  }

  @override
  Widget build(BuildContext context) {
    final clients = controller.currentRoomBundle;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<Profile>(
        future: controller.sendingClient.fetchOwnProfile(),
        builder: (context, snapshot) => PopupMenuButton<String>(
          useRootNavigator: true,
          onSelected: (mxid) => _popupMenuButtonSelected(mxid, context),
          itemBuilder: (BuildContext context) => clients
              .map(
                (client) => PopupMenuItem(
                  value: client!.userID,
                  child: FutureBuilder<Profile>(
                    future: client.fetchOwnProfile(),
                    builder: (context, snapshot) => ListTile(
                      leading: Avatar(
                        mxContent: snapshot.data?.avatarUrl,
                        name:
                            snapshot.data?.displayName ??
                            client.userID!.localpart,
                        size: 20,
                      ),
                      title: Text(snapshot.data?.displayName ?? client.userID!),
                      contentPadding: const EdgeInsets.all(0),
                    ),
                  ),
                ),
              )
              .toList(),
          child: Avatar(
            mxContent: snapshot.data?.avatarUrl,
            name:
                snapshot.data?.displayName ??
                Matrix.of(context).client.userID!.localpart,
            size: 20,
          ),
        ),
      ),
    );
  }
}
