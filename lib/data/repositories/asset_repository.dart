import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/asset_category.dart';
import '../supabase_service.dart';

class AssetRepository {
  AssetRepository(this._client);

  final SupabaseClient _client;

  static const String _selectWithCategory =
      '*, category:asset_categories(*)';

  Future<List<AssetCategory>> fetchCategories() async {
    final data = await _client
        .from('asset_categories')
        .select('*')
        .order('name', ascending: true);
    return (data as List)
        .map((row) => AssetCategory.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<AssetCategory> createCategory(String name, String description) async {
    final response = await _client
        .from('asset_categories')
        .insert({'name': name.trim(), 'description': description.trim()})
        .select()
        .single();
    return AssetCategory.fromMap(response);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('asset_categories').delete().eq('id', id);
  }

  Future<List<Asset>> fetchAssets({
    String? search,
    String? categoryId,
    AssetStatus? status,
    bool onlyAvailable = false,
  }) async {
    var query = _client.from('assets').select(_selectWithCategory);

    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query = query.or('name.ilike.%$term%,code.ilike.%$term%');
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (status != null) {
      query = query.eq('status', status.value);
    } else if (onlyAvailable) {
      query = query.eq('status', AssetStatus.available.value);
    }

    final data = await query.order('name', ascending: true);
    return (data as List)
        .map((row) => Asset.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Asset?> fetchAsset(String id) async {
    final data = await _client
        .from('assets')
        .select(_selectWithCategory)
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : Asset.fromMap(data);
  }

  Future<Asset?> findByCode(String code) async {
    final data = await _client
        .from('assets')
        .select(_selectWithCategory)
        .eq('code', code.trim())
        .maybeSingle();
    return data == null ? null : Asset.fromMap(data);
  }

  Future<Asset> createAsset(Asset asset) async {
    final response = await _client
        .from('assets')
        .insert(asset.toInsert())
        .select(_selectWithCategory)
        .single();
    return Asset.fromMap(response);
  }

  Future<Asset> updateAsset(String id, Asset asset) async {
    final response = await _client
        .from('assets')
        .update(asset.toUpdate())
        .eq('id', id)
        .select(_selectWithCategory)
        .single();
    return Asset.fromMap(response);
  }

  Future<void> setAssetStatus(String id, AssetStatus status) async {
    await _client
        .from('assets')
        .update({'status': status.value})
        .eq('id', id);
  }

  Future<void> deleteAsset(String id) async {
    await _client.from('assets').delete().eq('id', id);
  }

  /// Uploads a photo to the `asset-photos` bucket and returns its public URL.
  Future<String?> uploadPhoto(Uint8List bytes, String fileName) async {
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

  Future<Map<AssetStatus, int>> statusCounts(List<Asset> assets) {
    final counts = <AssetStatus, int>{};
    for (final asset in assets) {
      counts[asset.status] = (counts[asset.status] ?? 0) + 1;
    }
    return counts;
  }
}