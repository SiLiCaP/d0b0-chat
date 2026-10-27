// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/themes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Same nesting as AppRoutes on a phone: the outer shell, the chat list,
/// and the room shell with the chat as the first page of its own navigator.
GoRouter _router({
  required bool Function() canPop,
  required VoidCallback onPopBlocked,
}) => GoRouter(
  initialLocation: '/rooms/room',
  routes: [
    ShellRoute(
      pageBuilder: (context, state, child) =>
          NoTransitionPage(key: state.pageKey, child: child),
      routes: [
        GoRoute(
          path: '/rooms',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const Scaffold(body: Text('chat list')),
          ),
          routes: [
            ShellRoute(
              pageBuilder: (context, state, child) =>
                  MaterialPage(key: state.pageKey, child: child),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: _Chat(canPop: canPop, onPopBlocked: onPopBlocked),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _Chat extends StatefulWidget {
  final bool Function() canPop;
  final VoidCallback onPopBlocked;
  const _Chat({required this.canPop, required this.onPopBlocked});

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) widget.onPopBlocked();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => GoRouter.of(context).routerDelegate.popRoute(),
        ),
      ),
      body: const Text('chat'),
    ),
  );
}

Future<void> _sendBackGestureMessage(String method, [Object? arguments]) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );

/// An Android edge swipe, as the engine reports it with predictive back.
Future<void> _swipeBack(WidgetTester tester) async {
  await _sendBackGestureMessage('startBackGesture', {
    'touchOffset': [5.0, 300.0],
    'progress': 0.0,
    'swipeEdge': 0,
  });
  await tester.pump();
  await _sendBackGestureMessage('commitBackGesture');
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  bool Function()? canPop,
  VoidCallback? onPopBlocked,
}) async {
  final router = _router(
    canPop: canPop ?? () => true,
    onPopBlocked: onPopBlocked ?? () {},
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => Theme(
        data: FluffyThemes.buildTheme(
          context,
          Brightness.light,
          const Color(0xFF5625BA),
        ),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('chat'), findsOneWidget);
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('swiping back closes the chat', (tester) async {
    final router = await _pumpApp(tester);
    await _swipeBack(tester);
    expect(_location(router), '/rooms');
    expect(find.text('chat list'), findsOneWidget);
  }, variant: android);

  testWidgets('swiping back closes a viewer over the chat, not the chat', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    showDialog(
      context: tester.element(find.text('chat')),
      builder: (_) => const Text('viewer'),
    );
    await tester.pumpAndSettle();

    await _swipeBack(tester);
    expect(find.text('viewer'), findsNothing);
    expect(_location(router), '/rooms/room');
    expect(find.text('chat'), findsOneWidget);
  }, variant: android);

  testWidgets('swiping back respects the PopScope of the chat', (tester) async {
    var blocked = 0;
    final router = await _pumpApp(
      tester,
      canPop: () => false,
      onPopBlocked: () => blocked++,
    );
    await _swipeBack(tester);
    expect(blocked, 1);
    expect(_location(router), '/rooms/room');
  }, variant: android);

  testWidgets('the back button closes a viewer over the chat', (tester) async {
    final router = await _pumpApp(tester);
    showDialog(
      context: tester.element(find.text('chat')),
      builder: (_) => const Text('viewer'),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('viewer'), findsNothing);
    expect(_location(router), '/rooms/room');
  }, variant: android);

  testWidgets('the back button respects the PopScope of the chat', (
    tester,
  ) async {
    var blocked = 0;
    final router = await _pumpApp(
      tester,
      canPop: () => false,
      onPopBlocked: () => blocked++,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(blocked, 1);
    expect(_location(router), '/rooms/room');
  }, variant: android);

  testWidgets('the app bar back button leaves the chat', (tester) async {
    final router = await _pumpApp(tester);
    // Why a plain BackButton did nothing: its navigator has only the chat.
    expect(Navigator.of(tester.element(find.text('chat'))).canPop(), isFalse);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_location(router), '/rooms');
  }, variant: android);
}
