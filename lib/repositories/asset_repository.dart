import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../services/supabase_service.dart';

/// Reads and writes the asset inventory.
///
/// Deletion is deliberately not exposed. An asset with history is archived
/// (`archived_at`), which keeps every past booking and report pointing at a
/// real row while removing it from the borrowable list.
class AssetRepository {
  const AssetRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// All non-archived assets, optionally filtered.
  ///
  /// Archived assets are excluded here rather than filtered in Dart so the
  /// list never flickers an item out after it loads.
  Future<List<Asset>> fetchAssets({
    bool includeArchived = false,
    String search = '',
    AssetCategory? category,
    AssetStatus? status,
  }) async {
    var query = _client.from('assets').select();

    if (!includeArchived) {
      query = query.isFilter('archived_at', 'is', null);
    }
    if (search.trim().isNotEmpty) {
      // Match the code or the name. PostgREST's `or` is server-side, so this
      // stays one round trip.
      final term = search.trim();
      query = query.or(
        'name.ilike.%$term%,asset_code.ilike.%$term%',
      );
    }
    if (category != null) {
      query = query.eq('category', category.wire);
    }
    if (status != null) {
      query = query.eq('status', status.wire);
    }

    final data = await query.order('name');
    return _rows(data).map(Asset.fromMap).toList();
  }

  Future<Asset?> fetchAsset(String id) async {
    final data =
        await _client.from('assets').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Asset.fromMap(data);
  }

  /// Looks an asset up by the value encoded in its QR code.
  ///
  /// Scans arrive as free text, so both the QR column and the human-typed
  /// asset code are tried. Returns null rather than throwing when nothing
  /// matches — an unknown code is a normal outcome, not an error.
  Future<Asset?> findByQrValue(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final data = await _client
        .from('assets')
        .select()
        .or('qr_code_value.eq.$value,asset_code.eq.${value.toUpperCase()}')
        .isFilter('archived_at', 'is', null)
        .limit(1);

    final rows = _rows(data);
    return rows.isEmpty ? null : Asset.fromMap(rows.first);
  }

  Future<Asset?> createAsset(Asset asset) async {
    final payload = asset.toMap()..remove('id');
    final data = await _client.from('assets').insert(payload).select().single();
    return Asset.fromMap(data);
  }

  Future<Asset?> updateAsset(Asset asset) async {
    final payload = asset.toMap()
      ..remove('id')
      // Never move an archive back to null through a plain update; that is
      // what `unarchiveAsset` is for.
      ..remove('archived_at');
    final data = await _client
        .from('assets')
        .update(payload)
        .eq('id', asset.id)
        .select()
        .single();
    return Asset.fromMap(data);
  }

  /// Soft-deletes: sets `archived_at` and takes the asset out of circulation.
  Future<void> archiveAsset(String id) async {
    await _client
        .from('assets')
        .update({
          'archived_at': DateTime.now().toIso8601String(),
          'status': AssetStatus.retired.wire,
        })
        .eq('id', id);
  }

  Future<void> setStatus(String id, AssetStatus status) async {
    await _client
        .from('assets')
        .update({'status': status.wire})
        .eq('id', id);
  }

  Future<void> setMaintenanceNote(String id, String note) async {
    await _client
        .from('assets')
        .update({'maintenance_note': note})
        .eq('id', id);
  }

  /// Asset counts grouped by category, for the dashboard.
  Future<Map<AssetCategory, int>> countByCategory() async {
    final data = await _client
        .from('assets')
        .select('category')
        .isFilter('archived_at', 'is', null);
    final counts = <AssetCategory, int>{};
    for (final row in _rows(data)) {
      final category = AssetCategory.fromWire(row['category'] as String?);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  /// Normalises a PostgREST payload into a list of maps.
  ///
  /// `select()` is typed `dynamic`, so it can arrive as null or as a list of
  /// `_Map<String, Object?>`. Casting blindly is the single most common
  /// runtime cast error in a Supabase app, so every read goes through here.
  static List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}