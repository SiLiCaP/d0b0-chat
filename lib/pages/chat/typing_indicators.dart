// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';

/// Someone is typing: three pills in a Moss pill, pulsing left to right,
/// and who it is in mono.
class TypingIndicators extends StatelessWidget {
  final ChatController controller;
  const TypingIndicators(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
      stream: controller.room.client.onSync.stream.where(
        (syncUpdate) =>
            syncUpdate.rooms?.join?[controller.room.id]?.ephemeral?.any(
              (ephemeral) => ephemeral.type == 'm.typing',
            ) ??
            false,
      ),
      builder: (context, _) {
        final typingUsers = controller.room.typingUsers
          ..removeWhere((u) => u.stateKey == Matrix.of(context).client.userID);
        final label = typingUsers.isEmpty
            ? ''
            : controller.room.getLocalizedTypingText(context);
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          child: AnimatedContainer(
            constraints: const BoxConstraints(
              maxWidth: FluffyThemes.maxTimelineWidth,
            ),
            height: typingUsers.isEmpty ? 0 : 36 + 8,
            duration: D0b0Motion.move,
            curve: D0b0Motion.standard,
            alignment: Alignment.topLeft,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: typingUsers.isEmpty
                ? null
                : Row(
                    children: [
                      const TypingPills(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: D0b0Type.monoS.copyWith(
                            color: Theme.of(context).d0b0.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Three 14 × 8 pills; one at a time fills while the others stay outlines,
/// moving left to right. Still when animations are disabled.
class TypingPills extends StatefulWidget {
  const TypingPills({super.key});

  @override
  State<TypingPills> createState() => _TypingPillsState();
}

class _TypingPillsState extends State<TypingPills>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mint = theme.colorScheme.primary;
    return Container(
      width: 72,
      height: 36,
      decoration: ShapeDecoration(
        color: theme.d0b0.bubbleTheirs,
        shape: const StadiumBorder(),
      ),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final active = (_controller.value * 3).floor() % 3;
          return Row(
            mainAxisSize: .min,
            spacing: 2,
            children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: D0b0Motion.state,
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == active ? mint : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: mint, width: 1.5),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
