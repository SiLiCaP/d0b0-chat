// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/archive/archive.dart';
import 'package:fluffychat/pages/bootstrap/bootstrap_page.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:fluffychat/pages/chat_details/chat_details.dart';
import 'package:fluffychat/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_members/chat_members.dart';
import 'package:fluffychat/pages/chat_permissions_settings/chat_permissions_settings.dart';
import 'package:fluffychat/pages/chat_search/chat_search_page.dart';
import 'package:fluffychat/pages/device_settings/device_settings.dart';
import 'package:fluffychat/pages/intro/intro_page_presenter.dart';
import 'package:fluffychat/pages/invitation_selection/invitation_selection.dart';
import 'package:fluffychat/pages/login/login.dart';
import 'package:fluffychat/pages/new_group/new_group.dart';
import 'package:fluffychat/pages/new_private_chat/new_private_chat.dart';
import 'package:fluffychat/pages/settings/settings.dart';
import 'package:fluffychat/pages/settings_3pid/settings_3pid.dart';
import 'package:fluffychat/pages/settings_chat/settings_chat.dart';
import 'package:fluffychat/pages/settings_emotes/settings_emotes.dart';
import 'package:fluffychat/pages/settings_homeserver/settings_homeserver.dart';
import 'package:fluffychat/pages/settings_ignore_list/settings_ignore_list.dart';
import 'package:fluffychat/pages/settings_notifications/settings_notifications.dart';
import 'package:fluffychat/pages/settings_password/settings_password.dart';
import 'package:fluffychat/pages/settings_security/settings_security.dart';
import 'package:fluffychat/pages/settings_style/settings_style.dart';
import 'package:fluffychat/pages/sign_in/sign_in_page.dart';
import 'package:fluffychat/widgets/config_viewer.dart';
import 'package:fluffychat/widgets/layouts/empty_page.dart';
import 'package:fluffychat/widgets/layouts/two_column_layout.dart';
import 'package:fluffychat/widgets/log_view.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/share_scaffold_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

