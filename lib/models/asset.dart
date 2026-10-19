import 'package:flutter/material.dart';

/// What an asset is. Stored in Postgres as `asset_category`.
///
/// The wire names are stable: they are what the QR labels, the filter chips and
/// the database all agree on, so renaming a label here is safe but renaming a
/// [wire] value would orphan existing rows.
enum AssetCategory {
  vehicle('vehicle', 'Service Vehicle', Icons.directions_car),
  facility('facility', 'Facility', Icons.stadium),
  equipment('equipment', 'Equipment', Icons.mic),
  event('event', 'Event', Icons.celebration);

  const AssetCategory(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static AssetCategory fromWire(String? value) => AssetCategory.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => AssetCategory.equipment,
      );
}

/// Whether an asset can be borrowed right now.
///
/// [maintenance] is deliberately a first-class status rather than a flag on
/// [available]: business rule 9 says an asset under maintenance must not be
/// reservable, and the cleanest way to guarantee that is to make it impossible
/// to be [available] while maintenance is open.
enum AssetStatus {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  borrowed('borrowed', 'Borrowed'),
  maintenance('maintenance', 'Under Maintenance');

  const AssetStatus(this.wire, this.label);

  final String wire;
  final String label;

  static AssetStatus fromWire(String? value) => AssetStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => AssetStatus.available,
      );

  /// Only these may be reserved. Everything else is blocked at the form, at
  /// approval time, and again by the database.
  bool get isReservable => this == AssetStatus.available;
}

/// Condition recorded at release and again at return.
enum AssetCondition {
  good('good', 'Good', Icons.check_circle_outline),
  fair('fair', 'Fair', Icons.build_outlined),
  minorDamage('minor_damage', 'Minor Damage', Icons.warning_amber),
  majorDamage('major_damage', 'Major Damage', Icons.dangerous_outlined),
  missingItems('missing_items', 'Missing Items', Icons.help_outline);

  const AssetCondition(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static AssetCondition fromWire(String? value) =>
      AssetCondition.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => AssetCondition.good,
      );

  /// Anything other than [good] or [fair] needs an inspection follow-up.
  bool get needsInspection =>
      this == AssetCondition.minorDamage ||
      this == AssetCondition.majorDamage ||
      this == AssetCondition.missingItems;
}

/// A barangay-owned resource: a vehicle, a court, a sound system, and so on.
class Asset {
  final String id;
  final String assetCode;
  final String name;
  final AssetCategory category;
  final String? description;
  final List<String> imageUrls;
  final String? location;
  final String? plateNumber;
  final int quantity;
  final AssetCondition condition;
  final AssetStatus status;

  /// Stable payload encoded in the asset's QR code, e.g. `BBT:VEH-001`.
  final String qrValue;
  final DateTime? createdAt;
  final DateTime? archivedAt;

  const Asset({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.category,
    this.description,
    this.imageUrls = const [],
    this.location,
    this.plateNumber,
    this.quantity = 1,
    this.condition = AssetCondition.good,
    this.status = AssetStatus.available,
    this.qrValue = '',
    this.createdAt,
    this.archivedAt,
  });

  factory Asset.fromMap(Map<String, dynamic> map) => Asset(
        id: map['id']?.toString() ?? '',
        assetCode: map['asset_code'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: AssetCategory.fromWire(map['category'] as String?),
        description: map['description'] as String?,
        imageUrls: _stringList(map['image_urls']),
        location: map['location'] as String?,
        plateNumber: map['plate_number'] as String?,
        quantity: _int(map['quantity'], 1),
        condition: AssetCondition.fromWire(map['condition'] as String?),
        status: AssetStatus.fromWire(map['status'] as String?),
        qrValue: map['qr_value'] as String? ?? '',
        createdAt: _date(map['created_at']),
        archivedAt: _date(map['archived_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'asset_code': assetCode,
        'name': name,
        'category': category.wire,
        'description': description,
        'image_urls': imageUrls,
        'location': location,
        'plate_number': plateNumber,
        'quantity': quantity,
        'condition': condition.wire,
        'status': status.wire,
        'qr_value': qrValue,
        'created_at': createdAt?.toIso8601String(),
        'archived_at': archivedAt?.toIso8601String(),
      };

  Asset copyWith({
    String? name,
    AssetCategory? category,
    String? description,
    List<String>? imageUrls,
    String? location,
    String? plateNumber,
    int? quantity,
    AssetCondition? condition,
    AssetStatus? status,
    DateTime? archivedAt,
  }) =>
      Asset(
        id: id,
        assetCode: assetCode,
        name: name ?? this.name,
        category: category ?? this.category,
        description: description ?? this.description,
        imageUrls: imageUrls ?? this.imageUrls,
        location: location ?? this.location,
        plateNumber: plateNumber ?? this.plateNumber,
        quantity: quantity ?? this.quantity,
        condition: condition ?? this.condition,
        status: status ?? this.status,
        qrValue: qrValue,
        createdAt: createdAt,
        archivedAt: archivedAt ?? this.archivedAt,
      );

  bool get isArchived => archivedAt != null;

  /// An archived asset stays readable forever so its borrowing history and
  /// reports survive, but it must never be reservable again.
  bool get isReservable => !isArchived && status.isReservable;

  /// Vehicles need a named, authorised driver on the request.
  bool get requiresDriver => category == AssetCategory.vehicle;

  String? get primaryImage => imageUrls.isEmpty ? null : imageUrls.first;

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    // Postgres text[] arrives as a String literal like "{a,b}" when it comes
    // back through an untyped jsonb cast.
    if (value is String && value.startsWith('{')) {
      return value
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  static int _int(Object? value, int fallback) =>
      value is int ? value : int.tryParse('$value') ?? fallback;

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}