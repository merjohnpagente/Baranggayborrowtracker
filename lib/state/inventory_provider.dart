import 'package:flutter/foundation.dart';

import '../data/models/asset.dart';
import '../data/models/asset_category.dart';
import '../data/repositories/asset_repository.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider(this._assets);

  final AssetRepository _assets;

  List<Asset> _items = const [];
  List<AssetCategory> _categories = const [];
  bool _loading = false;
  bool _categoriesLoaded = false;
  String? _error;

  String _search = '';
  AssetCategory? _category;
  AssetStatus? _status;
  bool _onlyAvailable = false;

  List<Asset> get assets => _items;

  List<AssetCategory> get categories => _categories;

  bool get loading => _loading;

  String? get error => _error;

  String get search => _search;

  AssetCategory? get category => _category;

  AssetStatus? get status => _status;

  bool get onlyAvailable => _onlyAvailable;

  int get availableCount =>
      _items.where((a) => a.status == AssetStatus.available).length;

  int get borrowedCount =>
      _items.where((a) => a.status == AssetStatus.borrowed).length;

  int get totalCount => _items.length;

  bool get hasFilters =>
      _search.isNotEmpty ||
      _category != null ||
      _status != null ||
      _onlyAvailable;

  /// Categories are an enum in Postgres, not a table, so there is nothing to
  /// fetch. Populate the list from the enum once for the filter chips.
  Future<void> loadCategories({bool force = false}) async {
    if (_categoriesLoaded && !force) return;
    _categories = _assets.categories();
    _categoriesLoaded = true;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _assets.fetchAssets(
        search: _search,
        category: _category,
        status: _status,
        onlyAvailable: _onlyAvailable,
      );
      await loadCategories();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      _items = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadCategories(force: true);
    await load();
  }

  void setSearch(String value) {
    _search = value;
  }

  /// Tapping the selected chip again clears the filter.
  void setCategory(AssetCategory? value) {
    _category = _category == value ? null : value;
    load();
  }

  void setStatus(AssetStatus? status) {
    _status = status;
    load();
  }

  void toggleOnlyAvailable() {
    _onlyAvailable = !_onlyAvailable;
    load();
  }

  void clearFilters() {
    _search = '';
    _category = null;
    _status = null;
    _onlyAvailable = false;
    load();
  }

  /// Applies a locally created/updated asset without a full refetch.
  void upsertLocally(Asset asset) {
    final next = [..._items];
    final index = next.indexWhere((a) => a.id == asset.id);
    if (index >= 0) {
      next[index] = asset;
    } else {
      next.add(asset);
    }
    _items = next;
    notifyListeners();
  }

  void removeLocally(String id) {
    _items = _items.where((a) => a.id != id).toList();
    notifyListeners();
  }

  Asset? byId(String id) {
    for (final asset in _items) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Future<Asset?> lookupByCode(String code) async {
    try {
      return await _assets.findByCodeOrQr(code);
    } catch (_) {
      return null;
    }
  }
}