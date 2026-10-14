// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/settings_switch_list_tile.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_chat.dart';

class SettingsChatView extends StatelessWidget {
  final SettingsChatController controller;
  const SettingsChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).chat),
        automaticallyImplyLeading: !FluffyThemes.isColumnMode(context),
        centerTitle: FluffyThemes.isColumnMode(context),
      ),
      body: ListTileTheme(
        iconColor: theme.textTheme.bodyLarge!.color,
        child: MaxWidthBody(
          child: Column(
            children: [
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).formattedMessages,
                subtitle: L10n.of(context).formattedMessagesDescription,
                setting: AppSettings.renderHtml,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideRedactedMessages,
                subtitle: L10n.of(context).hideRedactedMessagesBody,
                setting: AppSettings.hideRedactedEvents,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideRoomsInSpaces,
                setting: AppSettings.hideRoomsInSpaces,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideInvalidOrUnknownMessageFormats,
                setting: AppSettings.hideUnknownEvents,
              ),
              if (PlatformInfos.isMobile)
                SettingsSwitchListTile.adaptive(
                  title: L10n.of(context).autoplayImages,
                  setting: AppSettings.autoplayImages,
                ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).sendOnEnter,
                setting: AppSettings.sendOnEnter,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).swipeRightToLeftToReply,
                setting: AppSettings.swipeRightToLeftToReply,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).showThumbnailsInTimeline,
                setting: AppSettings.showThumbnailsInTimeline,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).doubleTapToReact,
                subtitle: L10n.of(context).doubleTapToReactDescription,
                setting: AppSettings.doubleTapToReact,
                onChanged: (_) => controller.updateState(),
              ),
              if (AppSettings.doubleTapToReact.value)
                ListTile(
                  title: Text(L10n.of(context).doubleTapReaction),
                  trailing: Text(
                    AppSettings.doubleTapReaction.value,
                    style: const TextStyle(fontSize: 24),
                  ),
                  onTap: () async {
                    final emoji = await showAdaptiveBottomSheet<String>(
                      context: context,
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: Text(L10n.of(context).doubleTapReaction),
                          leading: CloseButton(
                            onPressed: () => Navigator.of(context).pop(null),
                          ),
                        ),
                        body: SizedBox(
                          height: double.infinity,
                          child: EmojiPicker(
                            onEmojiSelected: (_, emoji) =>
                                Navigator.of(context).pop(emoji.emoji),
                            config: Config(
                              locale: Localizations.localeOf(context),
                              emojiViewConfig: const EmojiViewConfig(
                                backgroundColor: Colors.transparent,
                              ),
                              bottomActionBarConfig:
                                  const BottomActionBarConfig(enabled: false),
                              categoryViewConfig: CategoryViewConfig(
                                initCategory: Category.SMILEYS,
                                backspaceColor: theme.colorScheme.primary,
                                iconColor: theme.colorScheme.primary.withAlpha(
                                  128,
                                ),
                                iconColorSelected: theme.colorScheme.primary,
                                indicatorColor: theme.colorScheme.primary,
                                backgroundColor: theme.colorScheme.surface,
                              ),
                              skinToneConfig: SkinToneConfig(
                                dialogBackgroundColor: Color.lerp(
                                  theme.colorScheme.surface,
                                  theme.colorScheme.primaryContainer,
                                  0.75,
                                )!,
                                indicatorColor: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    if (emoji != null) {
                      await AppSettings.doubleTapReaction.setItem(emoji);
                      controller.updateState();
                    }
                  },
                ),
              Divider(color: theme.dividerColor),
              ListTile(
                title: Text(
                  L10n.of(context).customEmojisAndStickers,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: Text(L10n.of(context).customEmojisAndStickers),
                subtitle: Text(L10n.of(context).customEmojisAndStickersBody),
                onTap: () => context.go('/rooms/settings/chat/emotes'),
                trailing: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(Icons.chevron_right_outlined),
                ),
              ),
              if (PlatformInfos.isMobile) ...[
                Divider(color: theme.dividerColor),
                ListTile(
                  title: Text(
                    L10n.of(context).videoMessages,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(L10n.of(context).videoMessageQuality),
                  subtitle: Text(
                    AppSettings.videoMessageQuality.value == 'max'
                        ? L10n.of(context).videoQualityMax
                        : L10n.of(context).videoQuality1080p,
                  ),
                  onTap: () => _pickSetting<String>(
                    context,
                    title: L10n.of(context).videoMessageQuality,
                    current: AppSettings.videoMessageQuality.value,
                    onSelected: AppSettings.videoMessageQuality.setItem,
                    options: {
                      '1080p': L10n.of(context).videoQuality1080p,
                      'max': L10n.of(context).videoQualityMax,
                    },
                  ),
                ),
                ListTile(
                  title: Text(L10n.of(context).videoMessageMaxLength),
                  subtitle: Text(
                    _formatSeconds(
                      context,
                      AppSettings.videoMessageMaxDurationSeconds.value,
                    ),
                  ),
                  onTap: () => _pickSetting<int>(
                    context,
                    title: L10n.of(context).videoMessageMaxLength,
                    current: AppSettings.videoMessageMaxDurationSeconds.value,
                    onSelected:
                        AppSettings.videoMessageMaxDurationSeconds.setItem,
                    options: {
                      for (final seconds in const [15, 30, 60, 120, 180])
                        seconds: _formatSeconds(context, seconds),
                    },
                  ),
                ),
                ListTile(
                  title: Text(L10n.of(context).defaultCamera),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'front',
                        label: Text(L10n.of(context).frontCamera),
                      ),
                      ButtonSegment(
                        value: 'back',
                        label: Text(L10n.of(context).backCamera),
                      ),
                    ],
                    selected: {AppSettings.videoMessageDefaultCamera.value},
                    onSelectionChanged: (selected) async {
                      await AppSettings.videoMessageDefaultCamera.setItem(
                        selected.single,
                      );
                      controller.updateState();
                    },
                  ),
                ),
                SettingsSwitchListTile.adaptive(
                  title: L10n.of(context).saveVideoMessagesToGallery,
                  subtitle: L10n.of(
                    context,
                  ).saveVideoMessagesToGalleryDescription,
                  setting: AppSettings.videoMessageSaveToGallery,
                ),
                SettingsSwitchListTile.adaptive(
                  title: L10n.of(context).saveVideoWhenOffline,
                  subtitle: L10n.of(context).saveVideoWhenOfflineDescription,
                  setting: AppSettings.videoMessageSaveWhenOffline,
                ),
              ],
              Divider(color: theme.dividerColor),
              ListTile(
                title: Text(
                  L10n.of(context).calls,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSeconds(BuildContext context, int seconds) =>
      seconds < 60 || seconds % 60 != 0
      ? L10n.of(context).secondsShort(seconds)
      : L10n.of(context).minutesShort(seconds ~/ 60);

  Future<void> _pickSetting<T>(
    BuildContext context, {
    required String title,
    required T current,
    required Future<void> Function(T) onSelected,
    required Map<T, String> options,
  }) async {
    final selected = await showAdaptiveBottomSheet<T>(
      context: context,
      isScrollControlled: false,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioGroup<T>(
              groupValue: current,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options.entries)
                    RadioListTile<T>.adaptive(
                      value: option.key,
                      title: Text(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await onSelected(selected);
    controller.updateState();
  }
}
