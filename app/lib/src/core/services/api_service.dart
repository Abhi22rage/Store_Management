import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../env/env.dart';
import 'data_repository.dart';
import 'package:smart_store/src/core/models/item_variant_model.dart';

class ApiService {
  static SupabaseClient get _db => Supabase.instance.client;

  // ─── Image URL helper ────────────────────────────────────────────
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${Env.storageUrl}$path';
  }

  // ─── UUID RESOLVERS & WARMUP ─────────────────────────────────────
  static final Map<String, String> _branchIdCache = {};
  static final Map<String, String> _categoryIdCache = {};
  static final Map<String, String> _supplierIdCache = {};

  Future<void> warmupCaches() async {
    try {
      final results = await Future.wait([
        _db.from('branches').select('id, name'),
        _db.from('categories').select('id, name'),
        _db.from('suppliers').select('id, name'),
      ]);
      for (var b in (results[0] as List)) {
        if (b['name'] != null && b['id'] != null) {
          _branchIdCache[b['name'].toString()] = b['id'].toString();
        }
      }
      for (var c in (results[1] as List)) {
        if (c['name'] != null && c['id'] != null) {
          _categoryIdCache[c['name'].toString()] = c['id'].toString();
        }
      }
      for (var s in (results[2] as List)) {
        if (s['name'] != null && s['id'] != null) {
          _supplierIdCache[s['name'].toString()] = s['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('ApiService warmup error: $e');
    }
  }

  Future<String?> _getBranchId(String? name) async {
    if (name == null || name.isEmpty) return null;
    if (_branchIdCache.containsKey(name)) {
      return _branchIdCache[name];
    }
    try {
      final res = await _db.from('branches').select('id').eq('name', name).maybeSingle();
      final id = res?['id']?.toString();
      if (id != null) {
        _branchIdCache[name] = id;
      }
      return id;
    } catch (_) { return null; }
  }

  Future<String?> _getCategoryId(String? name) async {
    if (name == null || name.isEmpty) return null;
    if (_categoryIdCache.containsKey(name)) {
      return _categoryIdCache[name];
    }
    try {
      final res = await _db.from('categories').select('id').eq('name', name).maybeSingle();
      final id = res?['id']?.toString();
      if (id != null) {
        _categoryIdCache[name] = id;
      }
      return id;
    } catch (_) { return null; }
  }

  Future<String?> getSupplierId(String? idOrName) async {
    if (idOrName == null || idOrName.isEmpty) return null;
    if (idOrName.contains('-')) return idOrName; // already a UUID
    if (_supplierIdCache.containsKey(idOrName)) {
      return _supplierIdCache[idOrName];
    }
    try {
      final res = await _db.from('suppliers').select('id').eq('name', idOrName).maybeSingle();
      final id = res?['id']?.toString();
      if (id != null) {
        _supplierIdCache[idOrName] = id;
      }
      return id;
    } catch (_) { return null; }
  }

  // ─── BRANCHES ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final rows = await _db
          .from('branches')
          .select('id, name, address, contact_phone, created_at')
          .order('created_at', ascending: true);
      
      final list = rows.map((r) => {
        'id': r['id'].toString(),
        'name': r['name'].toString(),
        'location': r['address']?.toString() ?? '',
        'contact_phone': r['contact_phone']?.toString() ?? '',
        'createdAt': r['created_at']?.toString() ?? '',
      }).toList();

      list.sort((a, b) {
        final aName = a['name'].toString();
        final bName = b['name'].toString();
        if (aName == 'Main Store') return -1;
        if (bName == 'Main Store') return 1;
        if (aName == 'Warehouse') return -1;
        if (bName == 'Warehouse') return 1;
        return 0;
      });

      return list;
    } catch (e) {
      debugPrint('SUPABASE DIAGNOSTIC - getBranches failed: $e');
      return [
        {'id': '1', 'name': 'Main Store'},
        {'id': '2', 'name': 'Warehouse'},
      ];
    }
  }

  Future<void> createBranch(String name, {String? location, String? contactPhone}) async {
    try {
      try {
        await _db.from('branches').insert({
          'name': name,
          'address': location,
          'contact_phone': contactPhone,
        });
      } catch (e) {
        // Fallback for schemas using 'location' column instead of 'address'
        if (e.toString().contains('address')) {
          await _db.from('branches').insert({
            'name': name,
            'location': location,
          });
        } else {
          rethrow;
        }
      }
    } catch (e) {
      throw Exception('Failed to create branch: $e');
    }
  }

  Future<void> updateBranch(String id, String newName, {String? location, String? contactPhone}) async {
    try {
      await _db.from('branches').update({
        'name': newName,
        'address': location,
        'contact_phone': contactPhone,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Failed to update branch: $e');
    }
  }

  Future<void> deleteBranch(String id) async {
    try {
      await _db.from('branches').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete branch: $e');
    }
  }

  // ─── ITEMS (INVENTORY) ───────────────────────────────────────────

  Future<List<dynamic>> getInventory({String? branch}) async {
    try {
      String? branchId;
      if (branch != null && branch.isNotEmpty) {
        branchId = await _getBranchId(branch);
      }

      List<dynamic> rows;
      try {
        var query = _db.from('items').select('*, categories(name), branches(name), items_size(*)');
        if (branchId != null) {
          if (branch == 'Main Store') {
            query = query.or('branch_id.eq.$branchId,branch_id.is.null');
          } else {
            query = query.eq('branch_id', branchId);
          }
        }
        rows = await query.order('created_at', ascending: false);
      } catch (joinErr) {
        debugPrint('[ApiService] getInventory relational join query failed ($joinErr), trying fallback select...');
        try {
          var query = _db.from('items').select('*, categories(name), branches(name)');
          if (branchId != null) {
            if (branch == 'Main Store') {
              query = query.or('branch_id.eq.$branchId,branch_id.is.null');
            } else {
              query = query.eq('branch_id', branchId);
            }
          }
          rows = await query.order('created_at', ascending: false);
        } catch (_) {
          var fallbackQuery = _db.from('items').select('*');
          rows = await fallbackQuery.order('created_at', ascending: false);
        }
      }

      return rows.map((r) => _normalizeItemRow(r)).toList();
    } catch (e) {
      debugPrint('[ApiService] getInventory error: $e');
      return [];
    }
  }

  Future<dynamic> createInventoryItem(
    Map<String, dynamic> item, {
    XFile? imageFile,
    String? branch,
  }) async {
    try {
      String imageUrl = '';
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile);
      }

      final branchId = await _getBranchId(branch ?? 'Main Store');
      final categoryId = await _getCategoryId(item['category'] ?? item['primeCategory']);

      final payload = <String, dynamic>{
        'item_name': item['name'] ?? item['item_name'] ?? '',
        'category_id': ?categoryId,
        'category_name': item['category'] ?? item['primeCategory'] ?? '',
        'branch_id': ?branchId,
        if (item['supplierId'] != null) 'supplier_id': item['supplierId'],
        if (item['supplierName'] != null || item['supplier'] != null)
          'supplier_name': item['supplierName'] ?? item['supplier'],
        'purchase_date': item['purchaseDate'] ?? DateTime.now().toIso8601String(),
        'stock_updated_at': DateTime.now().toIso8601String(),
        'color': item['color'] ?? '',
        if (imageUrl.isNotEmpty) 'image_url': imageUrl,
        'has_variants': item['hasVariants'] ?? false,
        'variants_count': (item['variants'] is List && (item['variants'] as List).isNotEmpty)
            ? (item['variants'] as List).length
            : 1,
      };

      Map<String, dynamic> row;
      while (true) {
        try {
          row = await _db
              .from('items')
              .insert(payload)
              .select('*, categories(name), branches(name)')
              .single();
          break;
        } catch (err) {
          final errStr = err.toString();
          if (errStr.contains('PGRST204') || errStr.contains('Could not find')) {
            final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(errStr);
            if (match != null) {
              final missingCol = match.group(1)!;
              if (payload.containsKey(missingCol)) {
                debugPrint('[ApiService] Pruning missing column "$missingCol" from items payload');
                payload.remove(missingCol);
                continue;
              }
            }
          }
          rethrow;
        }
      }

      DataRepository().invalidateInventory();

      final itemId = row['id'].toString();
      List<dynamic> variantsToSync;
      if (item['variants'] is List && (item['variants'] as List).isNotEmpty) {
        variantsToSync = item['variants'] as List;
      } else {
        variantsToSync = [
          {
            'id': itemId,
            'color': item['color'] ?? 'Default',
            'sizes': [
              {
                'size': item['size']?.toString() ?? '',
                'stock': int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
                'cost_price': double.tryParse((item['costPrice'] ?? item['cost_price'] ?? item['price'] ?? '0').toString()) ?? 0.0,
                'retail_price': double.tryParse((item['retailPrice'] ?? item['retail_price'] ?? '0').toString()) ?? 0.0,
                'barcode': item['barcode']?.toString() ?? '',
              }
            ]
          }
        ];
      }

      await _syncRelationalVariants(itemId, variantsToSync, itemName: item['name'] ?? item['item_name']);

      final normalized = _normalizeItemRow(row);
      final inputBarcode = item['barcode']?.toString() ?? '';
      if ((normalized['barcode'] as String).isEmpty && inputBarcode.isNotEmpty) {
        normalized['barcode'] = inputBarcode;
      }
      return normalized;
    } catch (e) {
      throw Exception('Failed to create item: $e');
    }
  }

  Future<void> bulkCreateInventoryItems(List<Map<String, dynamic>> items) async {
    try {
      if (items.isEmpty) return;

      final dataToInsert = <Map<String, dynamic>>[];
      for (var item in items) {
        final branchId = await _getBranchId(item['branch'] ?? 'Main Store');
        final categoryId = await _getCategoryId(item['category'] ?? item['primeCategory']);
        
        dataToInsert.add({
          'name': item['name'] ?? '',
          'category_id': ?categoryId,
          'branch_id': ?branchId,
          'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
          'retail_price': double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0,
          'stock': int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
          'image_url': item['image_url'] ?? '',
          'color': item['color'] ?? '',
          'size': item['size']?.toString() ?? '',
          'barcode': item['barcode']?.toString() ?? '',
        });
      }

      await _db.from('items').insert(dataToInsert);
      DataRepository().invalidateInventory();
    } catch (e) {
      throw Exception('Failed to bulk create items: $e');
    }
  }

  Future<dynamic> updateInventoryItem(
    String id,
    Map<String, dynamic> item, {
    XFile? imageFile,
  }) async {
    try {
      String? newImageUrl;
      if (imageFile != null) {
        newImageUrl = await _uploadImage(imageFile);
      }

      final branchId = item.containsKey('branch') ? await _getBranchId(item['branch']) : null;
      final categoryId = await _getCategoryId(item['category'] ?? item['primeCategory']);

      final updateData = <String, dynamic>{
        'item_name': item['name'] ?? item['item_name'] ?? '',
        'category_id': ?categoryId,
        if (item['category'] != null || item['primeCategory'] != null)
          'category_name': item['category'] ?? item['primeCategory'],
        if (item['supplierId'] != null) 'supplier_id': item['supplierId'],
        if (item['supplierName'] != null || item['supplier'] != null)
          'supplier_name': item['supplierName'] ?? item['supplier'],
        'stock_updated_at': DateTime.now().toIso8601String(),
        'color': item['color'] ?? '',
        if (newImageUrl != null && newImageUrl.isNotEmpty) 'image_url': newImageUrl,
        'branch_id': ?branchId,
        'has_variants': item['hasVariants'] ?? false,
        'variants_count': (item['variants'] is List && (item['variants'] as List).isNotEmpty)
            ? (item['variants'] as List).length
            : 1,
      };

      Map<String, dynamic> row;
      while (true) {
        try {
          row = await _db
              .from('items')
              .update(updateData)
              .eq('id', id)
              .select('*, categories(name), branches(name)')
              .single();
          break;
        } catch (err) {
          final errStr = err.toString();
          if (errStr.contains('PGRST204') || errStr.contains('Could not find')) {
            final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(errStr);
            if (match != null) {
              final missingCol = match.group(1)!;
              if (updateData.containsKey(missingCol)) {
                debugPrint('[ApiService] Pruning missing column "$missingCol" from items updateData');
                updateData.remove(missingCol);
                continue;
              }
            }
          }
          rethrow;
        }
      }

      DataRepository().invalidateInventory();

      List<dynamic> variantsToSync;
      if (item['variants'] is List && (item['variants'] as List).isNotEmpty) {
        variantsToSync = item['variants'] as List;
      } else {
        variantsToSync = [
          {
            'id': id,
            'color': item['color'] ?? 'Default',
            'sizes': [
              {
                'size': item['size']?.toString() ?? '',
                'stock': int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
                'cost_price': double.tryParse((item['costPrice'] ?? item['cost_price'] ?? item['price'] ?? '0').toString()) ?? 0.0,
                'retail_price': double.tryParse((item['retailPrice'] ?? item['retail_price'] ?? '0').toString()) ?? 0.0,
                'barcode': item['barcode']?.toString() ?? '',
              }
            ]
          }
        ];
      }

      await _syncRelationalVariants(id, variantsToSync, itemName: item['name'] ?? item['item_name']);

      final normalized = _normalizeItemRow(row);
      final inputBarcode = item['barcode']?.toString() ?? '';
      if ((normalized['barcode'] as String).isEmpty && inputBarcode.isNotEmpty) {
        normalized['barcode'] = inputBarcode;
      }
      return normalized;
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  Future<void> bulkUpdateInventoryItems(List<String> ids, Map<String, dynamic> data) async {
    try {
      if (ids.isEmpty) return;
      final mappedData = <String, dynamic>{};
      
      if (data.containsKey('primeCategory')) {
        final catId = await _getCategoryId(data['primeCategory']);
        if (catId != null) mappedData['category_id'] = catId;
      }
      if (data.containsKey('price')) mappedData['price'] = double.tryParse(data['price'].toString()) ?? 0;
      if (data.containsKey('retailPrice')) mappedData['retail_price'] = double.tryParse(data['retailPrice'].toString()) ?? 0;
      if (data.containsKey('stock')) mappedData['stock'] = int.tryParse(data['stock'].toString()) ?? 0;
      if (data.containsKey('color')) mappedData['color'] = data['color'];
      if (data.containsKey('size')) mappedData['size'] = data['size'];

      if (mappedData.isNotEmpty) {
        await _db.from('items').update(mappedData).inFilter('id', ids);
        DataRepository().invalidateInventory();
      }
    } catch (e) {
      throw Exception('Failed to bulk update items: $e');
    }
  }

  Future<void> bulkDeleteInventoryItems(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      
      final rows = await _db.from('items').select('image_url').inFilter('id', ids);
      final paths = rows
          .where((r) => r['image_url'] != null && r['image_url'] != '')
          .map((r) => _extractStoragePath(r['image_url']))
          .where((p) => p.isNotEmpty)
          .toList();
      
      if (paths.isNotEmpty) await _db.storage.from('product-images').remove(paths);
      await _db.from('items').delete().inFilter('id', ids);
      DataRepository().invalidateInventory();
    } catch (e) {
      throw Exception('Failed to bulk delete items: $e');
    }
  }

  Future<void> deleteInventoryItem(String id) async {
    try {
      final row = await _db.from('items').select('image_url').eq('id', id).maybeSingle();
      if (row != null && row['image_url'] != null && row['image_url'] != '') {
        final path = _extractStoragePath(row['image_url']);
        if (path.isNotEmpty) await _db.storage.from('product-images').remove([path]);
      }
      await _db.from('items').delete().eq('id', id);
      DataRepository().invalidateInventory();
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  bool _isValidUuid(String? s) {
    if (s == null || s.isEmpty) return false;
    final uuidRegExp = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegExp.hasMatch(s);
  }

  // ─── SALES ───────────────────────────────────────────────────────

  Future<List<dynamic>> getSales({String? branch}) async {
    try {
      String? branchId;
      if (branch != null && branch.isNotEmpty) {
        branchId = await _getBranchId(branch);
      }

      List<dynamic> rows;
      try {
        var query = _db.from('sales').select('*, branches(name), sale_items(*, items(*, categories(name)))');
        if (branchId != null) {
          if (branch == 'Main Store') {
            query = query.or('branch_id.eq.$branchId,branch_id.is.null');
          } else {
            query = query.eq('branch_id', branchId);
          }
        }
        rows = await query.order('created_at', ascending: false);
      } catch (joinErr) {
        debugPrint('[ApiService] getSales join query failed ($joinErr), trying fallback select...');
        try {
          var fallbackQuery = _db.from('sales').select('*, sale_items(*)');
          if (branchId != null) {
            if (branch == 'Main Store') {
              fallbackQuery = fallbackQuery.or('branch_id.eq.$branchId,branch_id.is.null');
            } else {
              fallbackQuery = fallbackQuery.eq('branch_id', branchId);
            }
          }
          rows = await fallbackQuery.order('created_at', ascending: false);
        } catch (_) {
          var unFilteredQuery = _db.from('sales').select('*, sale_items(*)');
          rows = await unFilteredQuery.order('created_at', ascending: false);
        }
      }

      return rows.map((r) => _normalizeSaleRow(r)).toList();
    } catch (e) {
      debugPrint('[ApiService] getSales error: $e');
      return [];
    }
  }

  Future<dynamic> createSale(Map<String, dynamic> sale, {String? branch}) async {
    try {
      String? branchId = await _getBranchId(branch ?? 'Main Store');
      if (branchId == null || !_isValidUuid(branchId)) {
        final branches = await getBranches();
        if (branches.isNotEmpty) {
          branchId = branches.first['id']?.toString();
        }
      }

      final currentUser = _db.auth.currentUser;
      final String? userId = currentUser?.id;
      final String? email = currentUser?.email;
      final String userName = (currentUser?.userMetadata?['full_name'] as String?) ??
          (email != null && email.contains('@')
              ? email.split('@').first
              : 'Store Admin');

      final String invNo = (sale['invoiceNumber'] ?? sale['invoice_number'] ?? '').toString();
      final String invoiceNumber = invNo.isNotEmpty
          ? invNo
          : 'DIG-${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}-${DateTime.now().millisecondsSinceEpoch % 10000}';

      final rawItemId = sale['itemId']?.toString() ?? sale['id']?.toString() ?? '';
      String realItemId = rawItemId;
      if (rawItemId.contains('_')) {
        realItemId = rawItemId.split('_').first;
      }
      final validItemId = _isValidUuid(realItemId) ? realItemId : null;
      final qty = int.tryParse(sale['quantity'].toString()) ?? 1;
      final total = double.tryParse(sale['totalAmount'].toString()) ?? 0;

      dynamic response;
      try {
        response = await _db.rpc('create_sale_with_items', params: {
          'p_branch_id': branchId,
          'p_user_id': userId,
          'p_invoice_number': invoiceNumber,
          'p_user_name': userName,
          'p_customer_name': sale['customerName'] ?? 'Walk-in Customer',
          'p_customer_phone': sale['customerPhone'] ?? '',
          'p_total_amount': total,
          'p_discount': 0,
          'p_final_amount': total,
          'p_payment_method': sale['paymentMethod'] ?? 'Cash',
          'p_items': [
            {
              'item_id': validItemId,
              'name': sale['name'] ?? 'Sale Item',
              'item_name': sale['name'] ?? 'Sale Item',
              'quantity': qty,
              'unit_price': (qty > 0) ? total / qty : 0,
              'subtotal': total,
              'final_amount': total,
            }
          ]
        });
      } catch (rpcErr) {
        debugPrint('[ApiService] RPC createSale failed ($rpcErr), executing direct fallback insert...');
        final payloadToInsert = <String, dynamic>{
          'branch_id': branchId,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          'invoice_number': invoiceNumber,
          'user_name': userName,
          'customer_name': sale['customerName'] ?? 'Walk-in Customer',
          'customer_phone': sale['customerPhone'] ?? '',
          'total_amount': total,
          'discount': 0,
          'final_amount': total,
          'payment_method': sale['paymentMethod'] ?? 'Cash',
          if (sale['date'] != null) 'sale_date': sale['date'],
        };
        try {
          final saleInsert = await _db.from('sales').insert(payloadToInsert).select('id').single();
          response = saleInsert['id'];
        } catch (dbErr) {
          final errStr = dbErr.toString();
          if (errStr.contains('invoice_number') || errStr.contains('user_name') || errStr.contains('PGRST204')) {
            payloadToInsert.remove('invoice_number');
            payloadToInsert.remove('user_name');
            try {
              final saleInsert = await _db.from('sales').insert(payloadToInsert).select('id').single();
              response = saleInsert['id'];
            } catch (_) {}
          }
        }

        if (response != null && validItemId != null) {
          try {
            final saleItemPayload = <String, dynamic>{
              'sale_id': response,
              'invoice_number': invoiceNumber,
              'item_id': validItemId,
              'item_name': sale['name'] ?? 'Sale Item',
              'quantity': qty,
              'unit_price': (qty > 0) ? total / qty : 0,
              'subtotal': total,
              'final_amount': total,
            };
            try {
              await _db.from('sale_items').insert(saleItemPayload);
            } catch (siErr) {
              final errStr = siErr.toString();
              if (errStr.contains('invoice_number') || errStr.contains('item_name') || errStr.contains('final_amount')) {
                saleItemPayload.remove('invoice_number');
                saleItemPayload.remove('item_name');
                saleItemPayload.remove('final_amount');
                await _db.from('sale_items').insert(saleItemPayload);
              }
            }
          } catch (itemErr) {
            debugPrint('[ApiService] Insert sale_item failed: $itemErr');
          }
        }
      }

      final saleId = response?.toString() ?? 'S-${DateTime.now().millisecondsSinceEpoch}';
      final newSaleRow = {
        'id': saleId,
        'invoiceNumber': invoiceNumber,
        'invoice_number': invoiceNumber,
        'userId': userId,
        'user_id': userId,
        'userName': userName,
        'user_name': userName,
        'date': sale['date'] ?? DateTime.now().toIso8601String(),
        'createdAt': sale['date'] ?? DateTime.now().toIso8601String(),
        'customerName': (sale['customerName'] != null && sale['customerName'].toString().trim().isNotEmpty)
            ? sale['customerName'].toString()
            : 'Walk-in Customer',
        'customerPhone': sale['customerPhone'] ?? '',
        'items': [
          {
            'name': sale['name'] ?? 'Sale Item',
            'quantity': qty,
            'price': (qty > 0) ? total / qty : 0,
            'totalPrice': total,
          }
        ],
        'subTotal': total,
        'discount': 0,
        'grandTotal': total,
        'totalAmount': total,
        'paymentMethod': sale['paymentMethod'] ?? 'Cash',
        'branch': branch ?? 'Main Store',
      };

      await deductStockForSale([
        {
          'itemId': rawItemId,
          'id': rawItemId,
          'quantity': qty,
          'color': sale['color'],
          'size': sale['size'],
        }
      ]);

      DataRepository().addLocalSale(newSaleRow, branch: branch ?? 'Main Store');
      DataRepository().invalidateInventory();

      return newSaleRow;
    } catch (e) {
      debugPrint('[ApiService] createSale error: $e');
      throw Exception('Failed to create sale: $e');
    }
  }

  Future<dynamic> createInvoiceSale(Map<String, dynamic> invoice, {String? branch}) async {
    try {
      String? branchId = await _getBranchId(branch ?? 'Main Store');
      if (branchId == null || !_isValidUuid(branchId)) {
        final branches = await getBranches();
        if (branches.isNotEmpty) {
          branchId = branches.first['id']?.toString();
        }
      }

      final currentUser = _db.auth.currentUser;
      final String? userId = currentUser?.id;
      final String? email = currentUser?.email;
      final String userName = (currentUser?.userMetadata?['full_name'] as String?) ??
          (email != null && email.contains('@')
              ? email.split('@').first
              : 'Store Admin');

      final String invNo = (invoice['invoiceNumber'] ?? invoice['invoice_number'] ?? '').toString();
      final String invoiceNumber = invNo.isNotEmpty
          ? invNo
          : 'INV-${DateTime.now().millisecondsSinceEpoch % 100000}';

      final items = invoice['items'] as List? ?? [];
      
      final grandTotal = double.tryParse(invoice['grandTotal'].toString()) ?? 0;
      final itemsForRpc = items.map((item) {
        final qty = int.tryParse(item['quantity'].toString()) ?? 1;
        final unitPrice = double.tryParse((item['pricePerPiece'] ?? item['price'] ?? '0').toString()) ?? 0.0;
        final subtotal = double.tryParse((item['totalPrice'] ?? item['totalAmount'] ?? '0').toString()) ?? (unitPrice * qty);
        final rawId = (item['itemId'] ?? item['id'] ?? '').toString();
        String realId = rawId;
        if (rawId.contains('_')) {
          realId = rawId.split('_').first;
        }
        final validId = _isValidUuid(realId) ? realId : null;
        final itemName = item['name']?.toString() ?? 'Sale Item';
        return {
          'item_id': validId,
          'name': itemName,
          'item_name': itemName,
          'quantity': qty,
          'unit_price': unitPrice,
          'subtotal': subtotal,
          'final_amount': grandTotal > 0 ? grandTotal : subtotal,
        };
      }).toList();

      dynamic response;
      try {
        response = await _db.rpc('create_sale_with_items', params: {
          'p_branch_id': branchId,
          'p_user_id': userId,
          'p_invoice_number': invoiceNumber,
          'p_user_name': userName,
          'p_customer_name': invoice['customerName'] ?? 'Walk-in Customer',
          'p_customer_phone': invoice['customerPhone'] ?? '',
          'p_total_amount': double.tryParse(invoice['subTotal'].toString()) ?? 0,
          'p_discount': double.tryParse(invoice['discount'].toString()) ?? 0,
          'p_final_amount': grandTotal,
          'p_payment_method': invoice['paymentMethod'] ?? 'Cash',
          'p_items': itemsForRpc,
        });
      } catch (rpcErr) {
        debugPrint('[ApiService] RPC createInvoiceSale failed ($rpcErr), executing direct fallback insert...');
        final payloadToInsert = <String, dynamic>{
          'branch_id': branchId,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          'invoice_number': invoiceNumber,
          'user_name': userName,
          'customer_name': invoice['customerName'] ?? 'Walk-in Customer',
          'customer_phone': invoice['customerPhone'] ?? '',
          'total_amount': double.tryParse(invoice['subTotal'].toString()) ?? 0,
          'discount': double.tryParse(invoice['discount'].toString()) ?? 0,
          'final_amount': grandTotal,
          'payment_method': invoice['paymentMethod'] ?? 'Cash',
          if (invoice['date'] != null) 'sale_date': invoice['date'],
        };
        try {
          final saleInsert = await _db.from('sales').insert(payloadToInsert).select('id').single();
          response = saleInsert['id'];
        } catch (dbErr) {
          final errStr = dbErr.toString();
          if (errStr.contains('invoice_number') || errStr.contains('user_name') || errStr.contains('PGRST204')) {
            payloadToInsert.remove('invoice_number');
            payloadToInsert.remove('user_name');
            try {
              final saleInsert = await _db.from('sales').insert(payloadToInsert).select('id').single();
              response = saleInsert['id'];
            } catch (_) {}
          }
        }

        if (response != null) {
          for (var item in itemsForRpc) {
            try {
              final saleItemPayload = <String, dynamic>{
                'sale_id': response,
                'invoice_number': invoiceNumber,
                if (item['item_id'] != null) 'item_id': item['item_id'],
                'item_name': item['name'],
                'quantity': item['quantity'],
                'unit_price': item['unit_price'],
                'subtotal': item['subtotal'],
                'final_amount': grandTotal,
              };
              try {
                await _db.from('sale_items').insert(saleItemPayload);
              } catch (siErr) {
                final errStr = siErr.toString();
                if (errStr.contains('invoice_number') || errStr.contains('item_name') || errStr.contains('final_amount')) {
                  saleItemPayload.remove('invoice_number');
                  saleItemPayload.remove('item_name');
                  saleItemPayload.remove('final_amount');
                  if (item['item_id'] != null) {
                    await _db.from('sale_items').insert(saleItemPayload);
                  }
                }
              }
            } catch (itemErr) {
              debugPrint('[ApiService] Insert sale_item failed: $itemErr');
            }
          }
        }
      }

      final saleId = response?.toString() ?? 'S-${DateTime.now().millisecondsSinceEpoch}';
      final newSaleRow = {
        'id': saleId,
        'invoiceNumber': invoiceNumber,
        'invoice_number': invoiceNumber,
        'userId': userId,
        'user_id': userId,
        'userName': userName,
        'user_name': userName,
        'date': invoice['date'] ?? DateTime.now().toIso8601String(),
        'createdAt': invoice['date'] ?? DateTime.now().toIso8601String(),
        'customerName': (invoice['customerName'] != null && invoice['customerName'].toString().trim().isNotEmpty)
            ? invoice['customerName'].toString()
            : 'Walk-in Customer',
        'customerPhone': invoice['customerPhone'] ?? '',
        'items': items,
        'subTotal': double.tryParse(invoice['subTotal'].toString()) ?? 0,
        'discount': double.tryParse(invoice['discount'].toString()) ?? 0,
        'grandTotal': double.tryParse(invoice['grandTotal'].toString()) ?? 0,
        'totalAmount': double.tryParse(invoice['grandTotal'].toString()) ?? 0,
        'paymentMethod': invoice['paymentMethod'] ?? 'Cash',
        'branch': branch ?? 'Main Store',
      };

      await deductStockForSale(items);
      DataRepository().addLocalSale(newSaleRow, branch: branch ?? 'Main Store');
      DataRepository().invalidateInventory();

      return newSaleRow;
    } catch (e) {
      debugPrint('[ApiService] createInvoiceSale error: $e');
      throw Exception('Failed to create sale: $e');
    }
  }

  Future<void> deductStockForSale(List<dynamic> items) async {
    for (var saleItem in items) {
      try {
        final rawId = (saleItem['itemId'] ?? saleItem['id'] ?? '').toString();
        if (rawId.isEmpty) continue;

        String realItemId = rawId;
        if (rawId.contains('_')) {
          realItemId = rawId.split('_').first;
        }

        if (!_isValidUuid(realItemId)) continue;

        final qty = int.tryParse(saleItem['quantity'].toString()) ?? 1;
        final String soldColor = saleItem['color']?.toString().trim() ?? '';
        final String soldSize = saleItem['size']?.toString().trim() ?? '';

        final row = await _db.from('items').select().eq('id', realItemId).maybeSingle();
        if (row == null) continue;

        int currentStock = int.tryParse(row['stock']?.toString() ?? '0') ?? 0;
        int newStock = (currentStock - qty).clamp(0, 999999);

        final updateData = <String, dynamic>{
          'stock': newStock,
        };

        final bool hasVariants = row['has_variants'] == true || (row['variants'] != null && (row['variants'] as List).isNotEmpty);
        if (hasVariants && row['variants'] != null) {
          try {
            final rawVars = row['variants'] as List;
            final List<ItemVariant> variants = rawVars
                .map((v) => ItemVariant.fromJson(Map<String, dynamic>.from(v as Map)))
                .toList();

            bool sizeDeducted = false;

            // 1st Pass: Try matching color and size (case-insensitive & trimmed)
            for (var variantObj in variants) {
              final bool colorMatches = soldColor.isEmpty ||
                  variantObj.color.trim().toLowerCase() == soldColor.toLowerCase() ||
                  variantObj.color.trim().toLowerCase() == 'default';
              if (colorMatches) {
                for (var sz in variantObj.sizes) {
                  final bool sizeMatches = soldSize.isEmpty ||
                      sz.size.trim().toLowerCase() == soldSize.toLowerCase();
                  if (sizeMatches) {
                    sz.stock = (sz.stock - qty).clamp(0, 999999);
                    sizeDeducted = true;
                  }
                }
              }
            }

            // 2nd Pass (Fallback): If color match didn't deduct size, match size across all variants
            if (!sizeDeducted && soldSize.isNotEmpty) {
              for (var variantObj in variants) {
                for (var sz in variantObj.sizes) {
                  if (sz.size.trim().toLowerCase() == soldSize.toLowerCase()) {
                    sz.stock = (sz.stock - qty).clamp(0, 999999);
                    sizeDeducted = true;
                  }
                }
              }
            }

            // 3rd Pass (Fallback): If no size was matched, deduct from the first variant size with stock > 0
            if (!sizeDeducted && variants.isNotEmpty) {
              for (var variantObj in variants) {
                for (var sz in variantObj.sizes) {
                  if (sz.stock > 0) {
                    sz.stock = (sz.stock - qty).clamp(0, 999999);
                    sizeDeducted = true;
                    break;
                  }
                }
                if (sizeDeducted) break;
              }
            }

            // Recalculate total matrix stock from variants
            int totalMatrixStock = 0;
            for (var v in variants) {
              totalMatrixStock += v.totalStock;
            }
            updateData['stock'] = totalMatrixStock;
            updateData['variants'] = variants.map((v) => v.toJson()).toList();
          } catch (varErr) {
            debugPrint('[ApiService] Error updating variant matrix stock: $varErr');
          }
        }

        updateData['stock_updated_at'] = DateTime.now().toIso8601String();

        try {
          await _db.from('items').update(updateData).eq('id', realItemId);
        } catch (upErr) {
          if (upErr.toString().contains('variants') || upErr.toString().contains('PGRST204')) {
            updateData.remove('variants');
            await _db.from('items').update(updateData).eq('id', realItemId);
          }
        }

        if (updateData['variants'] != null && updateData['variants'] is List) {
          await _syncRelationalVariants(
            realItemId,
            updateData['variants'] as List<dynamic>,
            itemName: (row['name'] ?? row['item_name'])?.toString(),
          );
        }

        // Update local DataRepository cache immediately
        DataRepository().updateLocalItemStock(realItemId, updateData);
      } catch (e) {
        debugPrint('[ApiService] Error deducting stock for item ($saleItem): $e');
      }
    }
  }

  // ─── SUPPLIERS ───────────────────────────────────────────────────

  Future<List<dynamic>> getSuppliers({String? branch}) async {
    try {
      // Branch relation can be tricky if it's many-to-many, but we don't have branch_id on supplier table in SQL
      // Wait, initial_schema didn't put branch_id in suppliers. 
      final rows = await _db.from('suppliers').select().order('name', ascending: true);
      return rows.map((r) => _normalizeSupplierRow(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch suppliers: $e');
    }
  }

  Future<dynamic> createSupplier(Map<String, dynamic> supplier, {String? branch}) async {
    try {
      final row = await _db.from('suppliers').insert({
        'name': supplier['name'],
        'phone': supplier['phone'],
        'email': supplier['email'],
        'gstin': supplier['gstin'],
        'address': supplier['address'],
      }).select().single();
      return _normalizeSupplierRow(row);
    } catch (e) {
      throw Exception('Failed to create supplier: $e');
    }
  }

  // ─── PURCHASES ───────────────────────────────────────────────────

  Future<List<dynamic>> getPurchases({String? branch}) async {
    try {
      var query = _db.from('purchases').select('*, suppliers(name), branches(name), purchase_items(*)');
      
      if (branch != null && branch.isNotEmpty) {
        final branchId = await _getBranchId(branch);
        if (branchId != null) query = query.eq('branch_id', branchId);
      }
      
      final rows = await query.order('created_at', ascending: false);
      return rows.map((r) => _normalizePurchaseRow(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch purchases: $e');
    }
  }

  Future<dynamic> createPurchase(Map<String, dynamic> purchase, {String? branch, XFile? billFile}) async {
    try {
      String billUrl = '';
      if (billFile != null) {
        billUrl = await _uploadBill(billFile);
      }

      final branchId = await _getBranchId(branch ?? 'Main Store');
      final items = purchase['items'] as List? ?? [];
      
      final itemsForRpc = items.map((item) {
        final qty = int.tryParse(item['quantity'].toString()) ?? 0;
        final subtotal = double.tryParse(item['totalAmount']?.toString() ?? '0') ?? 0;
        return {
          'item_id': item['itemId'],
          'quantity': qty,
          'unit_price': (qty > 0) ? subtotal / qty : 0,
          'subtotal': subtotal,
        };
      }).toList();

      final response = await _db.rpc('create_purchase_with_items', params: {
        'p_branch_id': branchId,
        'p_supplier_id': purchase['supplierId'],
        'p_user_id': null,
        'p_invoice_no': purchase['purchaseNumber'] ?? 'PO-${DateTime.now().millisecondsSinceEpoch}',
        'p_total_amount': double.tryParse(purchase['grandTotal'].toString()) ?? 0,
        'p_payment_mode': purchase['paymentMethod'] ?? 'Cash',
        'p_payment_details': purchase['paymentDetails'] ?? '',
        'p_status': purchase['status'] ?? 'Received',
        'p_purchase_date': purchase['date'] ?? DateTime.now().toIso8601String(),
        'p_bill_media_url': billUrl,
        'p_items': itemsForRpc,
      });

      return {
        'id': response,
        'purchaseNumber': purchase['purchaseNumber'],
        'grandTotal': purchase['grandTotal'],
        'createdAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to create purchase: $e');
    }
  }

  Future<void> uploadManualStock(
    List<Map<String, dynamic>> items, {
    String? branch,
    String? note,
  }) async {
    try {
      // Manual stock upload increments stock directly. We can reuse our RPC or do direct update.
      await Future.wait(items.map((item) async {
        final itemId = item['itemId']?.toString() ?? '';
        final qty = int.tryParse(item['quantity'].toString()) ?? 0;
        if (itemId.isEmpty || qty <= 0) return;

        // Fetch current and increment
        final row = await _db.from('items').select('stock').eq('id', itemId).maybeSingle();
        if (row != null) {
          final newStock = (row['stock'] as num).toInt() + qty;
          final updates = <String, dynamic>{
            'stock': newStock,
            'stock_updated_at': DateTime.now().toIso8601String(),
          };
          
          final costPrice = item['costPrice'];
          if (costPrice != null) {
            final price = double.tryParse(costPrice.toString());
            if (price != null && price > 0) updates['price'] = price;
          }
          await _db.from('items').update(updates).eq('id', itemId);
        }
      }));
      DataRepository().invalidateInventory();
    } catch (e) {
      throw Exception('Failed to upload manual stock: $e');
    }
  }


  Future<List<dynamic>> getCategories() async {
    try {
      final rows = await _db.from('categories').select().order('created_at', ascending: true);
      // Flat list to hierarchical for UI
      final parentCats = rows.where((r) => r['parent_id'] == null).toList();
      return parentCats.map((p) {
        final level2Rows = rows.where((r) => r['parent_id'] == p['id']).toList();
        final subcategories = level2Rows.map((s) {
          final level3Names = rows
              .where((r) => r['parent_id'] == s['id'])
              .map((t) => t['name']?.toString() ?? '')
              .toList();
          return {
            'id': s['id'],
            'name': s['name'],
            'subcategories': level3Names,
          };
        }).toList();

        return {
          'id': p['id'],
          'name': p['name'],
          'subcategories': subcategories,
        };
      }).toList();
    } catch (e) {
      throw Exception('Connection refused');
    }
  }

  Future<dynamic> createCategory(Map<String, dynamic> cat) async {
    try {
      final row = await _db.from('categories').insert({
        'name': cat['name'] ?? '',
      }).select().single();
      
      // If there are subcategories (array of strings), create them linked to parent
      final subs = cat['subcategories'] as List? ?? [];
      for (var sub in subs) {
        if (sub is String && sub.isNotEmpty) {
          await _db.from('categories').insert({'name': sub, 'parent_id': row['id']});
        }
      }
      return {
        'id': row['id'],
        'name': row['name'],
        'subcategories': subs,
      };
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<dynamic> updateCategory(String id, Map<String, dynamic> cat) async {
    try {
      // 1. Update the parent name
      final parentRow = await _db.from('categories').update({'name': cat['name']}).eq('id', id).select().single();
      
      // 2. Fetch existing subcategories in the database for this parent
      final existingSubs = await _db.from('categories').select().eq('parent_id', id);
      
      final List<dynamic> updatedSubs = cat['subcategories'] ?? [];
      final List<String> updatedSubNames = [];
      
      // We will sync Level 2 subcategories
      for (var sub in updatedSubs) {
        final subName = sub is Map ? sub['name']?.toString() ?? '' : sub.toString();
        if (subName.isEmpty) continue;
        updatedSubNames.add(subName);
        
        // Check if this Level 2 subcategory already exists
        final subRow = existingSubs.where(
          (r) => r['name']?.toString().toLowerCase() == subName.toLowerCase(),
        ).firstOrNull;
        
        String subId;
        if (subRow == null) {
          // Insert new Level 2 subcategory
          final inserted = await _db.from('categories').insert({
            'name': subName,
            'parent_id': id,
          }).select().single();
          subId = inserted['id'].toString();
        } else {
          subId = subRow['id'].toString();
        }
        
        // Now sync Level 3 sub-subcategories under this Level 2 subcategory
        final existingSubSubs = await _db.from('categories').select().eq('parent_id', subId);
        final List<dynamic> updatedSubSubs = (sub is Map && sub['subcategories'] != null)
            ? sub['subcategories'] as List
            : [];
        final List<String> updatedSubSubNames = [];
        
        for (var subSub in updatedSubSubs) {
          final subSubName = subSub.toString().trim();
          if (subSubName.isEmpty) continue;
          updatedSubSubNames.add(subSubName);
          
          final subSubRow = existingSubSubs.where(
            (r) => r['name']?.toString().toLowerCase() == subSubName.toLowerCase(),
          ).firstOrNull;
          
          if (subSubRow == null) {
            // Insert new Level 3 subcategory
            await _db.from('categories').insert({
              'name': subSubName,
              'parent_id': subId,
            });
          }
        }
        
        // Delete any Level 3 subcategories that are no longer in the list
        for (var row in existingSubSubs) {
          final name = row['name']?.toString() ?? '';
          if (!updatedSubSubNames.any((n) => n.toLowerCase() == name.toLowerCase())) {
            await _db.from('categories').delete().eq('id', row['id']);
          }
        }
      }
      
      // Delete any Level 2 subcategories that are no longer in the list
      for (var row in existingSubs) {
        final name = row['name']?.toString() ?? '';
        if (!updatedSubNames.any((n) => n.toLowerCase() == name.toLowerCase())) {
          await _db.from('categories').delete().eq('id', row['id']);
        }
      }
      
      return {
        'id': parentRow['id'],
        'name': parentRow['name'],
        'subcategories': updatedSubs,
      };
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _db.from('categories').delete().eq('id', id); // Cascade will delete subs
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ─── PRIVATE HELPERS ─────────────────────────────────────────────

  Future<String> _uploadImage(XFile file) async {
    try {
      String ext = file.name.split('.').last.toLowerCase();
      if (ext.isEmpty || ext.length > 5 || ext == file.name.toLowerCase()) {
        ext = 'png';
      }
      final path = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await file.readAsBytes();

      await _db.storage.from('product-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      return imageUrl(path);
    } catch (e) {
      debugPrint('[ApiService] Storage upload error: $e. Using base64 fallback.');
      try {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        return 'data:image/png;base64,$base64Str';
      } catch (dataErr) {
        debugPrint('[ApiService] Base64 fallback error: $dataErr');
        return '';
      }
    }
  }

  Future<String> _uploadBill(XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    final path = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();

    await _db.storage.from('purchase-bills').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return path;
  }

  String _extractStoragePath(String url) {
    final marker = '/product-images/';
    final idx = url.indexOf(marker);
    if (idx == -1) return '';
    return url.substring(idx + marker.length);
  }

  // Sync relational tables: items_size & legacy variant tables
  Future<void> _syncRelationalVariants(String itemId, List<dynamic> variants, {String? itemName}) async {
    try {
      try {
        await _db.from('items_size').delete().eq('item_id', itemId);
      } catch (_) {}
      try {
        await _db.from('item_variants').delete().eq('item_id', itemId);
      } catch (_) {}

      for (var v in variants) {
        final Map<String, dynamic> varMap = Map<String, dynamic>.from(v as Map);
        String? variantId;
        try {
          final varInsert = await _db.from('item_variants').insert({
            'item_id': itemId,
            'color': varMap['color'] ?? varMap['name'] ?? 'Default',
            'image_url': varMap['image_url'] ?? varMap['imageUrl'] ?? '',
          }).select('id').single();
          variantId = varInsert['id']?.toString();
        } catch (_) {}

        final sizes = (varMap['sizes'] as List?) ?? [];
        if (sizes.isNotEmpty) {
          final sizeInserts = sizes.map((sz) {
            final Map<String, dynamic> szMap = Map<String, dynamic>.from(sz as Map);
            final varColor = (varMap['color'] ?? varMap['name'] ?? varMap['variant_name'] ?? 'Default').toString();
            return {
              'item_id': itemId,
              'variant_id': (variantId?.isNotEmpty == true) ? variantId : itemId,
              'item_name': itemName ?? 'Item',
              'variant_name': (varColor.isNotEmpty && varColor != 'Default') ? varColor : null,
              'size': szMap['size']?.toString() ?? '',
              'stock': int.tryParse(szMap['stock']?.toString() ?? '0') ?? 0,
              'cost_price': double.tryParse((szMap['cost_price'] ?? szMap['costPrice'] ?? '0').toString()) ?? 0.0,
              'retail_price': double.tryParse((szMap['retail_price'] ?? szMap['retailPrice'] ?? '0').toString()) ?? 0.0,
              'barcode': szMap['barcode']?.toString() ?? '',
            };
          }).toList();

          try {
            await _db.from('items_size').insert(sizeInserts);
          } catch (e) {
            debugPrint('[ApiService] Insert items_size warning: $e');
          }

          if (variantId != null) {
            final legacyInserts = sizes.map((sz) {
              final Map<String, dynamic> szMap = Map<String, dynamic>.from(sz as Map);
              return {
                'variant_id': variantId,
                'size': szMap['size']?.toString() ?? '',
                'stock': int.tryParse(szMap['stock']?.toString() ?? '0') ?? 0,
                'cost_price': double.tryParse((szMap['cost_price'] ?? szMap['costPrice'] ?? '0').toString()) ?? 0.0,
                'retail_price': double.tryParse((szMap['retail_price'] ?? szMap['retailPrice'] ?? '0').toString()) ?? 0.0,
                'barcode': szMap['barcode']?.toString() ?? '',
              };
            }).toList();
            try {
              await _db.from('item_variant_sizes').insert(legacyInserts);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Relational variant sync warning: $e');
    }
  }

  // Normalize DB to UI models
  static Map<String, dynamic> _normalizeItemRow(Map<String, dynamic> r) {
    List<dynamic> variants = [];
    if (r['variants'] is List && (r['variants'] as List).isNotEmpty) {
      variants = r['variants'] as List;
    } else if (r['items_size'] is List && (r['items_size'] as List).isNotEmpty) {
      final relSizes = r['items_size'] as List;
      final Map<String, List<dynamic>> colorMap = {};
      for (var sz in relSizes) {
        final rawKey = (sz['variant_name'] ?? sz['color'] ?? sz['name'] ?? r['color'] ?? 'Default').toString().trim();
        final colorKey = rawKey.isNotEmpty ? rawKey : 'Default';
        colorMap.putIfAbsent(colorKey, () => []).add(sz);
      }
      variants = colorMap.entries.map((e) {
        return {
          'id': e.value.first['variant_id'] ?? e.value.first['id'],
          'color': e.key,
          'image_url': r['image_url'] ?? '',
          'sizes': e.value.map((sz) {
            return {
              'id': sz['id'],
              'size': sz['size'] ?? '',
              'stock': sz['stock'] ?? 0,
              'cost_price': sz['cost_price'] ?? 0.0,
              'retail_price': sz['retail_price'] ?? 0.0,
              'barcode': sz['barcode'] ?? '',
            };
          }).toList(),
        };
      }).toList();
    } else if (r['item_variants'] is List && (r['item_variants'] as List).isNotEmpty) {
      final relVars = r['item_variants'] as List;
      variants = relVars.map((v) {
        final relSizes = v['item_variant_sizes'] is List ? (v['item_variant_sizes'] as List) : [];
        return {
          'id': v['id'],
          'color': v['color'] ?? 'Default',
          'image_url': v['image_url'] ?? '',
          'sizes': relSizes.map((sz) {
            return {
              'id': sz['id'],
              'size': sz['size'] ?? '',
              'stock': sz['stock'] ?? 0,
              'cost_price': sz['cost_price'] ?? 0.0,
              'retail_price': sz['retail_price'] ?? 0.0,
              'barcode': sz['barcode'] ?? '',
            };
          }).toList(),
        };
      }).toList();
    }

    final bool hasVars = r['has_variants'] == true || variants.isNotEmpty;

    int totalStock = int.tryParse(r['stock']?.toString() ?? '') ?? 0;
    double priceVal = double.tryParse(r['price']?.toString() ?? '') ?? 0.0;
    double retailPriceVal = double.tryParse(r['retail_price']?.toString() ?? '') ?? 0.0;
    String sizeVal = r['size']?.toString() ?? '';
    String barcodeVal = r['barcode']?.toString() ?? '';

    if (variants.isNotEmpty) {
      int aggregatedStock = 0;
      double firstCost = 0.0;
      double firstRetail = 0.0;
      String firstSz = '';
      String firstBc = '';

      for (var v in variants) {
        if (v is Map && v['sizes'] is List) {
          for (var sz in (v['sizes'] as List)) {
            if (sz is Map) {
              final sCount = int.tryParse(sz['stock']?.toString() ?? '0') ?? 0;
              aggregatedStock += sCount;

              final cost = double.tryParse((sz['cost_price'] ?? sz['costPrice'] ?? '0').toString()) ?? 0.0;
              final retail = double.tryParse((sz['retail_price'] ?? sz['retailPrice'] ?? '0').toString()) ?? 0.0;
              final sizeName = sz['size']?.toString() ?? '';
              final bc = sz['barcode']?.toString() ?? '';

              if (firstCost == 0 && cost > 0) firstCost = cost;
              if (firstRetail == 0 && retail > 0) firstRetail = retail;
              if (firstSz.isEmpty && sizeName.isNotEmpty) firstSz = sizeName;
              if (firstBc.isEmpty && bc.isNotEmpty) firstBc = bc;
            }
          }
        }
      }

      totalStock = aggregatedStock;
      if (priceVal == 0) priceVal = firstCost;
      if (retailPriceVal == 0) retailPriceVal = firstRetail;
      if (sizeVal.isEmpty) sizeVal = firstSz;
      if (barcodeVal.isEmpty) barcodeVal = firstBc;
    }

    return {
      'id': r['id'],
      'name': r['item_name'] ?? r['name'] ?? '',
      'category': r['categories']?['name'] ?? r['category_name'] ?? r['category'] ?? '',
      'primeCategory': r['categories']?['name'] ?? r['category_name'] ?? r['category'] ?? '',
      'supplier': r['suppliers']?['name'] ?? r['supplier_name'] ?? r['supplier'] ?? '',
      'supplierId': r['supplier_id']?.toString() ?? '',
      'purchaseDate': r['purchase_date'] ?? r['created_at'],
      'stockUpdatedAt': r['stock_updated_at'] ?? r['updated_at'] ?? r['created_at'],
      'price': priceVal,
      'retailPrice': retailPriceVal,
      'stock': totalStock,
      'image': imageUrl(r['image_url']),
      'image_url': r['image_url'] ?? '',
      'color': r['color'] ?? '',
      'size': sizeVal
          .replaceAll(RegExp(r'\s*Inches|\s*inches', caseSensitive: false), '')
          .trim(),
      'barcode': barcodeVal,
      'createdAt': r['created_at'],
      'branch': r['branches']?['name'] ?? '',
      'hasVariants': hasVars,
      'variantsCount': r['variants_count'] ?? (variants.isEmpty ? 1 : variants.length),
      'variants': variants,
    };
  }

  static Map<String, dynamic> _normalizeSaleRow(Map<String, dynamic> r) {
    final List<dynamic> saleItemsList = r['sale_items'] ?? [];
    final List<dynamic> normalizedItems = saleItemsList.map((item) {
      final itemDetails = item['items'] ?? {};
      final categoryDetails = itemDetails['categories'] ?? {};
      final qty = item['quantity'] ?? 0;
      final unitPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
      final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0.0;
      final costPrice = double.tryParse(itemDetails['price']?.toString() ?? '0') ?? 0.0;

      final String resolvedName = (itemDetails['name'] ??
              itemDetails['item_name'] ??
              item['item_name'] ??
              item['name'] ??
              item['description'] ??
              'Sale Item')
          .toString()
          .trim();
      final String finalName = (resolvedName.isEmpty || resolvedName.toLowerCase() == 'unknown')
          ? 'Sale Item'
          : resolvedName;

      return {
        'id': item['id'],
        'itemId': itemDetails['id']?.toString() ?? item['item_id']?.toString() ?? item['id']?.toString(),
        'quantity': qty,
        'pricePerPiece': unitPrice,
        'costPrice': costPrice,
        'price': unitPrice,
        'totalPrice': subtotal,
        'amount': subtotal,
        'name': finalName,
        'color': itemDetails['color'] ?? item['color'] ?? '',
        'size': itemDetails['size']?.toString() ?? item['size']?.toString() ?? '',
        'category': categoryDetails['name'] ?? '',
      };
    }).toList();

    String rawInv = (r['invoice_number'] ?? r['invoiceNumber'] ?? '').toString();
    if (rawInv.isEmpty || (rawInv.length >= 36 && rawInv.contains('-'))) {
      final idStr = (r['id'] ?? '').toString();
      final shortHash = idStr.contains('-') ? idStr.split('-').first : idStr;
      rawInv = shortHash.isNotEmpty ? 'INV-${shortHash.toUpperCase()}' : 'INV-00000000';
    }

    final String uId = r['user_id']?.toString() ?? r['userId']?.toString() ?? '';
    final String uName = r['user_name']?.toString() ?? r['userName']?.toString() ?? r['profiles']?['full_name'] ?? r['profiles']?['email'] ?? '';

    final double dbTotalAmt = double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0.0;
    final double dbFinalAmt = double.tryParse(r['final_amount']?.toString() ?? '0') ?? dbTotalAmt;
    final double dbDisc = double.tryParse(r['discount']?.toString() ?? '0') ?? 0.0;

    final double itemsSubtotal = normalizedItems.fold<double>(
      0.0,
      (sum, it) => sum + (double.tryParse(it['totalPrice']?.toString() ?? '0') ?? 0.0),
    );

    final double effectiveSubTotal = dbTotalAmt > 0 && dbTotalAmt != dbFinalAmt
        ? dbTotalAmt
        : (itemsSubtotal > 0 ? itemsSubtotal : dbFinalAmt);

    return {
      'id': r['id'],
      'invoiceNumber': rawInv,
      'invoice_number': rawInv,
      'userId': uId,
      'user_id': uId,
      'userName': uName,
      'user_name': uName,
      'date': r['sale_date'] ?? r['created_at'],
      'createdAt': r['created_at'],
      'customerName': r['customer_name'] ?? '',
      'customerPhone': r['customer_phone'] ?? '',
      'items': normalizedItems,
      'subTotal': effectiveSubTotal,
      'discount': dbDisc,
      'grandTotal': dbFinalAmt,
      'totalAmount': dbFinalAmt,
      'taxDetails': r['tax_details'] ?? r['taxDetails'],
      'paymentMethod': r['payment_method'] ?? 'Cash',
      'branch': r['branches']?['name'] ?? '',
    };
  }

  static Map<String, dynamic> _normalizeSupplierRow(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'name': r['name'] ?? '',
      'phone': r['phone'] ?? '',
      'email': r['email'] ?? '',
      'gstin': r['gstin'] ?? '',
      'address': r['address'] ?? '',
      'createdAt': r['created_at'],
    };
  }

  static Map<String, dynamic> _normalizePurchaseRow(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'purchaseNumber': r['invoice_no'] ?? r['id'],
      'supplierId': r['supplier_id'],
      'supplierName': r['suppliers']?['name'] ?? 'Unknown Supplier',
      'date': r['purchase_date'] ?? r['created_at'],
      'items': r['purchase_items'] ?? [],
      'subTotal': r['total_amount'] ?? 0,
      'discount': 0, // Not in new schema, maybe add later if needed
      'grandTotal': r['total_amount'] ?? 0,
      'paymentMethod': r['payment_mode'] ?? 'Cash',
      'status': r['status'] ?? 'Received',
      'branch': r['branches']?['name'] ?? '',
      'createdAt': r['created_at'],
    };
  }

  // ─── STORE SETTINGS ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getStoreSettings() async {
    try {
      final rows = await _db.from('store_settings').select('*').limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
      }
    } catch (e) {
      debugPrint('[ApiService] getStoreSettings warning: $e');
    }
    return null;
  }

  Future<void> saveStoreSettings(Map<String, dynamic> settingsData) async {
    try {
      final existing = await getStoreSettings();
      if (existing != null && existing['id'] != null) {
        await _db.from('store_settings').update(settingsData).eq('id', existing['id']);
      } else {
        await _db.from('store_settings').insert(settingsData);
      }
    } catch (e) {
      debugPrint('[ApiService] saveStoreSettings warning: $e');
    }
  }
}

