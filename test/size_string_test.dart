// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/size_string.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sizeString', () {
    expect(512.sizeString, '512 Bytes');
    expect(1500.sizeString, '1.5 KB');
    expect(45600000.sizeString, '45.6 MB');
    expect(2300000000.sizeString, '2.3 GB');
  });
}
