// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/color_value.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeBuilder extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    ThemeMode themeMode,
    Color? primaryColor,
  )
  builder;

  final String themeModeSettingsKey;
  final String primaryColorSettingsKey;

  const ThemeBuilder({
    required this.builder,
    this.themeModeSettingsKey = 'theme_mode',
    this.primaryColorSettingsKey = 'primary_color',
    super.key,
  });

  @override
  State<ThemeBuilder> createState() => ThemeController();
}

class ThemeController extends State<ThemeBuilder> {
  SharedPreferences? _sharedPreferences;
  ThemeMode? _themeMode;
  Color? _primaryColor;
  bool _useSystemColor = false;

  /// Stored when the user explicitly picks the system (wallpaper) colour.
  /// Without any stored value the d0b0 brand colour is used.
  static const int _systemColorValue = 0;

  ThemeMode get themeMode => _themeMode ?? ThemeMode.system;

  /// The picked colour, or null when the system colour is picked.
  Color? get primaryColor =>
      _useSystemColor ? null : _primaryColor ?? AppConfig.chatColor;

  static ThemeController of(BuildContext context) =>
      Provider.of<ThemeController>(context, listen: false);

  Future<void> _loadData(_) async {
    final preferences = _sharedPreferences ??=
        await SharedPreferences.getInstance();

    final rawThemeMode = preferences.getString(widget.themeModeSettingsKey);
    final rawColor = preferences.getInt(widget.primaryColorSettingsKey);

    setState(() {
      _themeMode = ThemeMode.values.singleWhereOrNull(
        (value) => value.name == rawThemeMode,
      );
      _useSystemColor = rawColor == _systemColorValue;
      _primaryColor = rawColor == null || _useSystemColor
          ? null
          : Color(rawColor);
    });
  }

  Future<void> setThemeMode(ThemeMode newThemeMode) async {
    final preferences = _sharedPreferences ??=
        await SharedPreferences.getInstance();
    await preferences.setString(widget.themeModeSettingsKey, newThemeMode.name);
    setState(() {
      _themeMode = newThemeMode;
    });
  }

  Future<void> setPrimaryColor(Color? newPrimaryColor) async {
    final preferences = _sharedPreferences ??=
        await SharedPreferences.getInstance();
    await preferences.setInt(
      widget.primaryColorSettingsKey,
      newPrimaryColor?.hexValue ?? _systemColorValue,
    );
    setState(() {
      _useSystemColor = newPrimaryColor == null;
      _primaryColor = newPrimaryColor;
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(_loadData);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => this,
      child: DynamicColorBuilder(
        builder: (light, _) => widget.builder(
          context,
          themeMode,
          _useSystemColor ? light?.primary : _primaryColor,
        ),
      ),
    );
  }
}
