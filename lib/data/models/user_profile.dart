/// Roles, mirroring the `user_role` enum in `schema.sql`.
///
/// These values are used for *display and for deciding which buttons to show*.
/// They are **not** the security boundary: the RLS policies call
/// `public.current_user_role()` and re-derive the same answer from the JWT, so
/// hiding a button is only a courtesy. A tampered client still gets nothing.
enum UserRole {
  admin('admin', 'Administrator'),
  staff('staff', 'Barangay Staff'),
  approver('approver', 'Approver'),
  resident('resident', 'Resident');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  /// May see every resident's records, not just their own.
  bool get isOfficer =>
      this == UserRole.admin ||
      this == UserRole.staff ||
      this == UserRole.approver;

  /// May approve or reject requests.
  bool get canApprove => this == UserRole.admin || this == UserRole.approver;

  /// May release an asset or receive it back.
  bool get canHandleAssets => this == UserRole.admin || this == UserRole.staff;

  /// May add, edit or archive assets.
  bool get canManageAssets => this == UserRole.admin;

  /// May change another person's role.
  bool get canManageUsers => this == UserRole.admin;

  static UserRole fromValue(String? value) => values.firstWhere(
        (role) => role.value == value,
        // Anything unrecognised falls back to the least-privileged role rather
        // than to a privileged one.
        orElse: () => UserRole.resident,
      );
}

/// Whether an account may sign in. Mirrors `account_status`.
enum AccountStatus {
  pending('pending', 'Pending verification'),
  active('active', 'Active'),
  suspended('suspended', 'Suspended');

  const AccountStatus(this.value, this.label);

  final String value;
  final String label;

  static AccountStatus fromValue(String? value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => AccountStatus.pending,
      );
}

/// A signed-in person: one row of `profiles`, keyed to `auth.users.id`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.role = UserRole.resident,
    this.accountStatus = AccountStatus.active,
    this.barangay,
    this.purok,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final UserRole role;
  final AccountStatus accountStatus;
  final String? barangay;
  final String? purok;

  /// Initials for the avatar circle: "Juan Dela Cruz" -> "JD".
  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String? ?? '',
        fullName: (map['full_name'] as String?) ?? 'Unknown',
        email: map['email'] as String?,
        phone: map['phone_number'] as String?,
        role: UserRole.fromValue(map['role'] as String?),
        accountStatus: AccountStatus.fromValue(map['account_status'] as String?),
        barangay: map['barangay'] as String?,
        purok: map['purok'] as String?,
      );

  /// Contact details a person may change on themselves.
  ///
  /// `role` and `accountStatus` are absent by construction: there is no
  /// parameter through which a caller could pass them, and the
  /// `guard_profile_privilege_change` trigger would reject them anyway.
  Map<String, dynamic> toSelfUpdate() => {
        'full_name': fullName,
        'phone_number': phone,
        'barangay': barangay,
        'purok': purok,
      };
}