/// Build-time configuration and app-wide constants.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Barangay Borrow Tracker';

  static const String developerName = 'Merjohn Pagente';

  /// The name used on the splash screen and in the credits.
  static const String developerBrand = 'MerjDev';

  static const String githubHandle = 'merjohnpagente';

  static const String githubUrl = 'https://github.com/merjohnpagente';

  /// Shown with spaces so it can be read off the screen; [gcashDigits] is what
  /// actually gets copied.
  static const String gcashNumber = '0915 043 5696';

  static const String gcashDigits = '09150435696';

  /// Only the barangay name is still configurable at build time; the app has
  /// no server credentials any more.
  static const String barangayName =
      String.fromEnvironment('BARANGAY_NAME', defaultValue: 'Our Barangay');

  /// Longest borrow period a resident can request in one go (days).
  static const int maxBorrowDays = 14;

  /// How early a return must be scheduled.
  static const int maxAdvanceDays = 90;

  /// How long the splash stays up before the router takes over.
  static const Duration splashDuration = Duration(milliseconds: 2800);
}
