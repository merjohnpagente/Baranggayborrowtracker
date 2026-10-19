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
    String? address,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.isNotEmpty) 'address': address.trim(),
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
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    final current = _cache;
    if (current == null) {
      throw const AuthException('You are not signed in.');
    }
    final updated = current.copyWith(
      fullName: fullName ?? current.fullName,
      phone: phone ?? current.phone,
      address: address ?? current.address,
    );
    final response = await _client
        .from('profiles')
        .update(updated.toUpdate())
        .eq('id', current.id)
        .select()
        .maybeSingle();
    if (response == null) {
      throw const AuthException('Could not save your profile.');
    }
    _cache = UserProfile.fromMap(response);
    return _cache!;
  }

  /// Admin-only: change somebody else's role or reactivate an account.
  Future<UserProfile> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final response = await _client
        .from('profiles')
        .update({'role': role.value, 'updated_at': DateTime.now().toIso8601String()})
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