// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/widgets/d0b0/settings_group.dart';
import 'package:material_ui/material_ui.dart';

class SettingsSwitchListTile extends StatefulWidget {
  final AppSettings<bool?> setting;
  final String title;
  final String? subtitle;
  final Function(bool)? onChanged;
  final bool? defaultValue;

  /// Shows the switch on when the stored setting is off, so a negative
  /// setting ('Hide deleted') can read positively ('Show deleted').
  final bool invert;

  const SettingsSwitchListTile.adaptive({
    super.key,
    required this.setting,
    required this.title,
    this.subtitle,
    this.onChanged,
    this.defaultValue,
    this.invert = false,
  });

  @override
  SettingsSwitchListTileState createState() => SettingsSwitchListTileState();
}

class SettingsSwitchListTileState extends State<SettingsSwitchListTile> {
  @override
  Widget build(BuildContext context) {
    final stored = widget.setting.value ?? widget.defaultValue ?? false;
    return D0b0SwitchTile(
      title: widget.title,
      subtitle: widget.subtitle,
      value: widget.invert ? !stored : stored,
      onChanged: (bool newValue) async {
        final value = widget.invert ? !newValue : newValue;
        widget.onChanged?.call(value);
        await widget.setting.setItem(value);
        setState(() {});
      },
    );
  }
}
