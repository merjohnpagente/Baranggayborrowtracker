import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';

/// Result of an auth call. Sign-in and sign-up are both "successful" in more
/// than one sense, and the screens need to tell the cases apart: a sign-up
/// that requires email confirmation is not a failure, and neither is a
/// correctly-rejected password.
class AuthOutcome {
  final bool success;
  final String? error;
  final UserProfile? profile;

  /// True when the account was created but still needs to confirm an email.
  final bool needsConfirmation;

  /// True when the app is running on demo data and the action was a no-op.
  final bool demoMode;

  const AuthOutcome({
    required this.success,
    this.error,
    this.profile,
    this.needsConfirmation = false,
    this.demoMode = false,
  });
}

/// Sign-in, sign-up, password reset and profile reads.
///
/// Roles never come from the client. A new sign-up is always created as a
/// `resident` with `account_status = 'pending'` by a database trigger, so
/// there is no code path — here or anywhere else — that can hand someone an
/// administrator account.
class AuthRepository {
  const AuthRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// Signs in with email and password.
  Future<AuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseService.isDemo) {
      return const AuthOutcome(success: true, demoMode: true);
    }
    try {
      final response = await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      final profile = await fetchProfile(response.user?.id);
      return AuthOutcome(success: true, profile: profile);
    } catch (error) {
      return AuthOutcome(
        success: false,
        error: SupabaseService.describeError(error),
      );
    }
  }

  /// Creates an account. The role is never sent from here on purpose — the
  /// `handle_new_user` trigger in the schema assigns `resident` / `pending`.
  Future<AuthOutcome> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String? barangay,
    String? purok,
  }) async {
    if (SupabaseService.isDemo) {
      return const AuthOutcome(success: true, demoMode: true);
    }
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // `data` is merged into the trigger payload, which is where the
        // profile row is created from.
        data: {
          'full_name': fullName.trim(),
          'phone_number': phoneNumber.trim(),
          'barangay': barangay?.trim(),
          'purok': purok?.trim(),
        },
      );
      // No session means Supabase is waiting for an email confirmation.
      final needsConfirmation = response.session == null;
      final profile = await fetchProfile(response.user?.id);
      return AuthOutcome(
        success: true,
        needsConfirmation: needsConfirmation,
        profile: profile,
      );
    } catch (error) {
      return AuthOutcome(
        success: false,
        error: SupabaseService.describeError(error),
      );
    }
  }

  /// Reads the signed-in user's profile row.
  Future<UserProfile?> fetchProfile(String? userId) async {
    if (SupabaseService.isDemo) return null;
    final uid = userId ?? SupabaseService.currentUserId;
    if (uid == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  /// Sends the reset email. Deliberately returns success even when the
  /// account does not exist: telling a stranger which emails are registered is
  /// an account-enumeration leak.
  Future<AuthOutcome> resetPassword(String email) async {
    if (SupabaseService.isDemo) {
      return const AuthOutcome(success: true, demoMode: true);
    }
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return const AuthOutcome(success: true);
    } catch (error) {
      return AuthOutcome(
        success: false,
        error: SupabaseService.describeError(error),
      );
    }
  }

  Future<void> signOut() async {
    if (SupabaseService.isDemo) return;
    await _client.auth.signOut();
  }

  /// Updates only the fields a resident is allowed to change for themselves.
  ///
  /// `role` and `account_status` are absent by construction: there is no
  /// parameter through which a caller could pass them.
  Future<AuthOutcome> updateOwnProfile({
    required String fullName,
    String? phoneNumber,
    String? barangay,
    String? purok,
  }) async {
    if (SupabaseService.isDemo) {
      return const AuthOutcome(success: true, demoMode: true);
    }
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName.trim(),
            'phone_number': phoneNumber?.trim(),
            'barangay': barangay?.trim(),
            'purok': purok?.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', SupabaseService.currentUserId ?? '');
      return const AuthOutcome(success: true);
    } catch (error) {
      return AuthOutcome(
        success: false,
        error: SupabaseService.describeError(error),
      );
    }
  }
}