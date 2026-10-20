import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/asset_category.dart';
import '../supabase_service.dart';

/// Reads and writes `assets`.
///
/// There is no `asset_categories` table in this schema: the category is a
/// Postgres enum on `assets.category`, so there is nothing to join and nothing
/// to administer. [categories] returns the enum values for filter chips.
class AssetRepository {
  AssetRepository(this._client);

  final SupabaseClient _client;

  /// The categories offered in the filter chips, derived from the enum.
  List<AssetCategory> categories() => AssetCategory.values;

  Future<List<Asset>> fetchAssets({
    String? search,
    AssetCategory? category,
    AssetStatus? status,
    bool onlyAvailable = false,
    bool includeArchived = false,
  }) async {
    var query = _client.from('assets').select();

    // Archived rows are filtered in the query rather than in Dart so the list
    // never paints an item and then removes it a frame later.
    if (!includeArchived) {
      query = query.isFilter('archived_at', null);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query = query.or('name.ilike.%$term%,asset_code.ilike.%$term%');
    }
    if (category != null) {
      query = query.eq('category', category.value);
    }
    if (status != null) {
      query = query.eq('status', status.value);
    } else if (onlyAvailable) {
      query = query.eq('status', AssetStatus.available.value);
    }

    final data = await query.order('name', ascending: true);
    return _rows(data).map(Asset.fromMap).toList();
  }

  Future<Asset?> fetchAsset(String id) async {
    final data =
        await _client.from('assets').select().eq('id', id).maybeSingle();
    return data == null ? null : Asset.fromMap(data);
  }

  /// Resolves a scanned QR payload to an asset.
  ///
  /// Both the QR column and the human-typed asset code are tried, because a
  /// printed label and a typed code are both things a user will scan or type.
  /// Returns null rather than throwing: an unrecognised code is a normal
  /// outcome, not an error.
  Future<Asset?> findByCodeOrQr(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final data = await _client
        .from('assets')
        .select()
        .or('qr_code_value.eq.$value,asset_code.eq.${value.toUpperCase()}')
        .isFilter('archived_at', null)
        .limit(1);

    final rows = _rows(data);
    return rows.isEmpty ? null : Asset.fromMap(rows.first);
  }

  Future<Asset> createAsset(Asset asset) async {
    final response =
        await _client.from('assets').insert(asset.toInsert()).select().single();
    return Asset.fromMap(response);
  }

  Future<Asset> updateAsset(String id, Asset asset) async {
    final response = await _client
        .from('assets')
        .update(asset.toUpdate())
        .eq('id', id)
        .select()
        .single();
    return Asset.fromMap(response);
  }

  /// Soft delete.
  ///
  /// Assets are never hard-deleted: `bookings.asset_id` is ON DELETE RESTRICT
  /// precisely because an asset that has been borrowed has history worth
  /// keeping. Archiving takes it out of circulation while leaving the reports
  /// reconciling.
  Future<void> archiveAsset(String id) async {
    await _client
        .from('assets')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> unarchiveAsset(String id) async {
    await _client.from('assets').update({'archived_at': null}).eq('id', id);
  }

  Future<void> setAssetStatus(String id, AssetStatus status) async {
    await _client.from('assets').update({'status': status.value}).eq('id', id);
  }

  /// Whether an asset is free for a given window.
  ///
  /// Delegates to `check_asset_availability`, which is the same function the
  /// approval path uses — so the "is this slot free?" answer shown in the form
  /// cannot disagree with the one the approver gets.
  Future<bool> isAvailableFor({
    required String assetId,
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _client.rpc(
      'check_asset_availability',
      params: {
        'p_asset_id': assetId,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
      },
    );
    return result == true;
  }

  /// Uploads a photo to the public bucket and returns its URL.
  Future<String> uploadPhoto(Uint8List bytes, String fileName) async {
    final path = 'assets/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage
        .from(SupabaseService.photoBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from(SupabaseService.photoBucket).getPublicUrl(path);
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

  /// PostgREST `select()` is typed `dynamic` and can arrive as null or as a
  /// list of `_Map<String, Object?>`. Casting blindly is the single most common
  /// runtime cast error in a Supabase app, so every read goes through here.
  static List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}