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

  bool get isOfficial => role.canManageInventory;

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
    String? address,
  }) async {
    return _guard(() async {
      final result = await _repository.signUp(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        address: address,
      );
      if (result.needsEmailConfirmation) {
        // Stay signed out until the link in the inbox is used.
        return false;
      }
      _profile = result.profile;
      return true;
    });
  }

  Future<bool> sendPasswordReset(String email) async {
    return _guard(() async {
      await _repository.sendPasswordReset(email);
      return true;
    });
  }

  Future<bool> saveProfile({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    return _guard(() async {
      _profile = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        address: address,
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
      final result = await action();
      return result;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    final text = error.toString();
    if (error is AuthException) return text;
    if (text.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (text.contains('User already registered')) {
      return 'That email is already registered. Try signing in.';
    }
    if (text.contains('Email not confirmed')) {
      return 'Confirm your email address first.';
    }
    if (text.contains('rate limit') || text.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (text.contains('Failed host lookup') || text.contains('connection')) {
      return 'No internet connection. Check your data and try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}