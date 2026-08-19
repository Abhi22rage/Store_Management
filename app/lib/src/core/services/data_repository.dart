import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class DataRepository extends ChangeNotifier {
  static final DataRepository _instance = DataRepository._internal();
  factory DataRepository() => _instance;
  DataRepository._internal();

  final ApiService _apiService = ApiService();
  RealtimeChannel? _realtimeChannel;

  // In-Memory Caches
  final Map<String, List<dynamic>> _inventoryCache = {};
  final Map<String, List<dynamic>> _salesCache = {};
  final Map<String, List<dynamic>> _purchasesCache = {};
  List<dynamic>? _categoriesCache;
  List<dynamic>? _suppliersCache;

  // Cache Timestamps
  final Map<String, DateTime> _inventoryTimestamps = {};
  final Map<String, DateTime> _salesTimestamps = {};
  final Map<String, DateTime> _purchasesTimestamps = {};
  DateTime? _categoriesTimestamp;
  DateTime? _suppliersTimestamp;

  static const Duration _cacheDuration = Duration(minutes: 3);

  final Map<String, String> _savedItemBarcodes = {};

  /// Initializes disk persistence, warms up ApiService UUID mappings, and connects Realtime listeners
  Future<void> init() async {
    await _apiService.warmupCaches();
    await _loadDiskCaches();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public_realtime_sync');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'items',
            callback: (payload) {
              getInventory(forceRefresh: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sales',
            callback: (payload) {
              getSales(forceRefresh: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime setup error: $e');
    }
  }

  Future<void> _loadDiskCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catJson = prefs.getString('cached_categories');
      if (catJson != null && catJson.isNotEmpty) {
        _categoriesCache = jsonDecode(catJson) as List<dynamic>;
      }
      final suppJson = prefs.getString('cached_suppliers');
      if (suppJson != null && suppJson.isNotEmpty) {
        _suppliersCache = jsonDecode(suppJson) as List<dynamic>;
      }
      final bcJson = prefs.getString('saved_item_barcodes');
      if (bcJson != null && bcJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(bcJson);
        decoded.forEach((k, v) {
          if (v != null) _savedItemBarcodes[k] = v.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading disk cache: $e');
    }
  }

  /// Persistently saves an item's barcode in local storage so it persists across refreshes
  Future<void> saveItemBarcode(String? itemId, String? itemName, String barcode) async {
    if (barcode.trim().isEmpty) return;
    final bc = barcode.trim();
    final idKey = itemId?.trim().toLowerCase() ?? '';
    final nameKey = itemName?.trim().toLowerCase() ?? '';

    if (idKey.isNotEmpty) _savedItemBarcodes[idKey] = bc;
    if (nameKey.isNotEmpty) _savedItemBarcodes[nameKey] = bc;

    // Immediately update any in-memory inventory items across branches
    _inventoryCache.forEach((_, list) {
      for (var item in list) {
        if (item is Map<String, dynamic>) {
          final iId = item['id']?.toString().toLowerCase() ?? '';
          final iName = item['name']?.toString().toLowerCase() ?? '';
          if ((idKey.isNotEmpty && iId == idKey) || (nameKey.isNotEmpty && iName == nameKey)) {
            item['barcode'] = bc;
          }
        }
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_item_barcodes', jsonEncode(_savedItemBarcodes));
    } catch (e) {
      debugPrint('Error saving barcode cache: $e');
    }
    notifyListeners();
  }

  void _enrichBarcodes(List<dynamic> items) {
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        final itemId = item['id']?.toString().toLowerCase() ?? '';
        final itemName = item['name']?.toString().toLowerCase() ?? '';

        final savedBc = (itemId.isNotEmpty ? _savedItemBarcodes[itemId] : null) ??
                        (itemName.isNotEmpty ? _savedItemBarcodes[itemName] : null);

        if (savedBc != null && savedBc.isNotEmpty) {
          item['barcode'] = savedBc;
        } else {
          final existingBarcode = item['barcode']?.toString() ?? '';
          if (existingBarcode.isNotEmpty) {
            if (itemId.isNotEmpty) _savedItemBarcodes[itemId] = existingBarcode;
            if (itemName.isNotEmpty) _savedItemBarcodes[itemName] = existingBarcode;
          }
        }
      }
    }
  }

  // ─── INVENTORY ───────────────────────────────────────────────────

  List<dynamic>? getCachedInventory(String? branch) {
    final key = branch ?? 'default';
    final items = _inventoryCache[key];
    if (items != null) _enrichBarcodes(items);
    return items;
  }

  Future<List<dynamic>> getInventory({
    String? branch,
    bool forceRefresh = false,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  }) async {
    final key = branch ?? 'default';
    final cached = _inventoryCache[key];
    final lastFetch = _inventoryTimestamps[key];
    final isStale = lastFetch == null || DateTime.now().difference(lastFetch) > _cacheDuration;

    // Load from disk if in-memory is empty
    if (cached == null) {
      final diskData = await _readDiskList('cached_inventory_$key');
      if (diskData != null && diskData.isNotEmpty) {
        _enrichBarcodes(diskData);
        _inventoryCache[key] = diskData;
      }
    }

    final availableCache = _inventoryCache[key];

    if (!forceRefresh && availableCache != null && availableCache.isNotEmpty) {
      if (isStale) {
        // Trigger background refresh without blocking
        _refreshInventory(branch, key, onBackgroundRefreshed);
      }
      _enrichBarcodes(availableCache);
      return availableCache;
    }

    return await _refreshInventory(branch, key, onBackgroundRefreshed);
  }

  Future<List<dynamic>> _refreshInventory(
    String? branch,
    String key,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  ) async {
    try {
      final fresh = await _apiService.getInventory(branch: branch);
      _enrichBarcodes(fresh);
      _inventoryCache[key] = fresh;
      _inventoryTimestamps[key] = DateTime.now();
      _saveDiskList('cached_inventory_$key', fresh);
      notifyListeners();
      onBackgroundRefreshed?.call(fresh);
      return fresh;
    } catch (e) {
      if (_inventoryCache.containsKey(key)) return _inventoryCache[key]!;
      rethrow;
    }
  }

  void updateLocalItemStock(String itemId, Map<String, dynamic> updateData) {
    _inventoryCache.forEach((branchKey, items) {
      for (var item in items) {
        if (item is Map<String, dynamic> && item['id']?.toString() == itemId) {
          if (updateData.containsKey('stock')) {
            item['stock'] = updateData['stock'];
          }
          if (updateData.containsKey('variants') && updateData['variants'] is List) {
            item['variants'] = updateData['variants'];
            if (item.containsKey('items_size') && item['items_size'] is List) {
              final newRelSizes = <Map<String, dynamic>>[];
              for (var v in (updateData['variants'] as List)) {
                if (v is Map && v['sizes'] is List) {
                  for (var sz in (v['sizes'] as List)) {
                    if (sz is Map) {
                      newRelSizes.add({
                        'variant_id': v['id'],
                        'variant_name': v['color'],
                        'size': sz['size'],
                        'stock': sz['stock'],
                        'cost_price': sz['cost_price'] ?? sz['costPrice'] ?? 0.0,
                        'retail_price': sz['retail_price'] ?? sz['retailPrice'] ?? 0.0,
                        'barcode': sz['barcode'] ?? '',
                      });
                    }
                  }
                }
              }
              item['items_size'] = newRelSizes;
            }
          }
          if (updateData.containsKey('stock_updated_at')) {
            item['stockUpdatedAt'] = updateData['stock_updated_at'];
          }
        }
      }
      _saveDiskList('cached_inventory_$branchKey', items);
    });
    notifyListeners();
  }

  void invalidateInventory([String? branch]) {
    if (branch != null) {
      _inventoryCache.remove(branch);
      _inventoryTimestamps.remove(branch);
    } else {
      _inventoryCache.clear();
      _inventoryTimestamps.clear();
    }
    notifyListeners();
  }

  // ─── SALES ───────────────────────────────────────────────────────

  List<dynamic>? getCachedSales(String? branch) {
    final key = branch ?? 'default';
    return _salesCache[key];
  }

  Future<List<dynamic>> getSales({
    String? branch,
    bool forceRefresh = false,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  }) async {
    final key = branch ?? 'default';
    final cached = _salesCache[key];
    final lastFetch = _salesTimestamps[key];
    final isStale = lastFetch == null || DateTime.now().difference(lastFetch) > _cacheDuration;

    if (cached == null) {
      final diskData = await _readDiskList('cached_sales_$key');
      if (diskData != null && diskData.isNotEmpty) {
        _salesCache[key] = diskData;
      }
    }

    final availableCache = _salesCache[key];

    if (!forceRefresh && availableCache != null && availableCache.isNotEmpty) {
      if (isStale) {
        _refreshSales(branch, key, onBackgroundRefreshed);
      }
      return availableCache;
    }

    return await _refreshSales(branch, key, onBackgroundRefreshed);
  }

  Future<List<dynamic>> _refreshSales(
    String? branch,
    String key,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  ) async {
    try {
      final fresh = await _apiService.getSales(branch: branch);
      _salesCache[key] = fresh;
      _salesTimestamps[key] = DateTime.now();
      _saveDiskList('cached_sales_$key', fresh);
      notifyListeners();
      onBackgroundRefreshed?.call(fresh);
      return fresh;
    } catch (e) {
      if (_salesCache.containsKey(key)) return _salesCache[key]!;
      rethrow;
    }
  }

  void addLocalSale(Map<String, dynamic> saleRow, {String? branch}) {
    final key = branch ?? 'default';
    final list = _salesCache[key] ?? [];
    list.insert(0, saleRow);
    _salesCache[key] = list;
    _saveDiskList('cached_sales_$key', list);
    notifyListeners();
  }

  void invalidateSales([String? branch]) {
    if (branch != null) {
      _salesCache.remove(branch);
      _salesTimestamps.remove(branch);
    } else {
      _salesCache.clear();
      _salesTimestamps.clear();
    }
    notifyListeners();
  }

  // ─── CATEGORIES ──────────────────────────────────────────────────

  List<dynamic>? getCachedCategories() => _categoriesCache;

  Future<List<dynamic>> getCategories({
    bool forceRefresh = false,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  }) async {
    final isStale = _categoriesTimestamp == null ||
        DateTime.now().difference(_categoriesTimestamp!) > _cacheDuration;

    if (!forceRefresh && _categoriesCache != null && _categoriesCache!.isNotEmpty) {
      if (isStale) {
        _refreshCategories(onBackgroundRefreshed);
      }
      return _categoriesCache!;
    }

    return await _refreshCategories(onBackgroundRefreshed);
  }

  Future<List<dynamic>> _refreshCategories(
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  ) async {
    try {
      final fresh = await _apiService.getCategories();
      _categoriesCache = fresh;
      _categoriesTimestamp = DateTime.now();
      _saveDiskList('cached_categories', fresh);
      notifyListeners();
      onBackgroundRefreshed?.call(fresh);
      return fresh;
    } catch (e) {
      if (_categoriesCache != null) return _categoriesCache!;
      rethrow;
    }
  }

  void invalidateCategories() {
    _categoriesCache = null;
    _categoriesTimestamp = null;
    notifyListeners();
  }

  // ─── PURCHASES ───────────────────────────────────────────────────

  Future<List<dynamic>> getPurchases({
    String? branch,
    bool forceRefresh = false,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  }) async {
    final key = branch ?? 'default';
    final cached = _purchasesCache[key];
    final lastFetch = _purchasesTimestamps[key];
    final isStale = lastFetch == null || DateTime.now().difference(lastFetch) > _cacheDuration;

    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      if (isStale) {
        _refreshPurchases(branch, key, onBackgroundRefreshed);
      }
      return cached;
    }

    return await _refreshPurchases(branch, key, onBackgroundRefreshed);
  }

  Future<List<dynamic>> _refreshPurchases(
    String? branch,
    String key,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  ) async {
    try {
      final fresh = await _apiService.getPurchases(branch: branch);
      _purchasesCache[key] = fresh;
      _purchasesTimestamps[key] = DateTime.now();
      notifyListeners();
      onBackgroundRefreshed?.call(fresh);
      return fresh;
    } catch (e) {
      if (_purchasesCache.containsKey(key)) return _purchasesCache[key]!;
      rethrow;
    }
  }

  void invalidatePurchases([String? branch]) {
    if (branch != null) {
      _purchasesCache.remove(branch);
      _purchasesTimestamps.remove(branch);
    } else {
      _purchasesCache.clear();
      _purchasesTimestamps.clear();
    }
    notifyListeners();
  }

  // ─── SUPPLIERS ───────────────────────────────────────────────────

  Future<List<dynamic>> getSuppliers({
    bool forceRefresh = false,
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  }) async {
    final isStale = _suppliersTimestamp == null ||
        DateTime.now().difference(_suppliersTimestamp!) > _cacheDuration;

    if (!forceRefresh && _suppliersCache != null && _suppliersCache!.isNotEmpty) {
      if (isStale) {
        _refreshSuppliers(onBackgroundRefreshed);
      }
      return _suppliersCache!;
    }

    return await _refreshSuppliers(onBackgroundRefreshed);
  }

  Future<List<dynamic>> _refreshSuppliers(
    Function(List<dynamic> freshData)? onBackgroundRefreshed,
  ) async {
    try {
      final fresh = await _apiService.getSuppliers();
      _suppliersCache = fresh;
      _suppliersTimestamp = DateTime.now();
      _saveDiskList('cached_suppliers', fresh);
      notifyListeners();
      onBackgroundRefreshed?.call(fresh);
      return fresh;
    } catch (e) {
      if (_suppliersCache != null) return _suppliersCache!;
      rethrow;
    }
  }

  void invalidateSuppliers() {
    _suppliersCache = null;
    _suppliersTimestamp = null;
    notifyListeners();
  }

  void invalidateAll() {
    _inventoryCache.clear();
    _salesCache.clear();
    _purchasesCache.clear();
    _categoriesCache = null;
    _suppliersCache = null;
    _inventoryTimestamps.clear();
    _salesTimestamps.clear();
    _purchasesTimestamps.clear();
    _categoriesTimestamp = null;
    _suppliersTimestamp = null;
    notifyListeners();
  }

  /// Clears in-memory caches and removes cached persistent data from disk
  Future<void> clearAllDiskCaches() async {
    invalidateAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cached_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing disk caches: $e');
    }
  }

  /// Generates a JSON string representing backed up local data and store settings
  Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final backupData = <String, dynamic>{
      'export_timestamp': DateTime.now().toIso8601String(),
      'store_settings': {
        'store_name': prefs.getString('store_name') ?? 'Smart Store',
        'store_address': prefs.getString('store_address') ?? '',
        'store_phone': prefs.getString('store_phone') ?? '',
        'store_gstin': prefs.getString('store_gstin') ?? '',
        'receipt_tagline': prefs.getString('receipt_tagline') ?? '',
        'currency_symbol': prefs.getString('currency_symbol') ?? '₹',
        'currency_position': prefs.getString('currency_position') ?? 'before',
        'date_format': prefs.getString('date_format') ?? 'DD/MM/YYYY',
        'low_stock_threshold': prefs.getDouble('low_stock_threshold') ?? 10.0,
        'sgst_percent': prefs.getDouble('sgst_percent') ?? 0.0,
        'cgst_percent': prefs.getDouble('cgst_percent') ?? 0.0,
        'igst_percent': prefs.getDouble('igst_percent') ?? 0.0,
        'printer_paper_size': prefs.getString('printer_paper_size') ?? '58mm',
        'auto_print_receipt': prefs.getBool('auto_print_receipt') ?? false,
      },
      'inventory': _inventoryCache,
      'categories': _categoriesCache ?? [],
      'suppliers': _suppliersCache ?? [],
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  // Helper Methods for SharedPreferences Persistence
  Future<void> _saveDiskList(String key, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving disk list for $key: $e');
    }
  }

  Future<List<dynamic>?> _readDiskList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading disk list for $key: $e');
    }
    return null;
  }

  /// Fetches persistent store and tax settings
  Future<Map<String, dynamic>> getStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'store_name': prefs.getString('store_name') ?? 'Smart Store',
      'store_address': prefs.getString('store_address') ?? 'Main Road, Sample City',
      'store_phone': prefs.getString('store_phone') ?? '+91 9876543210',
      'store_gstin': prefs.getString('store_gstin') ?? '27AAAAA0000A1Z5',
      'receipt_tagline': prefs.getString('receipt_tagline') ?? 'Thank you for shopping with us!',
      'low_stock_threshold': prefs.getDouble('low_stock_threshold') ?? 10.0,
      'low_stock_alert_enabled': prefs.getBool('low_stock_alert_enabled') ?? true,
      'sgst_percent': prefs.getDouble('sgst_percent') ?? 0.0,
      'cgst_percent': prefs.getDouble('cgst_percent') ?? 0.0,
      'igst_percent': prefs.getDouble('igst_percent') ?? 0.0,
      'tax_inclusive': prefs.getBool('tax_inclusive') ?? false,
      'currency_symbol': prefs.getString('currency_symbol') ?? '₹',
      'currency_position': prefs.getString('currency_position') ?? 'before',
      'date_format': prefs.getString('date_format') ?? 'DD/MM/YYYY',
    };
  }

  /// Permanently saves tax and inventory rules settings to SharedPreferences and notifies UI listeners
  Future<void> saveTaxAndInventorySettings({
    required double sgst,
    required double cgst,
    required double igst,
    required double lowStockThreshold,
    required bool taxInclusive,
    required bool lowStockAlertEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sgst_percent', sgst);
    await prefs.setDouble('cgst_percent', cgst);
    await prefs.setDouble('igst_percent', igst);
    await prefs.setDouble('low_stock_threshold', lowStockThreshold);
    await prefs.setBool('tax_inclusive', taxInclusive);
    await prefs.setBool('low_stock_alert_enabled', lowStockAlertEnabled);
    notifySettingsChanged();
  }

  /// Notifies all listeners that global store settings or thresholds have been updated
  void notifySettingsChanged() {
    notifyListeners();
  }
}

