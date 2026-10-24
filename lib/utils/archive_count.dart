// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';

/// How many chats are in the archive (rooms you left), without loading them.
abstract class ArchiveCount {
  static final Map<String, int> _last = {};

  /// Varies the sync timeout so the server doesn't answer from its cache.
  static int _cacheBuster = 0;

  /// The count from the last [load] for [client], to show straight away.
  static int? cached(Client client) => _last[client.userID];

  /// Asks the server with a sync that leaves out every event, so only the
  /// room IDs come back, and counts the left rooms. Full state makes the
  /// server list rooms even when nothing in them passes the filter.
  static Future<int> load(Client client) async {
    final none = StateFilter(types: []);
    final filter = jsonEncode(
      Filter(
        accountData: EventFilter(types: []),
        presence: EventFilter(types: []),
        room: RoomFilter(
          includeLeave: true,
          state: none,
          timeline: StateFilter(types: [], limit: 0),
          ephemeral: none,
          accountData: none,
        ),
      ).toJson(),
    );
    final response = await client.sync(
      filter: filter,
      fullState: true,
      timeout: _cacheBuster,
      setPresence: client.syncPresence,
    );
    _cacheBuster = (_cacheBuster + 1) % 30;
    final count = response.rooms?.leave?.length ?? 0;
    final userId = client.userID;
    if (userId != null) _last[userId] = count;
    return count;
  }
}
