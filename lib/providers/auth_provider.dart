import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../services/supabase_service.dart';

/// Who is signed in, and what they are allowed to see.
///
/// This holds the *session*, not permissions. Every screen asks this provider
/// whether to show a button, but the same checks are enforced a second time by
/// the RLS policies in Postgres — hiding a button is a courtesy, the policy is
/// the control. The two are kept in step because the SQL policies call the
/// same role values that [UserRole] uses.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _auth = const AuthRepository();

  UserProfile? _profile;
  bool _busy = false;
  String? _error;
  bool _initialised = false;

  UserProfile? get profile => _profile;
  bool get isSignedIn => _profile != null;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isInitialised => _initialised;

  /// True when the app is running against demo data (no Supabase configured).
  bool get isDemo => SupabaseService.isDemo;

  UserRole get role => _profile?.role ?? UserRole.resident;
  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role == UserRole.staff || isAdmin;
  bool get isApprover => role == UserRole.approver || isAdmin;
  bool get isOfficer => isStaff || isApprover;

  /// Called once at startup. Reads any stored session so the splash screen can
  /// route straight to the home screen for a returning user.
  Future<void> restore() async {
    if (_initialised) return;
    _initialised = true;

    if (SupabaseService.isDemo) {
      // Demo mode has no real account; a resident profile keeps the UI usable
      // and the banner explains the rest.
      _profile = _demoProfile;
      notifyListeners();
      return;
    }

    final hasSession = await SupabaseService.hasStoredSession();
    if (!hasSession) {
      notifyListeners();
      return;
    }
    _profile = await _auth.fetchProfile(SupabaseService.currentUserId);
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setBusy(true);
    final result = await _auth.signIn(email: email, password: password);
    _setBusy(false);
    if (!result.success) {
      _setError(result.error);
      return false;
    }
    _profile = result.profile;
    _setError(null);
    return true;
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String? barangay,
    String? purok,
  }) async {
    _setBusy(true);
    final result = await _auth.signUp(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
      barangay: barangay,
      purok: purok,
    );
    _setBusy(false);
    if (!result.success) {
      _setError(result.error);
      return false;
    }
    _profile = result.profile ?? _demoProfile;
    _setError(null);
    return true;
  }

  /// Sent to a [resetPassword] screen. Returns the message to show, which is
  /// deliberately the same whether or not the account exists.
  Future<String> resetPassword(String email) => _auth.resetPassword(email);

  Future<void> signOut() async {
    await _auth.signOut();
    _profile = null;
    _setError(null);
    notifyListeners();
  }

  /// Re-reads the profile after the user edits their own details.
  Future<void> refreshProfile() async {
    if (SupabaseService.isDemo) return;
    _profile = await _auth.fetchProfile(SupabaseService.currentUserId);
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  static final UserProfile _demoProfile = UserProfile(
    id: 'demo-resident-1',
    fullName: 'Juan Dela Cruz',
    email: 'demo@barangay.gov.ph',
    phoneNumber: '0917 000 0001',
    role: UserRole.resident,
    accountStatus: AccountStatus.active,
  );
}