import 'dart:typed_data';

import '../local/ids.dart';
import '../local/local_store.dart';
import '../models/asset.dart';
import '../models/asset_category.dart';

/// Reads and writes the local `assets` list.
///
/// Categories are an enum, not a table, so [categories] just exposes the
/// values for the filter chips.
class AssetRepository {
  AssetRepository(this._store);

  final LocalStore _store;

  List<AssetCategory> categories() => AssetCategory.values;

  Future<List<Asset>> fetchAssets({
    String? search,
    AssetCategory? category,
    AssetStatus? status,
    bool onlyAvailable = false,
    bool includeArchived = false,
  }) async {
    final term = search?.trim().toLowerCase() ?? '';

    final rows = _store.assets.where((row) {
      if (!includeArchived && row['archived_at'] != null) return false;
      if (category != null && row['category'] != category.value) return false;
      if (status != null && row['status'] != status.value) return false;
      if (status == null && onlyAvailable && row['status'] != 'available') {
        return false;
      }
      if (term.isNotEmpty) {
        final name = (row['name'] as String? ?? '').toLowerCase();
        final code = (row['asset_code'] as String? ?? '').toLowerCase();
        if (!name.contains(term) && !code.contains(term)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => ((a['name'] as String?) ?? '')
          .toLowerCase()
          .compareTo(((b['name'] as String?) ?? '').toLowerCase()));

    return rows.map(Asset.fromMap).toList();
  }

  Future<Asset?> fetchAsset(String id) async {
    final row = _store.assetById(id);
    return row == null ? null : Asset.fromMap(row);
  }

  /// Resolves a scanned QR payload to an asset.
  ///
  /// The generated asset QR contains the record id, while a printed label or a
  /// typed-in code is the human-readable asset code. All three are tried.
  /// Returns null rather than throwing: an unrecognised code is a normal
  /// outcome, not an error.
  Future<Asset?> findByCodeOrQr(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final upper = value.toUpperCase();

    for (final row in _store.assets) {
      if (row['archived_at'] != null) continue;
      final qr = (row['qr_code_value'] as String?)?.trim();
      final code = (row['asset_code'] as String?)?.trim();
      if (row['id'] == value ||
          qr == value ||
          code == value ||
          code?.toUpperCase() == upper) {
        return Asset.fromMap(row);
      }
    }
    return null;
  }

  Future<Asset> createAsset(Asset asset) async {
    final row = <String, dynamic>{
      ...asset.toInsert(),
      'id': newLocalId(),
      'archived_at': null,
      'created_at': _store.nowIso(),
      'updated_at': _store.nowIso(),
    };
    _store.assets.add(row);
    await _store.save();
    return Asset.fromMap(row);
  }

  Future<Asset> updateAsset(String id, Asset asset) async {
    final row = _store.assetById(id);
    if (row == null) {
      throw const AssetException('That asset could not be found.');
    }
    row.addAll(asset.toUpdate());
    row['updated_at'] = _store.nowIso();
    await _store.save();
    return Asset.fromMap(row);
  }

  /// Soft delete: the row (and its borrowing history) stays.
  Future<void> archiveAsset(String id) async {
    final row = _store.assetById(id);
    if (row == null) return;
    row['archived_at'] = _store.nowIso();
    await _store.save();
  }

  Future<void> unarchiveAsset(String id) async {
    final row = _store.assetById(id);
    if (row == null) return;
    row['archived_at'] = null;
    await _store.save();
  }

  Future<void> setAssetStatus(String id, AssetStatus status) async {
    final row = _store.assetById(id);
    if (row == null) return;
    row['status'] = status.value;
    row['updated_at'] = _store.nowIso();
    await _store.save();
  }

  /// Whether the asset is free for the half-open window `[start, end)`.
  Future<bool> isAvailableFor({
    required String assetId,
    required DateTime start,
    required DateTime end,
  }) async {
    return _store.isAssetAvailable(assetId, start, end);
  }

  /// Writes a picked image into the app's private photo folder.
  Future<String> savePhoto(Uint8List bytes, String fileName) {
    return _store.savePhoto(bytes, fileName);
  }

  /// Counts by status for the dashboard's filter summary.
  static Map<AssetStatus, int> statusCounts(List<Asset> assets) {
    final counts = <AssetStatus, int>{};
    for (final asset in assets) {
      counts[asset.status] = (counts[asset.status] ?? 0) + 1;
    }
    return counts;
  }

  /// Counts by category for the dashboard's category summary.
  static Map<AssetCategory, int> categoryCounts(List<Asset> assets) {
    final counts = <AssetCategory, int>{};
    for (final asset in assets) {
      counts[asset.category] = (counts[asset.category] ?? 0) + 1;
    }
    return counts;
  }
}

class AssetException implements Exception {
  const AssetException(this.message);

  final String message;

  @override
  String toString() => message;
}
