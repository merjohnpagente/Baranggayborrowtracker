enum AssetStatus {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  borrowed('borrowed', 'Borrowed'),
  maintenance('maintenance', 'Maintenance'),
  retired('retired', 'Retired');

  const AssetStatus(this.value, this.label);

  final String value;
  final String label;

  bool get canRequest =>
      this == AssetStatus.available || this == AssetStatus.reserved;

  static AssetStatus fromValue(String? value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => AssetStatus.available,
      );
}

enum AssetCondition {
  good('good', 'Good'),
  fair('fair', 'Fair'),
  needsRepair('needs_repair', 'Needs repair'),
  damaged('damaged', 'Damaged');

  const AssetCondition(this.value, this.label);

  final String value;
  final String label;

  static AssetCondition fromValue(String? value) => values.firstWhere(
        (condition) => condition.value == value,
        orElse: () => AssetCondition.good,
      );
}

class Asset {
  const Asset({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.condition,
    this.categoryId,
    this.category,
    this.description,
    this.imageUrl,
    this.location,
    this.requiresApproval = true,
    this.depositAmount = 0,
    this.notes,
  });

  final String id;
  final String code;
  final String name;
  final String? categoryId;
  final AssetCategory? category;
  final String? description;
  final String? imageUrl;
  final AssetStatus status;
  final AssetCondition condition;
  final String? location;
  final bool requiresApproval;
  final double depositAmount;
  final String? notes;

  bool get isAvailable => status == AssetStatus.available;

  factory Asset.fromMap(Map<String, dynamic> map) {
    final categoryMap = map['category'];
    return Asset(
      id: map['id'] as String,
      code: (map['code'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed asset',
      categoryId: map['category_id'] as String?,
      category: categoryMap is Map
          ? AssetCategory.fromMap(Map<String, dynamic>.from(categoryMap))
          : null,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      status: AssetStatus.fromValue(map['status'] as String?),
      condition: AssetCondition.fromValue(map['condition'] as String?),
      location: map['location'] as String?,
      requiresApproval: (map['requires_approval'] as bool?) ?? true,
      depositAmount:
          double.tryParse((map['deposit_amount'] ?? '0').toString()) ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toInsert() => {
        'code': code,
        'name': name,
        'category_id': categoryId,
        'description': description,
        'image_url': imageUrl,
        'status': status.value,
        'condition': condition.value,
        'location': location,
        'requires_approval': requiresApproval,
        'deposit_amount': depositAmount,
        'notes': notes,
      };

  Map<String, dynamic> toUpdate() => toInsert();
}