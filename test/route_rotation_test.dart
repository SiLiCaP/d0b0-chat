// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/config/routes.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The same nesting as [AppRoutes], with stub pages: an outer shell that
/// puts the list beside its child on wide windows, and a room shell inside.
GoRouter _router() => GoRouter(
  initialLocation: '/rooms/abc',
  routes: [
    ShellRoute(
      pageBuilder: (context, state, child) => AppRoutes.noTransitionPageBuilder(
        context,
        state,
        FluffyThemes.isColumnMode(context)
            ? Scaffold(
                body: Row(
                  children: [
                    const SizedBox(width: 200, child: Text('list')),
                    Expanded(child: child),
                  ],
                ),
              )
            : child,
      ),
      routes: [
        GoRoute(
          path: '/rooms',
          pageBuilder: (context, state) => AppRoutes.defaultPageBuilder(
            context,
            state,
            FluffyThemes.isColumnMode(context)
                ? const Text('empty')
                : const Scaffold(body: Text('list-page')),
          ),
          routes: [
            ShellRoute(
              pageBuilder: AppRoutes.shellPageBuilder,
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => AppRoutes.defaultPageBuilder(
                    context,
                    state,
                    const Scaffold(body: Text('chat')),
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

void main() {
  testWidgets('an open chat survives rotating to landscape and back (#59)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);

    tester.view.physicalSize = const Size(892, 412);
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(412, 892);
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a chat still slides in on narrow windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.reset);
    final router = _router()..go('/rooms');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/rooms/abc'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final during = tester.getTopLeft(find.text('chat')).dx;
    await tester.pumpAndSettle();
    expect(during, greaterThan(tester.getTopLeft(find.text('chat')).dx));
  });
}
