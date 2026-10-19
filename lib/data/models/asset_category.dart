/// Asset categories.
///
/// In Postgres this is the `asset_category` **enum**, not a lookup table, so
/// there is nothing to join and nothing to cache — the values are fixed by
/// `schema.sql` and adding one is a migration, not an admin action.
enum AssetCategory {
  vehicle('vehicle', 'Service Vehicle', 'directions_car'),
  facility('facility', 'Facility', 'sports_basketball'),
  equipment('equipment', 'Equipment', 'campaign'),
  furniture('furniture', 'Furniture', 'chair'),
  shelter('shelter', 'Shelter', 'holiday_village'),
  electronics('electronics', 'Electronics', 'tv'),
  power('power', 'Power', 'electrical_services'),
  other('other', 'Other', 'inventory_2');

  const AssetCategory(this.value, this.label, this.icon);

  /// The wire value stored in Postgres. Must match `asset_category`.
  final String value;

  /// Human label for filters and chips.
  final String label;

  /// A Material icon name, mapped to a glyph in `AssetPhoto`.
  final String icon;

  static AssetCategory fromValue(String? value) => values.firstWhere(
        (c) => c.value == value,
        // An unknown category must not hide the asset; `other` keeps it
        // visible in the inventory and reservable.
        orElse: () => AssetCategory.other,
      );
}