import 'package:flutter/material.dart';

import '../data/local/local_store.dart';

/// The user's chosen appearance, persisted with the rest of the local data.
///
/// Default is [ThemeMode.system] so a first launch follows the phone. Once the
/// user picks Light or Dark in Settings, that choice survives a restart.
class AppearanceProvider extends ChangeNotifier {
  AppearanceProvider(this._store) : _mode = _decode(_store.themeModeValue);

  final LocalStore _store;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  String get label => switch (_mode) {
        ThemeMode.light => 'Light theme',
        ThemeMode.dark => 'Dark theme',
        ThemeMode.system => 'Following your phone',
      };

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _store.setThemeModeValue(_encode(mode));
  }

  static ThemeMode _decode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
