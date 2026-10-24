// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Asks before deleting messages for everyone: a plain-language title, the
/// consequence in text-2, an optional reason and a filled Coral Delete.
///
/// Returns the reason (empty when none was given), or null when cancelled.
Future<String?> showDeleteMessagesDialog(
  BuildContext context, {
  required int count,
  bool useRootNavigator = true,
}) => showDialog<String>(
  context: context,
  useRootNavigator: useRootNavigator,
  builder: (context) => _DeleteMessagesDialog(count: count),
);

class _DeleteMessagesDialog extends StatefulWidget {
  final int count;

  const _DeleteMessagesDialog({required this.count});

  @override
  State<_DeleteMessagesDialog> createState() => _DeleteMessagesDialogState();
}

class _DeleteMessagesDialogState extends State<_DeleteMessagesDialog> {
  final _reason = TextEditingController();

  static const int maxLength = 255;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = L10n.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.delete_rounded, color: scheme.onError),
              ),
              const SizedBox(height: 16),
              Text(
                widget.count == 1
                    ? l10n.deleteMessageTitle
                    : l10n.deleteMessagesTitle(widget.count),
                style: D0b0Type.title.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.deleteMessageBody,
                style: D0b0Type.bodyS.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                maxLength: maxLength,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(context).pop(_reason.text),
                style: D0b0Type.body.copyWith(color: scheme.onSurface),
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => Text(
                      '$currentLength/$maxLength',
                      style: D0b0Type.monoS.copyWith(color: theme.d0b0.text3),
                    ),
                decoration: InputDecoration(
                  hintText: l10n.reasonOptional,
                  fillColor: scheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(D0b0Radius.card),
                    borderSide: BorderSide(color: scheme.outline, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(D0b0Radius.card),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: .end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('delete_message_confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => Navigator.of(context).pop(_reason.text),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
