/// Compile-time configuration.
///
/// Supabase credentials are **not** secrets in the way a server key is — the
/// anon/publishable key is designed to ship inside a client app and the real
/// protection is Row Level Security in Postgres. It is still injected at build
/// time rather than committed, so a fork cannot accidentally point at somebody
/// else's project.
///
/// Supply them when running locally:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// The GitHub Actions workflow reads the same two names from repository
/// secrets, so CI and local builds are configured identically.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both values are present, i.e. the app can talk to a real
  /// database.
  ///
  /// When false the app runs against [DemoData] and shows a persistent banner
  /// saying so. That is deliberate: an app that silently looks real while
  /// reading nothing is worse than one that admits it is offline.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Demo mode also accepts an explicit override so a reviewer can force it.
  static const bool forceDemo = bool.fromEnvironment('FORCE_DEMO');

  static bool get isDemoMode => !isConfigured || forceDemo;

  /// The public bucket that holds asset photographs. Asset photos are not
  /// sensitive, so they are readable by anyone with the URL; borrower documents
  /// and condition evidence go to a private bucket instead.
  static const String assetBucket = String.fromEnvironment(
    'SUPABASE_ASSET_BUCKET',
    defaultValue: 'asset-photos',
  );

  /// Private bucket for request documents and release/return photos. Read only
  /// through short-lived signed URLs by authorised staff.
  static const String privateBucket = String.fromEnvironment(
    'SUPABASE_PRIVATE_BUCKET',
    defaultValue: 'borrow-documents',
  );
}