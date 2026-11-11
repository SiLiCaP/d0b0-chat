// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The emoji picker with a search field above it, like the sticker picker's.
///
/// The library's own search view and button are built on Flutter's Material
/// widgets, which find neither the Material ancestor nor the localizations
/// of material_ui, so the search is done here. While the field is empty the
/// picker shows; with text, the matching emoji replace it.
class SearchableEmojiPicker extends StatefulWidget {
  /// Config for the picker. Its bottom bar should be off.
  final Config config;

  /// An emoji was picked, from the grid or from the search results.
  final void Function(String emoji) onSelected;

  /// Focus the search field right away, to type at once.
  final bool autofocus;

  const SearchableEmojiPicker({
    required this.config,
    required this.onSelected,
    this.autofocus = false,
    super.key,
  });

  @override
  State<SearchableEmojiPicker> createState() => _SearchableEmojiPickerState();
}

class _SearchableEmojiPickerState extends State<SearchableEmojiPicker> {
  final _picker = GlobalKey<EmojiPickerState>();
  // The config's emoji set defaults to the library's own.
  late final List<CategoryEmoji> _emojiSet =
      widget.config.emojiSet?.call(widget.config.locale) ?? const [];
  List<Emoji> _results = const [];
  bool _searching = false;
  int _query = 0;

  Future<void> _search(String text) async {
    final query = ++_query;
    final trimmed = text.trim();
    setState(() => _searching = trimmed.isNotEmpty);
    final results = await EmojiPickerUtils().searchEmoji(trimmed, _emojiSet);
    // A slower search for older text must not replace a newer one.
    if (!mounted || query != _query) return;
    setState(() => _results = results);
  }

  Future<void> _pick(Emoji emoji) async {
    await EmojiPickerUtils().addEmojiToRecentlyUsed(
      key: _picker,
      emoji: emoji,
      config: widget.config,
    );
    widget.onSelected(emoji.emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: widget.autofocus,
            onChanged: _search,
            decoration: InputDecoration(
              filled: true,
              // Set off from the sheet it sits in, in light and dark.
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(99),
              ),
              contentPadding: EdgeInsets.zero,
              hintText: L10n.of(context).search,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              prefixIcon: const Icon(Symbols.search_rounded),
            ),
          ),
        ),
        Expanded(
          // The picker stays built under the results, so clearing the field
          // returns to the tab it was on.
          child: IndexedStack(
            index: _searching ? 1 : 0,
            children: [
              EmojiPicker(
                key: _picker,
                config: widget.config,
                onEmojiSelected: (_, emoji) => widget.onSelected(emoji.emoji),
              ),
              GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 48,
                ),
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final emoji = _results[i];
                  return Tooltip(
                    message: emoji.name,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _pick(emoji),
                      child: Center(
                        child: Text(
                          emoji.emoji,
                          style: D0b0Type.emoji(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
