// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/widgets/d0b0/avatar_tone.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:fluffychat/widgets/presence_builder.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class Avatar extends StatelessWidget {
  final Uri? mxContent;
  final String? name;
  final double size;
  final void Function()? onTap;
  static const double defaultSize = 48;
  final Client? client;
  final String? presenceUserId;
  final Color? presenceBackgroundColor;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final ShapeBorder? shapeBorder;
  final Color? backgroundColor;
  final Color? textColor;

  /// Picks the fallback tone; pass the room or user ID. Defaults to [name].
  final String? toneSeed;

  /// Rooms and spaces are rounded squares (radius = size ÷ 3); people are
  /// always circles.
  final bool isRoom;

  const Avatar({
    this.mxContent,
    this.name,
    this.size = defaultSize,
    this.onTap,
    this.client,
    this.presenceUserId,
    this.presenceBackgroundColor,
    this.borderRadius,
    this.shapeBorder,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.toneSeed,
    this.isRoom = false,
    super.key,
  });

  String _calcFallbackLetters() {
    final name = this.name?.trim().replaceFirst(RegExp(r'^[@#!]'), '');
    if (name == null || name.isEmpty) return '@';
    return name.characters.take(2).toUpperCase().toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fallbackLetters = _calcFallbackLetters();

    final noPic =
        mxContent == null ||
        mxContent.toString().isEmpty ||
        mxContent.toString() == 'null';
    final borderRadius =
        this.borderRadius ??
        BorderRadius.circular(isRoom ? size / 3 : size / 2);
    final tone = AvatarTone.of(toneSeed ?? name ?? '', theme.brightness);
    final presenceUserId = this.presenceUserId;
    final container = Stack(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Material(
            color: theme.colorScheme.surfaceContainer,
            shape:
                shapeBorder ??
                RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: BorderSide.none,
                ),
            clipBehavior: Clip.antiAlias,
            child: MxcImage(
              client: client,
              borderRadius: borderRadius,
              key: ValueKey(mxContent.toString()),
              cacheKey: '${mxContent}_$size',
              uri: mxContent,
              fit: BoxFit.cover,
              width: size,
              height: size,
              placeholder: (_) => noPic
                  ? Container(
                      decoration: BoxDecoration(
                        color: backgroundColor ?? tone.background,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        fallbackLetters,
                        textAlign: TextAlign.center,
                        style: D0b0Type.label.copyWith(
                          color: textColor ?? tone.foreground,
                          fontSize: (size * 0.36).roundToDouble(),
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Symbols.person_2_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: size / 1.5,
                      ),
                    ),
            ),
          ),
        ),
        if (presenceUserId != null)
          PresenceBuilder(
            client: client,
            userId: presenceUserId,
            builder: (context, presence) {
              if (presence == null ||
                  (presence.presence == PresenceType.offline &&
                      presence.lastActiveTimestamp == null)) {
                return const SizedBox.shrink();
              }
              // Online = filled Signal dot, away = Signal ring (outline =
              // waiting). Offline shows nothing.
              final isOnline = presence.presence.isOnline;
              if (!isOnline && !presence.presence.isUnavailable) {
                return const SizedBox.shrink();
              }
              final colors = theme.d0b0;
              final dot = (size * 0.29).roundToDouble();
              const ring = 3.0;
              return Positioned(
                bottom: -ring,
                right: -ring,
                child: Container(
                  width: dot + ring * 2,
                  height: dot + ring * 2,
                  decoration: BoxDecoration(
                    color: presenceBackgroundColor ?? theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: isOnline ? colors.online : null,
                      shape: BoxShape.circle,
                      border: isOnline
                          ? null
                          : Border.all(width: dot / 4, color: colors.away),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
    if (onTap == null) return container;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: container),
    );
  }
}
