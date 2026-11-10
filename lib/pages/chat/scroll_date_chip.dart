// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/day_chip.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// While the timeline scrolls, shows the day of the message at its top, then
/// fades out once it stops (#56). Place it at the top of the timeline.
class ScrollDateChip extends StatefulWidget {
  final ChatController controller;

  /// How long the chip stays after the last scroll.
  static const Duration lingerDuration = Duration(milliseconds: 1200);

  const ScrollDateChip({required this.controller, super.key});

  @override
  State<ScrollDateChip> createState() => _ScrollDateChipState();
}

class _ScrollDateChipState extends State<ScrollDateChip> {
  DateTime? _date;
  bool _visible = false;
  Timer? _hideTimer;
  bool _updateQueued = false;

  // The visible events change rarely, scrolling constantly, so keep the
  // filtered list until the timeline changes.
  List<Event>? _events;
  Timeline? _eventsTimeline;
  int _eventsLength = -1;
  String? _eventsNewestId;
  String? _eventsThreadId;

  @override
  void initState() {
    super.initState();
    widget.controller.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollDateChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.scrollController.removeListener(_onScroll);
      widget.controller.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.scrollController.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  /// The timeline as the list shows it, newest first, so an index here is the
  /// index of the same message in the list.
  List<Event>? _visibleEvents() {
    final timeline = widget.controller.timeline;
    if (timeline == null) return null;
    final threadId = widget.controller.activeThreadId;
    final newestId = timeline.events.firstOrNull?.eventId;
    if (_events == null ||
        !identical(_eventsTimeline, timeline) ||
        _eventsLength != timeline.events.length ||
        _eventsNewestId != newestId ||
        _eventsThreadId != threadId) {
      _events = timeline.events.filterByVisibleInGui(threadId: threadId);
      _eventsTimeline = timeline;
      _eventsLength = timeline.events.length;
      _eventsNewestId = newestId;
      _eventsThreadId = threadId;
    }
    return _events;
  }

  /// The day of the highest message that still reaches below the top edge.
  DateTime? _dateAtTop() {
    final events = _visibleEvents();
    final box = context.findRenderObject();
    if (events == null || box is! RenderBox || !box.attached) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    int? topIndex;
    for (final entry in widget.controller.scrollController.tagMap.entries) {
      final tagBox = entry.value.context.findRenderObject();
      if (!entry.value.mounted ||
          tagBox is! RenderBox ||
          !tagBox.attached ||
          !tagBox.hasSize) {
        continue;
      }
      final bottom = tagBox.localToGlobal(Offset.zero).dy + tagBox.size.height;
      if (bottom > top && (topIndex == null || entry.key > topIndex)) {
        topIndex = entry.key;
      }
    }
    if (topIndex == null || topIndex >= events.length) return null;
    return events[topIndex].originServerTs;
  }

  void _onScroll() {
    // Scroll positions also change during layout, where setState is not
    // allowed, and the items are only placed once layout is done.
    if (_updateQueued) return;
    _updateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueued = false;
      if (!mounted) return;
      final date = _dateAtTop();
      if (date == null) return;
      _hideTimer?.cancel();
      _hideTimer = Timer(ScrollDateChip.lingerDuration, () {
        if (mounted) setState(() => _visible = false);
      });
      final current = _date;
      if (_visible && current != null && current.sameDay(date)) return;
      setState(() {
        _date = date;
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return AnimatedOpacity(
      opacity: _visible && date != null ? 1 : 0,
      duration: D0b0Motion.state,
      child: date == null
          ? const SizedBox.shrink()
          : DayChip(date: date, floating: true),
    );
  }
}
