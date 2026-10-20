import '../local/ids.dart';
import '../local/local_store.dart';
import '../local/password.dart';
import '../models/user_profile.dart';

class AuthResult {
  const AuthResult({required this.profile});

  final UserProfile profile;
}

/// Accounts and profiles, stored entirely on this device.
///
/// There is no Supabase Auth, no session token and no email confirmation. The
/// session is simply the id of the last profile that signed in, persisted in
/// the same JSON file as everything else.
class AuthRepository {
  AuthRepository(this._store);

  final LocalStore _store;

  UserProfile? _cache;

  UserProfile? get cachedProfile => _cache;

  UserProfile? get currentUser => _cache;

  /// Called on app start: re-attach the profile to the persisted session.
  Future<UserProfile?> restoreSession() async {
    final id = _store.sessionUserId;
    if (id == null) {
      _cache = null;
      return null;
    }
    final row = _store.profileById(id);
    if (row == null) {
      await _store.setSession(null);
      _cache = null;
      return null;
    }
    _cache = UserProfile.fromMap(row);
    return _cache;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final row = _store.profileByEmail(email);
    if (row == null ||
        !LocalPassword.verify(
          password,
          row['password_salt'] as String?,
          row['password_hash'] as String?,
        )) {
      throw const AuthException('Wrong email or password.');
    }

    final status = row['account_status'] as String?;
    if (status == 'pending') {
      throw const AuthException(
        'This account is waiting for the administrator to activate it.',
      );
    }
    if (status == 'suspended') {
      throw const AuthException('This account has been suspended.');
    }

    await _store.setSession(row['id'] as String);
    _cache = UserProfile.fromMap(row);
    return AuthResult(profile: _cache!);
  }

  Future<AuthResult> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? purok,
  }) async {
    final address = email.trim();
    if (_store.profileByEmail(address) != null) {
      throw const AuthException(
        'That email is already registered. Try signing in.',
      );
    }

    final salt = LocalPassword.newSalt();
    final id = newLocalId();
    final now = _store.nowIso();
    final row = <String, dynamic>{
      'id': id,
      'full_name': fullName.trim(),
      'email': address,
      'phone_number': phone?.trim(),
      'role': UserRole.resident.value,
      'account_status': AccountStatus.active.value,
      'barangay': null,
      'purok': (purok == null || purok.trim().isEmpty) ? null : purok.trim(),
      'created_at': now,
      'updated_at': now,
      'password_salt': salt,
      'password_hash': LocalPassword.hash(password, salt),
    };

    _store.profiles.add(row);
    // One write: adding the profile and opening the session share the file.
    await _store.setSession(id);

    _cache = UserProfile.fromMap(row);
    return AuthResult(profile: _cache!);
  }

  Future<void> signOut() async {
    await _store.setSession(null);
    _cache = null;
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

    final row = _store.profileById(current.id);
    if (row == null) {
      throw const AuthException('Your profile could not be loaded.');
    }

    row['full_name'] = (fullName ?? current.fullName).trim();
    row['phone_number'] = phone ?? current.phone;
    row['purok'] = purok ?? current.purok;
    row['updated_at'] = _store.nowIso();
    await _store.save();

    _cache = UserProfile.fromMap(row);
    return _cache!;
  }

  /// Admin-only: change somebody else's role.
  ///
  /// Assigning a role also activates the account, mirroring the old
  /// `updateUserRole` RPC: a pending signup is made usable by the admin.
  Future<UserProfile> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final operator = _store.currentProfile;
    if (operator == null ||
        UserRole.fromValue(operator['role'] as String?) != UserRole.admin) {
      throw const AuthException('Only an administrator can change roles.');
    }

    final row = _store.profileById(userId);
    if (row == null) {
      throw const AuthException('Could not update that account.');
    }

    row['role'] = role.value;
    row['account_status'] = AccountStatus.active.value;
    row['updated_at'] = _store.nowIso();

    // Keep the signed-in profile in sync when the admin edits themselves.
    if (_cache?.id == userId) {
      _cache = UserProfile.fromMap(row);
    }

    await _store.save();
    return UserProfile.fromMap(row);
  }

  Future<List<UserProfile>> listUsers() async {
    final rows = [..._store.profiles]
      ..sort((a, b) => ((a['full_name'] as String?) ?? '')
          .toLowerCase()
          .compareTo(((b['full_name'] as String?) ?? '').toLowerCase()));
    return rows.map(UserProfile.fromMap).toList();
  }

  /// Change the signed-in account's password.
  ///
  /// The current password is required even though the session is already open:
  /// it stops somebody who picked up an unlocked phone from locking the owner
  /// out of their own local account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _cache;
    if (current == null) {
      throw const AuthException('You are not signed in.');
    }
    final row = _store.profileById(current.id);
    if (row == null) {
      throw const AuthException('Your profile could not be loaded.');
    }
    if (!LocalPassword.verify(
      currentPassword,
      row['password_salt'] as String?,
      row['password_hash'] as String?,
    )) {
      throw const AuthException('The current password is not correct.');
    }
    if (newPassword.length < 6) {
      throw const AuthException('Use at least 6 characters.');
    }

    final salt = LocalPassword.newSalt();
    row['password_salt'] = salt;
    row['password_hash'] = LocalPassword.hash(newPassword, salt);
    row['updated_at'] = _store.nowIso();
    await _store.save();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
