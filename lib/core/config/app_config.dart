/// Build-time configuration.
///
/// Values are injected by GitHub Actions (or a local `flutter run`) through
/// `--dart-define`, so no secret ever lands in the repository.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Barangay Borrow Tracker';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String barangayName =
      String.fromEnvironment('BARANGAY_NAME', defaultValue: 'Our Barangay');

  static bool get isConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.length > 20;

  /// Longest borrow period a resident can request in one go (days).
  static const int maxBorrowDays = 14;

  /// How early a return must be scheduled.
  static const int maxAdvanceDays = 90;
}