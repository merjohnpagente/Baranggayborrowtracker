import 'package:flutter/material.dart';

enum UserRole {
  resident('resident', 'Resident'),
  official('official', 'Barangay Official'),
  admin('admin', 'Administrator');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  bool get canManageInventory => this != UserRole.resident;

  bool get canApprove => this != UserRole.resident;

  bool get canManageUsers => this == UserRole.admin;

  static UserRole fromValue(String? value) => values.firstWhere(
        (role) => role.value == value,
        orElse: () => UserRole.resident,
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.address,
    this.avatarUrl,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? address;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? createdAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? 'Unknown',
      role: UserRole.fromValue(map['role'] as String?),
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
    );
  }

  UserProfile copyWith({
    String? fullName,
    UserRole? role,
    String? phone,
    String? address,
    String? avatarUrl,
    bool? isActive,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toUpdate() => {
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Widget get avatar => CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE0F2F1),
        backgroundImage:
            avatarUrl == null ? null : NetworkImage(avatarUrl!),
        child: Text(
          _initials,
          style: const TextStyle(
            color: Color(0xFF00695C),
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  String get _initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}