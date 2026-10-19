import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class AuthResult {
  const AuthResult({required this.profile, this.needsEmailConfirmation = false});

  final UserProfile profile;
  final bool needsEmailConfirmation;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  UserProfile? _cache;

  UserProfile? get cachedProfile => _cache;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  UserProfile? get currentUser => _cache;

  /// Called on app start: re-attach the profile to an existing session.
  Future<UserProfile?> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      _cache = null;
      return null;
    }
    return _loadProfile(session.user.id);
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth
        .signInWithPassword(email: email.trim(), password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign in failed. Please try again.');
    }
    final profile = await _loadProfile(user.id);
    return AuthResult(profile: profile);
  }

  Future<AuthResult> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? purok,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        // The names here must match `handle_new_user()` in schema.sql, which
        // copies them out of the sign-up metadata into `profiles`.
        if (phone != null && phone.isNotEmpty) 'phone_number': phone.trim(),
        if (purok != null && purok.isNotEmpty) 'purok': purok.trim(),
      },
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Could not create the account.');
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      // Email confirmation is enabled in the Supabase project.
      return AuthResult(
        profile: UserProfile(
          id: user.id,
          fullName: fullName.trim(),
          role: UserRole.resident,
          phone: phone,
        ),
        needsEmailConfirmation: true,
      );
    }

    final profile = await _loadProfile(user.id);
    return AuthResult(profile: profile);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _cache = null;
  }

  Future<void> sendPasswordReset(String email) async {
    // `redirectTo` is omitted on purpose: the Android app has no deep link
    // handler, so Supabase sends its own reset page instead of redirecting to
    // a URL the app cannot open.
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? purok,
  }) async {
    final current = _cache;
    if (current == null) {
      throw const AuthException('You are not signed in.');
    }

    // Built explicitly rather than from the model: `toSelfUpdate()` would also
    // write `barangay`, and a stale value there should not be able to overwrite
    // what the office set.
    final updates = <String, dynamic>{
      'full_name': (fullName ?? current.fullName).trim(),
      'phone_number': phone ?? current.phone,
      'purok': purok ?? current.purok,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('profiles')
        .update(updates)
        .eq('id', current.id)
        .select()
        .maybeSingle();
    if (response == null) {
      throw const AuthException('Could not save your profile.');
    }
    _cache = UserProfile.fromMap(response);
    return _cache!;
  }

  /// Admin-only: change somebody else's role.
  ///
  /// Assigning a role is also the act of activating the account: a new signup
  /// starts as `resident` / `pending` (the `handle_new_user` trigger enforces
  /// that, so public registration cannot grant privileges), and the only way
  /// it becomes usable is an administrator acting on it here.
  Future<UserProfile> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final response = await _client
        .from('profiles')
        .update({
          'role': role.value,
          'account_status': AccountStatus.active.value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .maybeSingle();
    if (response == null) {
      throw const AuthException('Could not update that account.');
    }
    return UserProfile.fromMap(response);
  }

  Future<List<UserProfile>> listUsers() async {
    final data = await _client
        .from('profiles')
        .select('*')
        .order('full_name', ascending: true);
    return (data as List)
        .map((row) => UserProfile.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<UserProfile> _loadProfile(String userId) async {
    var data = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    // The trigger normally creates this row; create it defensively if the
    // account was made before the trigger existed.
    data ??= await _client.from('profiles').insert({
      'id': userId,
      'full_name': 'New resident',
    }).select().maybeSingle();

    if (data == null) {
      throw const AuthException('Your profile could not be loaded.');
    }
    _cache = UserProfile.fromMap(data);
    return _cache!;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}