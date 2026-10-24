// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/utils/downloads_saver.dart';
import 'package:fluffychat/utils/media_download.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/d0b0/settings_group.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/settings_switch_list_tile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_chat.dart';

class SettingsChatView extends StatelessWidget {
  final SettingsChatController controller;
  const SettingsChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

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
              D0b0SectionLabel(l10n.messages),
              D0b0SettingsGroup(
                children: [
                  SettingsSwitchListTile.adaptive(
                    title: l10n.formattedMessages,
                    subtitle: l10n.formattedMessagesShortDescription,
                    setting: AppSettings.renderHtml,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: l10n.showDeletedMessages,
                    subtitle: l10n.showDeletedMessagesDescription,
                    setting: AppSettings.hideRedactedEvents,
                    invert: true,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: l10n.showUnsupportedEvents,
                    subtitle: l10n.showUnsupportedEventsDescription,
                    setting: AppSettings.hideUnknownEvents,
                    invert: true,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: l10n.hideRoomsInSpaces,
                    setting: AppSettings.hideRoomsInSpaces,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: l10n.showThumbnailsInTimeline,
                    setting: AppSettings.showThumbnailsInTimeline,
                  ),
                ],
              ),
              D0b0SectionLabel(l10n.typingSection),
              D0b0SettingsGroup(
                children: [
                  // 'Enter sends' explains itself per platform.
                  SettingsSwitchListTile.adaptive(
                    title: l10n.enterSends,
                    subtitle: PlatformInfos.isMobile
                        ? l10n.enterSendsMobileDescription
                        : l10n.enterSendsDesktopDescription,
                    setting: AppSettings.sendOnEnter,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: l10n.swipeRightToLeftToReply,
                    setting: AppSettings.swipeRightToLeftToReply,
                  ),
                ],
              ),
              D0b0SectionLabel(l10n.reactionsAndMedia),
              D0b0SettingsGroup(
                children: [
                  SettingsSwitchListTile.adaptive(
                    title: l10n.doubleTapToReact,
                    subtitle: l10n.doubleTapToReactDescription,
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
                                onPressed: () =>
                                    Navigator.of(context).pop(null),
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
                                      const BottomActionBarConfig(
                                        enabled: false,
                                      ),
                                  categoryViewConfig: CategoryViewConfig(
                                    initCategory: Category.SMILEYS,
                                    backspaceColor: theme.colorScheme.primary,
                                    iconColor: theme.colorScheme.primary
                                        .withAlpha(128),
                                    iconColorSelected:
                                        theme.colorScheme.primary,
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
                  if (PlatformInfos.isMobile)
                    SettingsSwitchListTile.adaptive(
                      title: l10n.autoplayImages,
                      setting: AppSettings.autoplayImages,
                    ),
                ],
              ),
              if (PlatformInfos.isMobile) ...[
                D0b0SectionLabel(l10n.videoMessages),
                D0b0SettingsGroup(
                  children: [
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
                        current:
                            AppSettings.videoMessageMaxDurationSeconds.value,
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
                      subtitle: L10n.of(
                        context,
                      ).saveVideoWhenOfflineDescription,
                      setting: AppSettings.videoMessageSaveWhenOffline,
                    ),
                  ],
                ),
              ],
              // Downloads are only kept where there is a file system.
              if (!kIsWeb) ...[
                D0b0SectionLabel(l10n.mediaDownloads),
                D0b0SettingsGroup(
                  children: [
                    if (PlatformInfos.supportsVideoPlayer)
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).autoDownloadVideos,
                        setting: AppSettings.autoDownloadVideos,
                        onChanged: (_) => controller.updateState(),
                      ),
                    SettingsSwitchListTile.adaptive(
                      title: L10n.of(context).autoDownloadImages,
                      setting: AppSettings.autoDownloadImages,
                      onChanged: (_) => controller.updateState(),
                    ),
                    SettingsSwitchListTile.adaptive(
                      title: L10n.of(context).autoDownloadFiles,
                      setting: AppSettings.autoDownloadFiles,
                      onChanged: (_) => controller.updateState(),
                    ),
                    if (autoDownloadEnabled) ...[
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).autoDownloadWifiOnly,
                        subtitle: L10n.of(
                          context,
                        ).autoDownloadWifiOnlyDescription,
                        setting: AppSettings.autoDownloadWifiOnly,
                      ),
                      ListTile(
                        title: Text(L10n.of(context).autoDownloadMaxSize),
                        subtitle: Text(
                          _formatMegabytes(
                            context,
                            AppSettings.autoDownloadMaxSizeMb.value,
                          ),
                        ),
                        onTap: () => _pickSetting<int>(
                          context,
                          title: L10n.of(context).autoDownloadMaxSize,
                          current: AppSettings.autoDownloadMaxSizeMb.value,
                          onSelected: AppSettings.autoDownloadMaxSizeMb.setItem,
                          options: {
                            for (final megabytes in const [5, 20, 50, 100, 0])
                              megabytes: _formatMegabytes(context, megabytes),
                          },
                        ),
                      ),
                    ],
                    // Gal has no Linux support.
                    if (!PlatformInfos.isLinux) ...[
                      _locationTile(
                        context,
                        title: L10n.of(context).saveDownloadedPhotosTo,
                        setting: AppSettings.imageDownloadLocation,
                        options: {
                          'cache': L10n.of(context).mediaLocationCache,
                          'gallery': L10n.of(context).mediaLocationGallery(
                            MediaDownload.galleryAlbum(video: false),
                          ),
                        },
                      ),
                      _locationTile(
                        context,
                        title: L10n.of(context).saveDownloadedVideosTo,
                        setting: AppSettings.videoDownloadLocation,
                        options: {
                          'cache': L10n.of(context).mediaLocationCache,
                          'gallery': L10n.of(context).mediaLocationGallery(
                            MediaDownload.galleryAlbum(video: true),
                          ),
                        },
                      ),
                    ],
                    _locationTile(
                      context,
                      title: L10n.of(context).saveDownloadedFilesTo,
                      setting: AppSettings.fileDownloadLocation,
                      options: {
                        'cache': L10n.of(context).mediaLocationCache,
                        'downloads': PlatformInfos.isIOS
                            ? L10n.of(
                                context,
                              ).mediaLocationFilesApp(DownloadsSaver.folder)
                            : L10n.of(
                                context,
                              ).mediaLocationDownloads(DownloadsSaver.folder),
                      },
                    ),
                    SettingsSwitchListTile.adaptive(
                      title: L10n.of(context).deleteCachedMedia,
                      subtitle: L10n.of(context).deleteCachedMediaDescription,
                      setting: AppSettings.mediaCacheAutoDelete,
                      onChanged: (_) => controller.updateState(),
                    ),
                    ListTile(
                      enabled: AppSettings.mediaCacheAutoDelete.value,
                      title: Text(L10n.of(context).deleteCachedMediaAfter),
                      subtitle: Text(
                        L10n.of(
                          context,
                        ).countDays(AppSettings.mediaCacheMaxAgeDays.value),
                      ),
                      onTap: () => _pickSetting<int>(
                        context,
                        title: L10n.of(context).deleteCachedMediaAfter,
                        current: AppSettings.mediaCacheMaxAgeDays.value,
                        onSelected: AppSettings.mediaCacheMaxAgeDays.setItem,
                        options: {
                          for (final days in const [1, 7, 30, 90])
                            days: L10n.of(context).countDays(days),
                        },
                      ),
                    ),
                    ListTile(
                      enabled: AppSettings.mediaCacheAutoDelete.value,
                      title: Text(L10n.of(context).maxCacheSize),
                      subtitle: Text(
                        _formatMegabytes(
                          context,
                          AppSettings.mediaCacheMaxSizeMb.value,
                        ),
                      ),
                      onTap: () => _pickSetting<int>(
                        context,
                        title: L10n.of(context).maxCacheSize,
                        current: AppSettings.mediaCacheMaxSizeMb.value,
                        onSelected: (megabytes) async {
                          await AppSettings.mediaCacheMaxSizeMb.setItem(
                            megabytes,
                          );
                          await MediaDownload.cleanUp();
                        },
                        options: {
                          for (final megabytes in const [
                            500,
                            1000,
                            2000,
                            5000,
                            0,
                          ])
                            megabytes: _formatMegabytes(context, megabytes),
                        },
                      ),
                    ),
                    FutureBuilder<int>(
                      future: MediaDownload.cacheSize(),
                      builder: (context, snapshot) {
                        final size = snapshot.data;
                        return ListTile(
                          title: Text(L10n.of(context).mediaCache),
                          subtitle: Text(size == null ? '…' : size.sizeString),
                          trailing: TextButton(
                            onPressed: size == null || size == 0
                                ? null
                                : () => _clearMediaCache(context),
                            child: Text(L10n.of(context).clear),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
              D0b0SectionLabel(l10n.customSection),
              D0b0SettingsGroup(
                children: [
                  D0b0SettingsTile(
                    icon: Symbols.add_reaction_rounded,
                    title: l10n.emojiAndStickerPacks,
                    subtitle: l10n.customEmojisAndStickersBody,
                    chevron: true,
                    onTap: () => context.go('/rooms/settings/chat/emotes'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool get autoDownloadEnabled =>
      (PlatformInfos.supportsVideoPlayer &&
          AppSettings.autoDownloadVideos.value) ||
      AppSettings.autoDownloadImages.value ||
      AppSettings.autoDownloadFiles.value;

  Widget _locationTile(
    BuildContext context, {
    required String title,
    required AppSettings<String> setting,
    required Map<String, String> options,
  }) => ListTile(
    title: Text(title),
    subtitle: Text(options[setting.value] ?? options.values.first),
    onTap: () => _pickSetting<String>(
      context,
      title: title,
      current: setting.value,
      onSelected: setting.setItem,
      options: options,
    ),
  );

  String _formatMegabytes(BuildContext context, int megabytes) => megabytes <= 0
      ? L10n.of(context).noLimit
      : megabytes % 1000 == 0
      ? '${megabytes ~/ 1000} GB'
      : '$megabytes MB';

  Future<void> _clearMediaCache(BuildContext context) async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).clearMediaCache,
      message: L10n.of(context).clearMediaCacheDescription,
      okLabel: L10n.of(context).clear,
      isDestructive: true,
    );
    if (result != OkCancelResult.ok) return;
    await MediaDownload.clearCache();
    controller.updateState();
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
