// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/d0b0_theme.dart';
import 'package:fluffychat/widgets/d0b0/splash_marquee.dart';
import 'package:flutter/widgets.dart';

/// Shows the splash marquee from the first Flutter frame until the app is
/// ready, then cross-fades into it.
///
/// [main] runs this before loading settings and clients, and hands the
/// built app over through [show] instead of calling runApp again.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  static final ValueNotifier<Widget?> _app = ValueNotifier(null);
  static bool _running = false;

  /// Starts the splash.
  static void start() {
    _running = true;
    runApp(const SplashGate());
  }

  /// Shows [app], fading out the splash if it is running.
  static void show(Widget app) {
    if (_running) {
      _app.value = app;
    } else {
      runApp(app);
    }
  }

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  /// The hand-over: the background fades away first, leaving the chain over
  /// the app, then the chain goes.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _splashGone = false;

  @override
  void initState() {
    super.initState();
    SplashGate._app.addListener(_onApp);
    _exit.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _splashGone = true);
      }
    });
  }

  void _onApp() {
    if (SplashGate._app.value == null) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _exit.duration = reduceMotion
        ? D0b0Motion.state
        : const Duration(milliseconds: 900);
    _exit.forward();
  }

  @override
  void dispose() {
    SplashGate._app.removeListener(_onApp);
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Widget?>(
    valueListenable: SplashGate._app,
    builder: (context, app, _) => Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        ?app,
        if (!_splashGone)
          IgnorePointer(
            ignoring: app != null,
            child: D0b0SplashMarquee(exit: app == null ? null : _exit),
          ),
      ],
    ),
  );
}
