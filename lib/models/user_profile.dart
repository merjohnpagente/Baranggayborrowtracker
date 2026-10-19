import 'package:flutter/material.dart';

/// Who a person is in the barangay. Stored in Postgres as `user_role`.
///
/// The order matters only for display; permissions live in the database
/// policies, never in this list. Public registration can only ever create a
/// [resident] — see `sign_up` in the SQL setup.
enum UserRole {
  admin('admin', 'Administrator'),
  staff('staff', 'Barangay Staff'),
  approver('approver', 'Approver'),
  resident('resident', 'Resident');

  const UserRole(this.wire, this.label);

  /// The value stored in Postgres. Must match the `user_role` enum in SQL.
  final String wire;
  final String label;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        // Unknown roles must never be escalated. Anything unrecognised falls
        // back to the least-privileged role.
        orElse: () => UserRole.resident,
      );

  /// Roles allowed to see every resident's records.
  bool get canManageAll =>
      this == UserRole.admin || this == UserRole.staff || this == UserRole.approver;

  /// Roles allowed to approve or reject a request.
  bool get canApprove => this == UserRole.admin || this == UserRole.approver;

  /// Roles allowed to hand an asset over or take it back.
  bool get canReleaseOrReceive =>
      this == UserRole.admin || this == UserRole.staff;

  /// Roles allowed to add, edit or archive assets.
  bool get canManageAssets => this == UserRole.admin;

  bool get isStaff => this == UserRole.admin || this == UserRole.staff;

  IconData get icon => switch (this) {
        UserRole.admin => Icons.admin_panel_settings,
        UserRole.staff => Icons.badge_outlined,
        UserRole.approver => Icons.verified_outlined,
        UserRole.resident => Icons.person_outline,
      };
}

/// Whether an account may sign in. `pending` is the default for a new sign-up
/// so nobody borrows a vehicle by registering and logging straight in.
enum AccountStatus {
  pending('pending', 'Pending verification'),
  active('active', 'Active'),
  suspended('suspended', 'Suspended');

  const AccountStatus(this.wire, this.label);

  final String wire;
  final String label;

  static AccountStatus fromWire(String? value) =>
      AccountStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AccountStatus.pending,
      );
}

/// A signed-in person. `profiles` row joined with the Supabase auth user.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final UserRole role;
  final AccountStatus accountStatus;
  final String? barangay;
  final String? purok;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.role = UserRole.resident,
    this.accountStatus = AccountStatus.active,
    this.barangay,
    this.purok,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id']?.toString() ?? '',
        fullName: map['full_name'] as String? ?? 'Unknown',
        email: map['email'] as String? ?? '',
        phoneNumber: map['phone_number'] as String?,
        role: UserRole.fromWire(map['role'] as String?),
        accountStatus: AccountStatus.fromWire(map['account_status'] as String?),
        barangay: map['barangay'] as String?,
        purok: map['purok'] as String?,
        createdAt: _parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'role': role.wire,
        'account_status': accountStatus.wire,
        'barangay': barangay,
        'purok': purok,
        'created_at': createdAt?.toIso8601String(),
      };

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    AccountStatus? accountStatus,
    String? barangay,
    String? purok,
  }) =>
      UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        role: role ?? this.role,
        accountStatus: accountStatus ?? this.accountStatus,
        barangay: barangay ?? this.barangay,
        purok: purok ?? this.purok,
        createdAt: createdAt,
      );

  /// Initials for the avatar circle, e.g. "Juan Dela Cruz" -> "JD".
  ///
  /// Uses [String.substring] rather than the `characters` extension so this
  /// file does not depend on `package:characters` being re-exported.
  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}