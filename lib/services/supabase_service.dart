import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

/// Owns the single [SupabaseClient] and turns failures into plain language.
///
/// The app treats "Supabase not configured" as a first-class state rather than
/// an error: on a fresh clone with no credentials it still runs, on clearly
/// labelled demo data. See [AppConfig].
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;
  static bool _ready = false;

  /// Initialises Supabase when credentials are present.
  ///
  /// Returns true when a real backend was reached. The caller uses the return
  /// value to choose between live data and the demo store, so it reflects what
  /// actually happened rather than what was expected.
  static Future<bool> initialize() async {
    if (AppConfig.isDemoMode) return false;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _ready = true;
      return true;
    } catch (_) {
      // A bad URL or key must not take the app down; fall back to demo mode.
      _client = null;
      _ready = false;
      return false;
    }
  }

  static bool get isReady => _ready;

  /// True when the app is showing demo data rather than real records.
  static bool get isDemo => !_ready;

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError(
        'Supabase is not initialised. The app is running on demo data.',
      );
    }
    return c;
  }

  /// The signed-in user id, or null when signed out.
  static String? get currentUserId => _client?.auth.currentUser?.id;

  /// Auth changes, for routing. Empty stream in demo mode.
  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  /// Resolves once the stored session has been read, so the splash screen does
  /// not flash the login screen at somebody who is already signed in.
  static Future<bool> hasStoredSession() async {
    final c = _client;
    if (c == null) return false;
    try {
      final state = await c.auth.onAuthStateChange.first;
      return state.session != null;
    } catch (_) {
      return false;
    }
  }

  /// Turns a Supabase failure into something a resident can act on.
  ///
  /// Supabase messages are developer-facing ("AuthApiException: Invalid login
  /// credentials"), so the handful that matter are mapped to plain language.
  /// Everything else falls through to the raw message rather than being
  /// swallowed — a silent generic error hides real configuration problems.
  static String describeError(Object error) {
    if (error is AuthException) {
      final status = error.statusCode ?? '';
      if (error.message.toLowerCase().contains('invalid login')) {
        return 'Email or password is incorrect.';
      }
      if (status == '429') {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      if (status == '401' || status == '403') {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.message.toLowerCase().contains('already registered')) {
        return 'An account already exists for that email.';
      }
      return error.message;
    }

    if (error is PostgrestException) {
      // PostgREST surfaces RAISE'd messages directly. The schema writes those
      // to be read by a barangay official ("This asset is already booked..."),
      // so they are shown verbatim rather than replaced with generic text.
      final msg = error.message.trim();
      if (msg.isEmpty) return 'The database rejected that request.';
      return msg;
    }

    if (error is StorageException) {
      return 'That photo could not be uploaded.';
    }

    return 'Something went wrong. Please try again.';
  }
}