import 'package:package_info_plus/package_info_plus.dart';

/// The version of the app that is actually installed.
///
/// Read from the build rather than typed into the settings screen: a hardcoded
/// number is right until the next release and wrong the moment somebody
/// reports a bug. Same approach as the ClassCast app.
class AppVersion {
  const AppVersion._();

  static String _version = '';
  static String _build = '';
  static bool _loaded = false;

  /// e.g. `1.0.0 (1)`. Empty until [load] has run.
  static String get label {
    if (!_loaded) return '';
    if (_build.isEmpty || _build == '0') return _version;
    return '$_version ($_build)';
  }

  static bool get isLoaded => _loaded;

  /// Reads it once. Never throws: on a platform that cannot answer the row
  /// simply falls back to the pubspec version instead of taking Settings down.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _build = info.buildNumber;
    } catch (_) {
      // No platform channel (a test, or an unusual build).
    }
    if (_version.isEmpty) _version = '1.0.0';
    _loaded = true;
  }
}
