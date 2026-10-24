// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/widgets.dart';

class StartTime extends StatefulWidget {
  final DateTime startTime;
  final TextStyle? style;

  /// Wraps the elapsed time, e.g. '4 in call · 12:04'.
  final String Function(String elapsed)? label;

  const StartTime({required this.startTime, this.style, this.label, super.key});

  @override
  State<StartTime> createState() => _StartTimeState();
}

class _StartTimeState extends State<StartTime> {
  late final Timer _timer;

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(widget.startTime);
    final elapsed =
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    return Text(
      widget.label?.call(elapsed) ?? elapsed,
      maxLines: 1,
      style: widget.style ?? const TextStyle(fontSize: 11),
    );
  }
}
