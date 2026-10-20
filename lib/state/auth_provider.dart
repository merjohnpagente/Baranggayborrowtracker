import 'package:flutter/foundation.dart';

import '../data/models/user_profile.dart';
import '../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  UserProfile? _profile;
  bool _initialising = true;
  bool _busy = false;
  String? _error;

  UserProfile? get profile => _profile;

  bool get initialising => _initialising;

  bool get busy => _busy;

  String? get error => _error;

  bool get isSignedIn => _profile != null;

  UserRole get role => _profile?.role ?? UserRole.resident;

  bool get isOfficial => role.isOfficer;

  bool get isAdmin => role.canManageUsers;

  Future<void> bootstrap() async {
    try {
      _profile = await _repository.restoreSession();
    } catch (_) {
      _profile = null;
    } finally {
      _initialising = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _guard(() async {
      final result = await _repository.signIn(email: email, password: password);
      _profile = result.profile;
      return true;
    });
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? purok,
  }) async {
    return _guard(() async {
      final result = await _repository.signUp(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        purok: purok,
      );
      // Local accounts are active immediately: there is no email to confirm
      // and no server-side administrator to wait for.
      _profile = result.profile;
      return true;
    });
  }

  Future<bool> saveProfile({
    String? fullName,
    String? phone,
    String? purok,
  }) async {
    return _guard(() async {
      _profile = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        purok: purok,
      );
      return true;
    });
  }

  Future<bool> changeRole({
    required String userId,
    required UserRole role,
  }) async {
    return _guard(() async {
      await _repository.updateUserRole(userId: userId, role: role);
      return true;
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _guard(() async {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    });
  }

  Future<List<UserProfile>> listUsers() => _repository.listUsers();

  Future<void> signOut() async {
    await _repository.signOut();
    _profile = null;
    notifyListeners();
  }

  Future<void> reloadProfile() async {
    if (!isSignedIn) return;
    _profile = await _repository.restoreSession();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _guard(Future<bool> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