abstract class AppRoutes {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) => Matrix.of(context).widget.clients.any((client) => client.isLogged())
      ? '/rooms'
      : null;

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) => Matrix.of(context).widget.clients.any((client) => client.isLogged())
      ? null
      : '/home';

  AppRoutes();

  static final List<RouteBase> routes = [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          Matrix.of(context).widget.clients.any((client) => client.isLogged())
          ? '/rooms'
          : '/home',
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const IntroPagePresenter()),
      redirect: loggedInRedirect,
      routes: [
        GoRoute(
          path: 'sign_in',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: false)),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'sign_up',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: true)),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'login',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            Login(client: state.extra as Client),
          ),
          redirect: loggedInRedirect,
        ),
      ],
    ),
    GoRoute(
      path: '/logs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const LogViewer()),
    ),
    GoRoute(
      path: '/configs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const ConfigViewer()),
    ),
    GoRoute(
      path: '/backup',
      redirect: loggedOutRedirect,
      pageBuilder: (context, state) => defaultPageBuilder(
        context,
        state,
        BootstrapPage(reset: state.uri.queryParameters['reset'] == 'true'),
      ),
    ),
    ShellRoute(
      // Never use a transition on the shell route. Changing the PageBuilder
      // here based on a MediaQuery causes the child to briefly be rendered
      // twice with the same GlobalKey, blowing up the rendering.
      pageBuilder: (context, state, child) => noTransitionPageBuilder(
        context,
        state,
        FluffyThemes.isColumnMode(context) &&
                state.fullPath?.startsWith('/rooms/settings') == false
            ? TwoColumnLayout(
                mainView: ChatList(
                  activeChat: state.pathParameters['roomid'],
                  activeSpace: state.uri.queryParameters['spaceId'],
                  initialTab: state.uri.queryParameters['tab'],
                  displayNavigationRail:
                      state.path?.startsWith('/rooms/settings') != true,
                ),
                sideView: child,
              )
            : child,
      ),
      routes: [
        GoRoute(
          path: '/rooms',
          redirect: loggedOutRedirect,
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            FluffyThemes.isColumnMode(context)
                ? const EmptyPage()
                : ChatList(
                    activeChat: state.pathParameters['roomid'],
                    activeSpace: state.uri.queryParameters['spaceId'],
                    initialTab: state.uri.queryParameters['tab'],
                  ),
          ),
          routes: [
            GoRoute(
              path: 'archive',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Archive()),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatPage(
                      key: ValueKey(state.uri),
                      roomId: state.pathParameters['roomid']!,
                      eventId: state.uri.queryParameters['event'],
                      timeline: state.extra as Timeline?,
                      action: state.uri.queryParameters['action'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
              ],
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newprivatechat',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewPrivateChat(
                  key: ValueKey('new_chat_${state.uri.fragment}'),
                  deeplink: state.uri.fragment,
                ),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newgroup',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewGroup(spaceId: state.uri.queryParameters['space_id']),
              ),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newspace',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                NewGroup(
                  createGroupType: CreateGroupType.space,
                  spaceId: state.uri.queryParameters['space_id'],
                ),
              ),
              redirect: loggedOutRedirect,
            ),
            ShellRoute(
              pageBuilder: (context, state, child) => defaultPageBuilder(
                context,
                state,
                FluffyThemes.isColumnMode(context)
                    ? TwoColumnLayout(
                        mainView: Settings(key: state.pageKey),
                        sideView: child,
                      )
                    : child,
              ),
              routes: [
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    FluffyThemes.isColumnMode(context)
                        ? const EmptyPage()
                        : const Settings(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsNotifications(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'style',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsStyle(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'devices',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const DevicesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'chat',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsChat(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'emotes',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            EmotesSettings(
                              roomId: state.pathParameters['roomid'],
                            ),
                          ),
                        ),
                      ],
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'addaccount',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const IntroPagePresenter(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'sign_in',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: false),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'sign_up',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: true),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'login',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            Login(client: state.extra as Client),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'homeserver',
                      pageBuilder: (context, state) {
                        return defaultPageBuilder(
                          context,
                          state,
                          const SettingsHomeserver(),
                        );
                      },
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'security',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsSecurity(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'password',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              const SettingsPassword(),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'ignorelist',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              SettingsIgnoreList(
                                initialUserId: state.extra?.toString(),
                              ),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: '3pid',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const Settings3Pid(),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            // On large windows the room keeps its page and everything below
            // it (details, members, search, …) opens in the pane on its right,
            // each with its own URL. Elsewhere they stack as pages.
            ShellRoute(
              pageBuilder: (context, state, child) => defaultPageBuilder(
                context,
                state,
                _roomHasPane(context, state)
                    ? _chatPage(
                        state,
                        key: ValueKey(
                          '${state.pathParameters['roomid']}'
                          '?${state.uri.query}',
                        ),
                        pane: child,
                        paneOpen:
                            state.uri.path !=
                            '/rooms/${state.pathParameters['roomid']}',
                      )
                    : child,
              ),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    _roomHasPane(context, state)
                        ? const SizedBox.shrink()
                        : _chatPage(state, key: ValueKey(state.uri)),
                  ),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'search',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatSearchPage(roomId: state.pathParameters['roomid']!),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'encryption',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const ChatEncryptionSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'invite',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        InvitationSelection(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'details',
                      pageBuilder: (context, state) {
                        final roomId = state.pathParameters['roomid']!;
                        return defaultPageBuilder(
                          context,
                          state,
                          ChatDetails(
                            roomId: roomId,
                            embeddedCloseButton: _roomHasPane(context, state)
                                ? IconButton(
                                    tooltip: L10n.of(context).close,
                                    icon: const Icon(Symbols.close_rounded),
                                    onPressed: () {
                                      AppSettings.displayChatDetailsColumn
                                          .setItem(false);
                                      context.go('/rooms/$roomId');
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'access',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            ChatAccessSettings(
                              roomId: state.pathParameters['roomid']!,
                            ),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'members',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            ChatMembersPage(
                              roomId: state.pathParameters['roomid']!,
                            ),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'permissions',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const ChatPermissionsSettings(),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'invite',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            InvitationSelection(
                              roomId: state.pathParameters['roomid']!,
                            ),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'emotes',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            EmotesSettings(
                              roomId: state.pathParameters['roomid'],
                            ),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                      redirect: loggedOutRedirect,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  /// Whether the room at [state] shows what is below it in a pane beside it:
  /// large windows, a chat you're in, not a space.
  static bool _roomHasPane(BuildContext context, GoRouterState state) {
    if (!FluffyThemes.isThreeColumnMode(context)) return false;
    final roomId = state.pathParameters['roomid'];
    final room = roomId == null
        ? null
        : Matrix.of(context).client.getRoomById(roomId);
    return room != null && room.membership == Membership.join && !room.isSpace;
  }

  static Widget _chatPage(
    GoRouterState state, {
    required Key key,
    Widget? pane,
    bool paneOpen = false,
  }) {
    final body = state.uri.queryParameters['body'];
    var shareItems = state.extra is List<ShareItem>
        ? state.extra as List<ShareItem>
        : null;
    if (body != null && body.isNotEmpty) {
      shareItems ??= [];
      shareItems.add(TextShareItem(body));
    }
    return ChatPage(
      key: key,
      roomId: state.pathParameters['roomid']!,
      shareItems: shareItems,
      eventId: state.uri.queryParameters['event'],
      action: state.uri.queryParameters['action'],
      pane: pane,
      paneOpen: paneOpen,
    );
  }

  static Page noTransitionPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => NoTransitionPage(
    key: state.pageKey,
    restorationId: state.pageKey.value,
    child: child,
  );

  static Page defaultPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    final clientName = state.uri.queryParameters['client'];
    if (clientName != null) {
      final matrix = Matrix.of(context);
      final client = matrix.getClientByName(clientName);
      if (client != null) matrix.setActiveClient(client);
    }
    return FluffyThemes.isColumnMode(context)
        ? noTransitionPageBuilder(context, state, child)
        : MaterialPage(
            key: state.pageKey,
            restorationId: state.pageKey.value,
            child: child,
          );
  }
}
