import 'asset_category.dart';

/// Whether an asset can be requested right now.
///
/// Mirrors the `asset_status` enum in `schema.sql`. `status` is kept in sync
/// by the database (`sync_asset_status_on_booking` / `refresh_asset_status`),
/// so the client reads it rather than deriving it.
enum AssetStatus {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  borrowed('borrowed', 'Borrowed'),
  maintenance('maintenance', 'Maintenance'),
  retired('retired', 'Retired');

  const AssetStatus(this.value, this.label);

  final String value;
  final String label;

  /// Only an available asset may be newly requested.
  ///
  /// A *reserved* asset has an approved booking on it for a future window; it
  /// is not up for grabs, so it is excluded here. Overlap is checked per
  /// window by `check_asset_availability`.
  bool get canRequest => this == AssetStatus.available;

  /// Needs somebody to act on it: broken, or out of service.
  bool get needsAttention =>
      this == AssetStatus.maintenance || this == AssetStatus.retired;

  static AssetStatus fromValue(String? value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => AssetStatus.available,
      );
}

/// Physical condition, recorded at release and again at return.
enum AssetCondition {
  good('good', 'Good'),
  serviceable('serviceable', 'Serviceable'),
  minorDamage('minor_damage', 'Minor Damage'),
  majorDamage('major_damage', 'Major Damage'),
  missingItems('missing_items', 'Missing Items');

  const AssetCondition(this.value, this.label);

  final String value;
  final String label;

  /// Anything that is not clean needs an inspector to follow up, not just a
  /// return receipt.
  bool get needsInspection =>
      this == AssetCondition.minorDamage ||
      this == AssetCondition.majorDamage ||
      this == AssetCondition.missingItems;

  static AssetCondition fromValue(String? value) => values.firstWhere(
        (condition) => condition.value == value,
        orElse: () => AssetCondition.good,
      );
}

/// A barangay-owned resource.
///
/// Field names here are Dart-side; the column names are the snake_case wire
/// values in `schema.sql`, and [Asset.fromMap] / [Asset.toInsert] are the only
/// places that know the difference.
class Asset {
  const Asset({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.condition,
    this.category = AssetCategory.other,
    this.description,
    this.imageUrls = const [],
    this.location,
    this.quantity = 1,
    this.plateNumber,
    this.qrCodeValue,
    this.maintenanceNote,
    this.archivedAt,
  });

  final String id;

  /// Human asset code, e.g. `VEH-001` (`assets.asset_code`, unique).
  final String code;

  final String name;
  final AssetCategory category;
  final String? description;

  /// `assets.image_urls` is a Postgres `text[]`.
  final List<String> imageUrls;

  final String? location;

  /// How many of this item the barangay owns. Chairs and tables are counted;
  /// a vehicle is 1.
  final int quantity;

  final AssetCondition condition;
  final AssetStatus status;
  final String? plateNumber;

  /// The payload encoded in the asset's QR label.
  final String? qrCodeValue;

  final String? maintenanceNote;

  /// Soft delete. An archived asset keeps its history but is not requestable.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  /// A request may only be filed for an asset that is available and not
  /// archived. The database re-checks this in `check_asset_availability`.
  bool get canRequest => !isArchived && status.canRequest;

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as String? ?? '',
      code: (map['asset_code'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed asset',
      category: AssetCategory.fromValue(map['category'] as String?),
      description: map['description'] as String?,
      imageUrls: _stringList(map['image_urls']),
      location: map['location'] as String?,
      quantity: _int(map['quantity'], fallback: 1),
      condition: AssetCondition.fromValue(map['condition'] as String?),
      status: AssetStatus.fromValue(map['status'] as String?),
      plateNumber: map['plate_number'] as String?,
      // Fall back to the code so a row inserted without an explicit QR value
      // still scans back to the right asset.
      qrCodeValue: (map['qr_code_value'] as String?) ?? map['asset_code'] as String?,
      maintenanceNote: map['maintenance_note'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.tryParse(map['archived_at'].toString()),
    );
  }

  /// Columns for INSERT. `id` is omitted so Postgres generates the uuid.
  Map<String, dynamic> toInsert() => {
        'asset_code': code,
        'name': name,
        'category': category.value,
        'description': description,
        'image_urls': imageUrls,
        'location': location,
        'quantity': quantity,
        'condition': condition.value,
        'status': status.value,
        'plate_number': plateNumber,
        'qr_code_value': qrCodeValue ?? code,
        'maintenance_note': maintenanceNote,
      };

  /// Columns for UPDATE. `archived_at` is deliberately absent: archiving is
  /// its own action, not something a form edit can undo by omission.
  Map<String, dynamic> toUpdate() => toInsert();

  /// A Postgres `text[]` round-trips as a Dart `List`, but a column that has
  /// been cast to text or json can come back as a bracketed string. Accept all
  /// three rather than losing every photo.
  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    final raw = value.toString().replaceAll(RegExp(r'^\[|\]$'), '');
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int _int(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}