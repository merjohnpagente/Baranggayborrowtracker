class AssetCategory {
  const AssetCategory({
    required this.id,
    required this.name,
    this.icon = 'category',
    this.description,
  });

  final String id;
  final String name;
  final String icon;
  final String? description;

  factory AssetCategory.fromMap(Map<String, dynamic> map) {
    return AssetCategory(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Uncategorised',
      icon: (map['icon'] as String?) ?? 'category',
      description: map['description'] as String?,
    );
  }
}