import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/export_service.dart';
import 'package:smart_store/src/core/services/pdf_service.dart';
import 'package:smart_store/src/core/utils/csv_helper.dart';
import 'package:smart_store/src/presentation/screens/dashboard/widgets/custom_range_picker.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/core/models/item_variant_model.dart';

enum DateFilter { all, today, singleDate, lastMonth, custom }

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _inventoryItems = [];
  List<dynamic> _salesHistory = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  bool _isCompletingSale = false;

  // Cart State: { itemId: { 'item': item, 'quantity': qty } }
  final Map<String, Map<String, dynamic>> _cart = {};
  String _selectedPaymentMethod = 'Cash';

  final TextEditingController _cartSearchController = TextEditingController();
  final FocusNode _cartSearchFocus = FocusNode();
  bool _showCartSuggestions = false;

  final TextEditingController _salesSearchController = TextEditingController();
  bool _isSearchingSales = false;

  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  late String _digitalBillId;

  // Manual Item Entry State
  bool _isManualItemMode = false;
  final TextEditingController _customItemNameCtrl = TextEditingController();
  final TextEditingController _customItemDescCtrl = TextEditingController();
  final TextEditingController _customItemPriceCtrl = TextEditingController();
  int _customItemQty = 1;

  // Tax State
  double _sgstPercent = 0.0;
  double _cgstPercent = 0.0;
  double _igstPercent = 0.0;
  bool _isInterState = false; // Choose IGST vs (CGST+SGST)

  DateFilter _selectedDateFilter = DateFilter.all;
  DateTime? _selectedSingleDate;
  DateTimeRange? _customDateRange;

  // Pagination State (15 rows per page)
  int _currentPage = 1;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _digitalBillId = _generateDigitalId();
    _loadTaxSettings();
    _loadData();
    BranchService().addListener(_onBranchChanged);
    DataRepository().addListener(_onDataRepoChanged);
  }

  void _onBranchChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _onDataRepoChanged() {
    _loadTaxSettings();
    final currentBranch = BranchService().currentBranch;
    final cachedInv = DataRepository().getCachedInventory(currentBranch);
    final cachedSales = DataRepository().getCachedSales(currentBranch);

    if (mounted) {
      setState(() {
        if (cachedInv != null) {
          _inventoryItems = cachedInv;
        }
        if (cachedSales != null && cachedSales.isNotEmpty) {
          final Map<String, dynamic> merged = {};
          for (var s in cachedSales) {
            final id = (s['id'] ?? s['invoiceNumber'] ?? s['invoice_number'])?.toString();
            if (id != null && id.isNotEmpty) merged[id] = s;
          }
          for (var s in _salesHistory) {
            final id = (s['id'] ?? s['invoiceNumber'] ?? s['invoice_number'])?.toString();
            if (id != null && id.isNotEmpty && !merged.containsKey(id)) {
              merged[id] = s;
            }
          }
          _salesHistory = merged.values.toList();
          _sortSalesHistory();
        }
      });
    }
  }

  Future<void> _loadTaxSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sgstPercent = prefs.getDouble('sgst_percent') ?? 0.0;
      _cgstPercent = prefs.getDouble('cgst_percent') ?? 0.0;
      _igstPercent = prefs.getDouble('igst_percent') ?? 0.0;
    });
  }

  String _formatPct(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toString();
  }

  String _generateDigitalId() {
    final now = DateTime.now();
    return 'DIG-${now.year}${now.month}${now.day}-${now.millisecondsSinceEpoch % 10000}';
  }

  @override
  void dispose() {
    BranchService().removeListener(_onBranchChanged);
    DataRepository().removeListener(_onDataRepoChanged);
    _cartSearchController.dispose();
    _cartSearchFocus.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    _salesSearchController.dispose();
    _customItemNameCtrl.dispose();
    _customItemDescCtrl.dispose();
    _customItemPriceCtrl.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredSalesHistory {
    if (_isLoading) {
      return List.generate(
        5,
        (index) => {
          'id': 'dummy_$index',
          'invoiceNumber': 'DIG-12345678-$index',
          'customerName': 'Loading Customer Name',
          'customerPhone': '1234567890',
          'items': [{}, {}],
          'totalAmount': 1200.0,
          'createdAt': DateTime.now().toIso8601String(),
          'paymentMethod': 'Card',
        },
      );
    }
    final query = _salesSearchController.text.toLowerCase();

    return _salesHistory.where((sale) {
      // 1. Search Query Filter
      bool matchesQuery = true;
      if (query.isNotEmpty) {
        final invoiceNo = (sale['invoiceNumber'] ?? '')
            .toString()
            .toLowerCase();
        final customerName = (sale['customerName'] ?? '')
            .toString()
            .toLowerCase();
        final customerPhone = (sale['customerPhone'] ?? '')
            .toString()
            .toLowerCase();
        matchesQuery =
            invoiceNo.contains(query) ||
            customerName.contains(query) ||
            customerPhone.contains(query);
      }

      if (!matchesQuery) return false;

      // 2. Date Filter
      final saleDateStr = sale['createdAt'] ?? sale['date'];
      if (saleDateStr == null) return _selectedDateFilter == DateFilter.all;

      try {
        final saleDate = DateTime.parse(saleDateStr.toString()).toLocal();
        final now = DateTime.now();

        switch (_selectedDateFilter) {
          case DateFilter.today:
            return saleDate.year == now.year &&
                saleDate.month == now.month &&
                saleDate.day == now.day;
          case DateFilter.singleDate:
            if (_selectedSingleDate == null) return true;
            return saleDate.year == _selectedSingleDate!.year &&
                saleDate.month == _selectedSingleDate!.month &&
                saleDate.day == _selectedSingleDate!.day;
          case DateFilter.lastMonth:
            final thirtyDaysAgo = now.subtract(const Duration(days: 30));
            return saleDate.isAfter(thirtyDaysAgo);
          case DateFilter.custom:
            if (_customDateRange == null) return true;
            final start = DateTime(
              _customDateRange!.start.year,
              _customDateRange!.start.month,
              _customDateRange!.start.day,
            );
            final end = DateTime(
              _customDateRange!.end.year,
              _customDateRange!.end.month,
              _customDateRange!.end.day,
              23,
              59,
              59,
            );
            return saleDate.isAtSameMomentAs(start) ||
                saleDate.isAtSameMomentAs(end) ||
                (saleDate.isAfter(start) && saleDate.isBefore(end));
          case DateFilter.all:
            return true;
        }
      } catch (_) {
        return _selectedDateFilter == DateFilter.all;
      }
    }).toList();
  }

  void _sortSalesHistory() {
    _salesHistory.sort((a, b) {
      final dtA =
          DateTime.tryParse((a['createdAt'] ?? a['date'] ?? '').toString()) ??
          DateTime(1970);
      final dtB =
          DateTime.tryParse((b['createdAt'] ?? b['date'] ?? '').toString()) ??
          DateTime(1970);
      return dtB.compareTo(dtA); // Descending order: Newest at top!
    });
  }

  Future<void> _loadData() async {
    final currentBranch = BranchService().currentBranch;
    final cachedInv = DataRepository().getCachedInventory(currentBranch);
    final cachedSales = DataRepository().getCachedSales(currentBranch);
    final cachedCats = DataRepository().getCachedCategories();

    if (cachedInv != null && cachedInv.isNotEmpty) {
      _inventoryItems = cachedInv;
      _salesHistory = List<dynamic>.from(cachedSales ?? []);
      _sortSalesHistory();
      _categories = cachedCats ?? [];
      _isLoading = false;
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _sgstPercent = prefs.getDouble('sgst_percent') ?? 0.0;
      _cgstPercent = prefs.getDouble('cgst_percent') ?? 0.0;
      _igstPercent = prefs.getDouble('igst_percent') ?? 0.0;

      final results = await Future.wait([
        DataRepository().getInventory(branch: currentBranch),
        DataRepository()
            .getSales(branch: currentBranch)
            .catchError((_) => <dynamic>[]),
        DataRepository().getCategories().catchError((_) => <dynamic>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _inventoryItems = results[0];
        final List<dynamic> remoteSales = results[1];
        final Map<String, dynamic> merged = {};
        for (var s in remoteSales) {
          if (s['id'] != null) merged[s['id'].toString()] = s;
        }
        for (var s in _salesHistory) {
          if (s['id'] != null && !merged.containsKey(s['id'].toString())) {
            merged[s['id'].toString()] = s;
          }
        }
        _salesHistory = merged.values.toList();
        _sortSalesHistory();
        _categories = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportSales(String format) async {
    final salesToExport = _filteredSalesHistory;
    if (salesToExport.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No sales to export')));
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (format == 'csv') {
        final csvContent = ExportService.salesToCsv(salesToExport);
        downloadCSV(content: csvContent, filename: 'sales_$timestamp.csv');
      } else {
        final bytes = await ExportService.salesToXlsx(salesToExport);
        final tempPath = (await getApplicationDocumentsDirectory()).path;
        final file = dart_io.File('$tempPath/sales_$timestamp.xlsx');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                file.path,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
            subject: 'Smart Store Sales Export',
          ),
        );
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${salesToExport.length} sales'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    final bool isVariantSelected = item['isVariantSelected'] == true;
    if (!isVariantSelected && (item['hasVariants'] == true || (item['variants'] != null && (item['variants'] as List).isNotEmpty))) {
      _showVariantPickerModal(context, item);
      return;
    }

    _addSingleItemToCart(item);
  }

  void _showVariantPickerModal(BuildContext context, Map<String, dynamic> item) {
    final rawVars = (item['variants'] as List?) ?? [];
    final variants = rawVars.map((v) => ItemVariant.fromJson(Map<String, dynamic>.from(v as Map))).toList();

    if (variants.isEmpty) {
      _addSingleItemToCart(item);
      return;
    }

    ItemVariant selectedVar = variants.first;
    VariantSize? selectedSize = selectedVar.sizes.isNotEmpty ? selectedVar.sizes.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? 'Select Option',
                          style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text('Select Color / Variant:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: variants.map((v) {
                      final isSel = v.id == selectedVar.id;
                      return ChoiceChip(
                        label: Text(v.color),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.onSurface),
                        onSelected: (sel) {
                          if (sel) {
                            setModalState(() {
                              selectedVar = v;
                              selectedSize = v.sizes.isNotEmpty ? v.sizes.first : null;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Text('Select Size & Stock:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (selectedVar.sizes.isEmpty)
                    Text('No sizes configured for this variant.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedVar.sizes.map((sz) {
                        final isSel = selectedSize?.id == sz.id;
                        final isOut = sz.stock <= 0;
                        return ChoiceChip(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(sz.size, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.onSurface)),
                              Text(
                                '₹${sz.retailPrice > 0 ? sz.retailPrice.toStringAsFixed(0) : item['retailPrice']} (${sz.stock} left)',
                                style: TextStyle(fontSize: 10, color: isSel ? Colors.white70 : (isOut ? AppTheme.error : AppTheme.onSurfaceVariant)),
                              ),
                            ],
                          ),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          onSelected: isOut ? null : (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedSize = sz;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        selectedSize != null
                            ? 'ADD SIZE ${selectedSize!.size} (₹${selectedSize!.retailPrice > 0 ? selectedSize!.retailPrice.toStringAsFixed(0) : item['retailPrice']})'
                            : 'SELECT SIZE',
                      ),
                      onPressed: selectedSize == null || selectedSize!.stock <= 0
                          ? null
                          : () {
                              final variantItemId = '${item['id']}_${selectedVar.color}_${selectedSize!.size}';
                              final variantItemMap = <String, dynamic>{
                                ...Map<String, dynamic>.from(item as Map),
                                'id': variantItemId,
                                'name': '${item['name']} (${selectedVar.color} - ${selectedSize!.size})',
                                'color': selectedVar.color,
                                'size': selectedSize!.size,
                                'price': selectedSize!.costPrice > 0 ? selectedSize!.costPrice : item['price'],
                                'retailPrice': selectedSize!.retailPrice > 0 ? selectedSize!.retailPrice : item['retailPrice'],
                                'stock': selectedSize!.stock,
                                'barcode': selectedSize!.barcode,
                                'isVariantSelected': true,
                              };
                              Navigator.pop(ctx);
                              _addSingleItemToCart(variantItemMap);
                              setState(() {
                                _cartSearchController.clear();
                                _showCartSuggestions = false;
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleBarcodeSubmitted(String input) {
    final query = input.trim();
    if (query.isEmpty) return;

    // 1. Search for exact size barcode in variants matrix
    for (var item in _inventoryItems) {
      if (item['variants'] != null && (item['variants'] as List).isNotEmpty) {
        final rawVars = item['variants'] as List;
        for (var vMap in rawVars) {
          final color = vMap['color'] ?? '';
          final sizes = (vMap['sizes'] as List?) ?? [];
          for (var szMap in sizes) {
            final barcode = (szMap['barcode'] ?? '').toString();
            if (barcode.isNotEmpty && barcode.toLowerCase() == query.toLowerCase()) {
              final variantItemId = '${item['id']}_${color}_${szMap['size']}';
              final variantItemMap = <String, dynamic>{
                ...Map<String, dynamic>.from(item as Map),
                'id': variantItemId,
                'name': '${item['name']} ($color - ${szMap['size']})',
                'color': color,
                'size': szMap['size']?.toString() ?? '',
                'price': double.tryParse(szMap['cost_price']?.toString() ?? '0') ?? item['price'],
                'retailPrice': double.tryParse(szMap['retail_price']?.toString() ?? '0') ?? item['retailPrice'],
                'stock': int.tryParse(szMap['stock']?.toString() ?? '0') ?? 0,
                'barcode': barcode,
                'isVariantSelected': true,
              };
              _addSingleItemToCart(variantItemMap);
              _cartSearchController.clear();
              setState(() => _showCartSuggestions = false);
              return;
            }
          }
        }
      }
      // 2. Direct item barcode match
      final itemBarcode = (item['barcode'] ?? '').toString();
      if (itemBarcode.isNotEmpty && itemBarcode.toLowerCase() == query.toLowerCase()) {
        _addToCart(item);
        _cartSearchController.clear();
        setState(() => _showCartSuggestions = false);
        return;
      }
    }
  }

  void _addSingleItemToCart(Map<String, dynamic> item) {
    setState(() {
      final id = item['id'].toString();
      final stock = item['stock'] ?? 0;

      int currentQtyInCart = _cart[id]?['quantity'] ?? 0;

      if (currentQtyInCart < stock) {
        if (_cart.containsKey(id)) {
          _cart[id]!['quantity']++;
        } else {
          _cart[id] = {'item': item, 'quantity': 1};
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough stock available for selected option!')),
        );
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      if (_cart.containsKey(id)) {
        if (_cart[id]!['quantity'] > 1) {
          _cart[id]!['quantity']--;
        } else {
          _cart.remove(id);
        }
      }
    });
  }

  double get _subtotal {
    return _cart.values.fold(0, (sum, entry) {
      final item = entry['item'];
      final double cost =
          double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final double ret =
          double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
      final double effectivePrice = ret > 0 ? ret : (cost > 0 ? cost * 2.0 : 0);
      return sum + (effectivePrice * entry['quantity']);
    });
  }

  double get _sgst => _isInterState ? 0 : (_subtotal * _sgstPercent / 100);
  double get _cgst => _isInterState ? 0 : (_subtotal * _cgstPercent / 100);
  double get _igst => _isInterState ? (_subtotal * _igstPercent / 100) : 0;
  double get _totalTax => _sgst + _cgst + _igst;
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0.0;
  double get _total => (_subtotal + _totalTax) - _discount;

  Future<void> _completeSale() async {
    if (_cart.isEmpty || _isCompletingSale) return;

    setState(() => _isCompletingSale = true);
    try {
      final invoice = {
        'invoiceNumber': _digitalBillId,
        'date': DateTime.now().toIso8601String(),
        'customerName': _customerNameCtrl.text.isEmpty
            ? 'Walk-in Customer'
            : _customerNameCtrl.text,
        'customerPhone': _customerPhoneCtrl.text,
        'items': _cart.values.map((entry) {
          final item = entry['item'];
          final double cost =
              double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          final double ret =
              double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
          final double effectivePrice = ret > 0
              ? ret
              : (cost > 0 ? cost * 2.0 : 0);

          return {
            'itemId': item['id'].toString(),
            'name': item['name'],
            'color': item['color']?.toString() ?? '',
            'size': item['size']?.toString() ?? '',
            'quantity': entry['quantity'],
            'costPrice': cost,
            'pricePerPiece': effectivePrice,
            'totalPrice': effectivePrice * entry['quantity'],
          };
        }).toList(),
        'subTotal': _subtotal,
        'taxDetails': {
          'sgst': _sgst,
          'cgst': _cgst,
          'igst': _igst,
          'totalTax': _totalTax,
          'isInterState': _isInterState,
          'sgstPercent': _sgstPercent,
          'cgstPercent': _cgstPercent,
          'igstPercent': _igstPercent,
        },
        'discount': _discount,
        'grandTotal': _total,
        'paymentMethod': _selectedPaymentMethod,
      };

      final createdSale = await _apiService.createInvoiceSale(
        invoice,
        branch: BranchService().currentBranch,
      );

      if (!mounted) return;

      final saleData =
          createdSale is Map<String, dynamic> ? createdSale : invoice;

      setState(() {
        if (createdSale is Map<String, dynamic>) {
          _salesHistory.insert(0, createdSale);
          _sortSalesHistory();
          _currentPage = 1;
        }
        _cart.clear();
        _customerNameCtrl.clear();
        _customerPhoneCtrl.clear();
        _discountCtrl.text = '0';
        _selectedPaymentMethod = 'Cash';
        _digitalBillId = _generateDigitalId();
        _isCompletingSale = false;
      });

      // Background data sync so stock & history update without blocking UI
      _loadData();

      // Show success popup dialog!
      _showSaleSuccessDialog(saleData);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCompletingSale = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing sale: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSaleSuccessDialog(Map<String, dynamic> sale) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final String invoiceNo =
        sale['invoiceNumber'] ?? sale['invoice_number'] ?? _digitalBillId;
    final String custName =
        sale['customerName'] ?? sale['customer_name'] ?? 'Walk-in Customer';
    final double grandTotal = double.tryParse(
            (sale['grandTotal'] ?? sale['total'] ?? 0).toString()) ??
        0.0;
    final String payMethod =
        sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash';
    final List itemsList = (sale['items'] as List?) ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sale Completed!',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Digital Bill #$invoiceNo',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppTheme.outline)),
                      Text(
                        currencyFormat.format(grandTotal),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Customer',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.outline)),
                      Text(custName,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Method',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.outline)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          payMethod.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (itemsList.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items Count',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.outline)),
                        Text('${itemsList.length} item(s)',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PdfService.generateAndPrintInvoice(sale);
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('PRINT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PdfService.generateAndShareInvoice(sale);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('SHARE'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('NEW SALE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesHistory() {
    final filtered = _filteredSalesHistory;
    final int totalItems = filtered.length;
    final int totalPages = totalItems == 0
        ? 1
        : (totalItems / _pageSize).ceil();
    final int safePage = _currentPage > totalPages
        ? totalPages
        : (_currentPage < 1 ? 1 : _currentPage);
    final int startIndex = (safePage - 1) * _pageSize;
    final pagedSales = filtered.skip(startIndex).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isSearchingSales) ...[
          _buildDateFilters(),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isSearchingSales)
              Text(
                'SALES HISTORY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.outline,
                  letterSpacing: 1.5,
                ),
              )
            else
              Expanded(
                child: TextField(
                  controller: _salesSearchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search invoice, customer...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppTheme.outline.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _salesSearchController.clear();
                          _isSearchingSales = false;
                          _currentPage = 1;
                        });
                      },
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() => _currentPage = 1),
                ),
              ),
            Row(
              children: [
                if (!_isSearchingSales)
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppTheme.outline,
                    ),
                    onPressed: () => setState(() => _isSearchingSales = true),
                  ),
                TextButton(
                  onPressed: _loadData,
                  child: Text(
                    'Refresh',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!_isSearchingSales) const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: AppTheme.outline.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _salesSearchController.text.isEmpty
                        ? 'No sales found yet.'
                        : 'No invoices match your search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.outline),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedSales.length,
            itemBuilder: (context, index) {
              final sale = pagedSales[index];

              String invNum = (sale['invoiceNumber'] ?? '').toString();
              if (invNum.isEmpty ||
                  (invNum.length >= 36 && invNum.contains('-'))) {
                final idStr = (sale['id'] ?? '').toString();
                final shortHash = idStr.contains('-')
                    ? idStr.split('-').first
                    : idStr;
                invNum = shortHash.isNotEmpty
                    ? 'INV-${shortHash.toUpperCase()}'
                    : 'INV-00000000';
              }
              final customer =
                  (sale['customerName'] != null &&
                      sale['customerName'].toString().trim().isNotEmpty)
                  ? sale['customerName'].toString()
                  : 'Walk-in Customer';
              final int itemQty = sale['items'] is List
                  ? (sale['items'] as List).length
                  : 1;

              return InkWell(
                onTap: () => _showInvoiceDetailsDialog(context, sale),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getPaymentIconColor(
                            sale['paymentMethod'],
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getPaymentIcon(sale['paymentMethod']),
                          size: 20,
                          color: _getPaymentIconColor(sale['paymentMethod']),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invNum,
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$customer • $itemQty ${itemQty == 1 ? 'item' : 'items'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${_formatAmount(sale['grandTotal'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? 0)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            _formatDate(sale['createdAt'] ?? sale['date']),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (totalItems > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${startIndex + 1}-${startIndex + pagedSales.length} of $totalItems',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.outline,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: safePage > 1
                              ? () =>
                                    setState(() => _currentPage = safePage - 1)
                              : null,
                          tooltip: 'Previous Page',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Page $safePage / $totalPages',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: safePage < totalPages
                              ? () =>
                                    setState(() => _currentPage = safePage + 1)
                              : null,
                          tooltip: 'Next Page',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDateFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildFilterChip('All', DateFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Today', DateFilter.today),
          const SizedBox(width: 8),
          _buildFilterChip(
            _selectedDateFilter == DateFilter.singleDate &&
                    _selectedSingleDate != null
                ? DateFormat('dd MMM yyyy').format(_selectedSingleDate!)
                : 'Select Date 📅',
            DateFilter.singleDate,
          ),
          const SizedBox(width: 8),
          _buildFilterChip('Last 30 Days', DateFilter.lastMonth),
          const SizedBox(width: 8),
          _buildFilterChip(
            _selectedDateFilter == DateFilter.custom && _customDateRange != null
                ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                : 'Custom Range',
            DateFilter.custom,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DateFilter filter) {
    bool isSelected = _selectedDateFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) async {
        if (filter == DateFilter.singleDate) {
          if (selected) {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedSingleDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() {
                _selectedDateFilter = DateFilter.singleDate;
                _selectedSingleDate = picked;
                _currentPage = 1;
              });
            }
          }
        } else if (filter == DateFilter.custom) {
          if (selected) {
            final DateTimeRange? picked = await showDialog<DateTimeRange>(
              context: context,
              builder: (context) => CustomRangePicker(
                initialStart:
                    _customDateRange?.start ??
                    DateTime.now().subtract(const Duration(days: 30)),
                initialEnd: _customDateRange?.end ?? DateTime.now(),
              ),
            );
            if (picked != null) {
              setState(() {
                _selectedDateFilter = DateFilter.custom;
                _customDateRange = picked;
                _currentPage = 1;
              });
            }
          }
        } else {
          setState(() {
            _selectedDateFilter = filter;
            _currentPage = 1;
          });
        }
      },
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainerLow,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  IconData _getPaymentIcon(dynamic method) {
    if (method == 'Card') return Icons.credit_card;
    if (method == 'UPI') return Icons.qr_code_2;
    return Icons.payments;
  }

  Color _getPaymentIconColor(dynamic method) {
    if (method == 'Card') return const Color(0xFF6366F1);
    if (method == 'UPI') return const Color(0xFF8B5CF6);
    return const Color(0xFF10B981);
  }

  void _showInvoiceDetailsDialog(
    BuildContext context,
    Map<String, dynamic> sale,
  ) {
    final items = (sale['items'] as List?) ?? [];
    final bool isInvoice = sale.containsKey('invoiceNumber');
    String invoiceNo = (sale['invoiceNumber'] ?? '').toString();
    if (invoiceNo.isEmpty ||
        (invoiceNo.length >= 36 && invoiceNo.contains('-'))) {
      final idStr = (sale['id'] ?? '').toString();
      final shortHash = idStr.contains('-') ? idStr.split('-').first : idStr;
      invoiceNo = shortHash.isNotEmpty
          ? 'INV-${shortHash.toUpperCase()}'
          : 'INV-00000000';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isInvoice ? Icons.receipt_long : Icons.shopping_basket,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoiceNo,
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            _formatDate(sale['createdAt'] ?? sale['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Section
                      Text(
                        'CUSTOMER DETAILS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.outline,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppTheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sale['customerName'] ?? 'Walk-in Customer',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (sale['customerPhone'] != null &&
                          sale['customerPhone'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: AppTheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(sale['customerPhone'].toString()),
                          ],
                        ),
                      ],

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
                      ),

                      // Items Table
                      Text(
                        'ORDER BREAKDOWN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.outline,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(4),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(2.5),
                          3: FlexColumnWidth(2.5),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildTableHeader('Item'),
                              _buildTableHeader('Qty'),
                              _buildTableHeader('Price'),
                              _buildTableHeader(
                                'Total',
                                align: TextAlign.right,
                              ),
                            ],
                          ),
                          ...items.map((item) {
                            final primeCat = _resolvePrimeCategory(
                              item['category'] ?? '',
                            );
                            final String rawItemName = (item['name'] ?? item['item_name'] ?? item['description'] ?? '').toString().trim();
                            final String cleanItemName = (rawItemName.isEmpty || rawItemName.toLowerCase() == 'unknown') ? 'Sale Item' : rawItemName;
                            final String displayName = (primeCat.isNotEmpty && !cleanItemName.toLowerCase().startsWith(primeCat.toLowerCase()))
                                ? '$primeCat - $cleanItemName'
                                : cleanItemName;
                            final color = item['color']?.toString() ?? '';
                            final size = item['size']?.toString() ?? '';
                            final List<String> details = [
                              if (color.isNotEmpty) 'Color: $color',
                              if (size.isNotEmpty) 'Size: $size',
                            ];
                            final detailsText = details.join(' • ');

                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (detailsText.isNotEmpty)
                                        Text(
                                          detailsText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.outline,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(item['quantity'].toString()),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    '₹${_formatAmount(item['pricePerPiece'] ?? item['price'] ?? item['unitPrice'] ?? 0)}',
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    '₹${_formatAmount(item['totalPrice'] ?? item['amount'] ?? item['subtotal'] ?? 0)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
                      ),

                      // Calculate accurate Subtotal, Tax, Discount & Grand Total
                      Builder(builder: (context) {
                        final double gTotal = double.tryParse((sale['grandTotal'] ?? sale['grand_total'] ?? sale['final_amount'] ?? sale['totalAmount'] ?? 0).toString()) ?? 0.0;
                        final double discount = double.tryParse((sale['discount'] ?? 0).toString()) ?? 0.0;
                        final double itemsSum = items.fold<double>(
                          0.0,
                          (sum, it) => sum + (double.tryParse((it['totalPrice'] ?? it['amount'] ?? it['subtotal'] ?? 0).toString()) ?? 0.0),
                        );
                        final double dbSub = double.tryParse((sale['subTotal'] ?? sale['sub_total'] ?? 0).toString()) ?? 0.0;
                        final double effectiveSub = itemsSum > 0
                            ? itemsSum
                            : (dbSub > 0 && dbSub != gTotal ? dbSub : gTotal);
                        final double calculatedTax = (gTotal - effectiveSub + discount).clamp(0.0, double.infinity);
                        final taxDetails = sale['taxDetails'] ?? sale['tax_details'];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryRow(
                              'Subtotal',
                              '₹${_formatAmount(effectiveSub)}',
                            ),

                            // Tax Breakdown (Placed above Discount)
                            if (taxDetails != null && taxDetails is Map) ...[
                              if ((double.tryParse(taxDetails['sgst']?.toString() ?? '0') ?? 0) > 0 ||
                                  (double.tryParse(taxDetails['sgstPercent']?.toString() ?? '0') ?? 0) > 0)
                                _buildSummaryRow(
                                  'SGST (${_formatPct(double.tryParse(taxDetails['sgstPercent']?.toString() ?? '') ?? _sgstPercent)}%)',
                                  '₹${_formatAmount(taxDetails['sgst'])}',
                                ),
                              if ((double.tryParse(taxDetails['cgst']?.toString() ?? '0') ?? 0) > 0 ||
                                  (double.tryParse(taxDetails['cgstPercent']?.toString() ?? '0') ?? 0) > 0)
                                _buildSummaryRow(
                                  'CGST (${_formatPct(double.tryParse(taxDetails['cgstPercent']?.toString() ?? '') ?? _cgstPercent)}%)',
                                  '₹${_formatAmount(taxDetails['cgst'])}',
                                ),
                              if ((double.tryParse(taxDetails['igst']?.toString() ?? '0') ?? 0) > 0 ||
                                  (double.tryParse(taxDetails['igstPercent']?.toString() ?? '0') ?? 0) > 0)
                                _buildSummaryRow(
                                  'IGST (${_formatPct(double.tryParse(taxDetails['igstPercent']?.toString() ?? '') ?? _igstPercent)}%)',
                                  '₹${_formatAmount(taxDetails['igst'])}',
                                ),
                              if ((double.tryParse(taxDetails['totalTax']?.toString() ?? '0') ?? 0) > 0 &&
                                  (double.tryParse(taxDetails['sgst']?.toString() ?? '0') ?? 0) == 0 &&
                                  (double.tryParse(taxDetails['igst']?.toString() ?? '0') ?? 0) == 0)
                                _buildSummaryRow(
                                  'Tax / GST',
                                  '₹${_formatAmount(taxDetails['totalTax'])}',
                                ),
                            ] else ...[
                              _buildSummaryRow(
                                calculatedTax > 0 && effectiveSub > 0
                                    ? 'Tax / GST (${((calculatedTax / effectiveSub) * 100).toStringAsFixed(1)}%)'
                                    : 'Tax',
                                '₹${_formatAmount(calculatedTax)}',
                              ),
                            ],

                            // Discount Box (Placed below Tax)
                            if (discount > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_offer_outlined,
                                            size: 16, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Discount Applied',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '-₹${_formatAmount(discount)}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],

                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '₹${_formatAmount(gTotal)}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Payment: ${sale['paymentMethod'] ?? 'Cash'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                PdfService.generateAndPrintInvoice(sale),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('PRINT RECEIPT'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                PdfService.generateAndShareInvoice(sale),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('DOWNLOAD'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('DONE'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(dynamic val) {
    if (val == null) return '0';
    try {
      final double amount = double.parse(val.toString());
      if (amount % 1 == 0) return amount.toInt().toString();
      return amount.toStringAsFixed(2);
    } catch (_) {
      return val.toString();
    }
  }

  Widget _buildTableHeader(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppTheme.outline,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.outline)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _resolvePrimeCategory(String categoryName) {
    if (categoryName.isEmpty) return '';
    for (var prime in _categories) {
      final primeName = prime['name']?.toString() ?? '';
      if (primeName.toLowerCase() == categoryName.toLowerCase()) {
        return primeName;
      }

      final List<dynamic> cat2List = prime['subcategories'] ?? [];
      for (var cat2 in cat2List) {
        final cat2Name = cat2 is Map
            ? (cat2['name']?.toString() ?? '')
            : cat2.toString();
        if (cat2Name.toLowerCase() == categoryName.toLowerCase()) {
          return primeName;
        }

        if (cat2 is Map && cat2['subcategories'] != null) {
          final List<dynamic> cat3List = cat2['subcategories'];
          for (var cat3 in cat3List) {
            final cat3Name = cat3.toString();
            if (cat3Name.toLowerCase() == categoryName.toLowerCase()) {
              return primeName;
            }
          }
        }
      }
    }
    return categoryName;
  }

  Widget _buildCartSearchResults() {
    final query = _cartSearchController.text.trim().toLowerCase();
    final results = _inventoryItems.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final color = (item['color'] ?? '').toString().toLowerCase();
      final size = (item['size'] ?? '').toString().toLowerCase();
      if (name.contains(query) || color.contains(query) || size.contains(query)) return true;

      // Match size matrix barcodes
      if (item['variants'] != null && (item['variants'] as List).isNotEmpty) {
        final rawVars = item['variants'] as List;
        for (var v in rawVars) {
          final sizes = (v['sizes'] as List?) ?? [];
          for (var sz in sizes) {
            final barcode = (sz['barcode'] ?? '').toString().toLowerCase();
            if (barcode.isNotEmpty && barcode == query) return true;
          }
        }
      }
      return false;
    }).take(8).toList();

    if (results.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: results.map((item) {
          final isOutOfStock = (item['stock'] ?? 0) <= 0;
          final primeCat = _resolvePrimeCategory(item['category'] ?? '');
          final size = item['size']?.toString() ?? '';
          final color = item['color']?.toString() ?? '';
          final double retailPriceVal =
              double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
          final double costPriceVal =
              double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          final calculatedRetail = retailPriceVal > 0
              ? retailPriceVal
              : (costPriceVal > 0 ? costPriceVal * 2.0 : 0);

          final List<String> leftDetails = [
            if (primeCat.isNotEmpty) primeCat,
            if (size.isNotEmpty) 'Size: $size',
            if (color.isNotEmpty) 'Color: $color',
          ];
          final detailsText = leftDetails.join(' • ');

          return ListTile(
            dense: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item['name'] ?? '',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '₹${calculatedRetail.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    detailsText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isOutOfStock ? AppTheme.error : AppTheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stock: ${item['stock']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOutOfStock ? AppTheme.error : AppTheme.outline,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.add_shopping_cart,
                size: 18,
                color: isOutOfStock ? AppTheme.outline : AppTheme.primary,
              ),
              onPressed: isOutOfStock
                  ? null
                  : () {
                      _addToCart(item);
                      setState(() {
                        _cartSearchController.clear();
                        _showCartSuggestions = false;
                      });
                      _cartSearchFocus.unfocus();
                    },
            ),
            onTap: isOutOfStock
                ? null
                : () {
                    _addToCart(item);
                    setState(() {
                      _cartSearchController.clear();
                      _showCartSuggestions = false;
                    });
                    _cartSearchFocus.unfocus();
                  },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.primary,
                ),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'POS TERMINAL',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/sales/new'),
            icon: const Icon(Icons.receipt_long, color: AppTheme.primary),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.primary),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.primary),
            onSelected: (val) {
              if (val == 'export_csv') _exportSales('csv');
              if (val == 'export_xlsx') _exportSales('xlsx');
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export_csv',
                child: const Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Export CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_xlsx',
                child: const Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Export Excel'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Daily Sales',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Skeletonizer(
        enabled: _isLoading,
        containersColor: AppTheme.outline,
        effect: ShimmerEffect(
          baseColor: AppTheme.surfaceContainerHighest,
          highlightColor: AppTheme.surfaceContainer,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales Management',
                          style: GoogleFonts.manrope(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildCartSection(context),
              const SizedBox(height: 32),
              _buildSalesHistory(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Invoice',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_cart.length} ITEMS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // --- ITEM SEARCH FOR CART ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CUSTOMER DETAILS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.outline,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ID: $_digitalBillId',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(DateTime.now()),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customerNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Customer Name',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppTheme.outline.withValues(alpha: 0.5),
                          ),
                          prefixIcon: const Icon(Icons.person, size: 16),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customerPhoneCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Phone (Optional)',
                          counterText: '',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppTheme.outline.withValues(alpha: 0.5),
                          ),
                          prefixIcon: const Icon(Icons.phone, size: 16),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADD ITEM TO CART',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.outline,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: !_isManualItemMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !_isManualItemMode
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            ),
                          ),
                          selected: !_isManualItemMode,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceContainerLow,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (val) {
                            if (val) setState(() => _isManualItemMode = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Manual / Custom Item',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _isManualItemMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _isManualItemMode
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            ),
                          ),
                          selected: _isManualItemMode,
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceContainerLow,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (val) {
                            if (val) setState(() => _isManualItemMode = true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isManualItemMode) ...[
                  TextField(
                    controller: _cartSearchController,
                    focusNode: _cartSearchFocus,
                    onChanged: (val) =>
                        setState(() => _showCartSuggestions = val.isNotEmpty),
                    onSubmitted: (val) => _handleBarcodeSubmitted(val),
                    onTap: () => setState(
                      () => _showCartSuggestions =
                          _cartSearchController.text.isNotEmpty,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search product or Scan size barcode...',
                      hintStyle: TextStyle(
                        color: AppTheme.outline.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppTheme.outline,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_cartSearchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _cartSearchController.clear();
                                  _showCartSuggestions = false;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 22),
                            tooltip: 'Focus Barcode Scanner',
                            onPressed: () {
                              _cartSearchFocus.requestFocus();
                              if (_cartSearchController.text.isNotEmpty) {
                                _handleBarcodeSubmitted(_cartSearchController.text);
                              }
                            },
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLow,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_showCartSuggestions &&
                      _cartSearchController.text.isNotEmpty)
                    _buildCartSearchResults(),
                ] else ...[
                  _buildManualItemForm(),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (_cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Center(child: Text('Your cart is empty')),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: _cart.values.map((entry) {
                  return _buildCartItem(entry);
                }).toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(24.0),
            color: AppTheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTotalRow(
                  'Subtotal',
                  '₹${_subtotal.toStringAsFixed(2)}',
                  false,
                ),
                const SizedBox(height: 12),
                if (!_isInterState) ...[
                  _buildTotalRow(
                    'SGST (${_formatPct(_sgstPercent)}%)',
                    '₹${_sgst.toStringAsFixed(2)}',
                    false,
                  ),
                  const SizedBox(height: 8),
                  _buildTotalRow(
                    'CGST (${_formatPct(_cgstPercent)}%)',
                    '₹${_cgst.toStringAsFixed(2)}',
                    false,
                  ),
                ] else
                  _buildTotalRow(
                    'IGST (${_formatPct(_igstPercent)}%)',
                    '₹${_igst.toStringAsFixed(2)}',
                    false,
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppTheme.outlineVariant,
                            ),
                          ),
                          isDense: true,
                          fillColor: AppTheme.surfaceContainerLowest,
                          filled: true,
                        ),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(),
                ),
                _buildTotalRow(
                  'Total Amount',
                  '₹${_total.toStringAsFixed(2)}',
                  true,
                ),
                const SizedBox(height: 24),
                Text(
                  'PAYMENT METHOD',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentMethod(
                        'Cash',
                        Icons.payments,
                        _selectedPaymentMethod == 'Cash',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentMethod(
                        'Card',
                        Icons.credit_card,
                        _selectedPaymentMethod == 'Card',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentMethod(
                        'UPI',
                        Icons.qr_code_2,
                        _selectedPaymentMethod == 'UPI',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      (_cart.isEmpty || _isCompletingSale) ? null : _completeSale,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCompletingSale
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'PROCESSING...',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        )
                      : const Text(
                          'COMPLETE SALE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Local GST',
                      style: TextStyle(
                        fontSize: 10,
                        color: !_isInterState
                            ? AppTheme.primary
                            : AppTheme.outline,
                      ),
                    ),
                    Switch(
                      value: _isInterState,
                      onChanged: (v) => setState(() => _isInterState = v),
                      activeThumbColor: AppTheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      'Interstate (IGST)',
                      style: TextStyle(
                        fontSize: 10,
                        color: _isInterState
                            ? AppTheme.primary
                            : AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> entry) {
    final item = entry['item'];
    final qty = entry['quantity'];

    final primeCat = _resolvePrimeCategory(item['category'] ?? '');
    final size = item['size']?.toString() ?? '';
    final color = item['color']?.toString() ?? '';
    final double retailPriceVal =
        double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
    final double costPriceVal =
        double.tryParse(item['price']?.toString() ?? '0') ?? 0;
    final calculatedRetail = retailPriceVal > 0
        ? retailPriceVal
        : (costPriceVal > 0 ? costPriceVal * 2.0 : 0);

    final List<String> leftDetails = [
      if (primeCat.isNotEmpty) primeCat,
      if (size.isNotEmpty) 'Size: $size',
      if (color.isNotEmpty) 'Color: $color',
    ];
    final detailsText = leftDetails.join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checkroom, color: AppTheme.outline),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (detailsText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detailsText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '₹${calculatedRetail.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => _removeFromCart(item['id'].toString()),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  qty.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => _addSingleItemToCart(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppTheme.primary : AppTheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 24 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.normal,
            color: isTotal ? AppTheme.primary : AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(String text, IconData icon, bool selected) {
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = text),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryContainer.withValues(alpha: 0.1)
              : AppTheme.surfaceContainerLowest,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outlineVariant,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : AppTheme.onSurface,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: selected ? AppTheme.primary : AppTheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualItemForm() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _customItemNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Item Name *',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.outline.withValues(alpha: 0.6),
                      ),
                      prefixIcon: const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _customItemDescCtrl,
                    decoration: InputDecoration(
                      hintText: 'Description / Note (Optional)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.outline.withValues(alpha: 0.6),
                      ),
                      prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _customItemPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Price *',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.outline.withValues(alpha: 0.6),
                      ),
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                    ),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qty',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildQuantitySelector(),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ElevatedButton.icon(
                    onPressed: _addCustomItemToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: _customItemNameCtrl,
              decoration: InputDecoration(
                hintText: 'Item Name *',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: AppTheme.outline.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerLowest,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customItemDescCtrl,
              decoration: InputDecoration(
                hintText: 'Description / Note (Optional)',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: AppTheme.outline.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerLowest,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customItemPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Price *',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.outline.withValues(alpha: 0.6),
                      ),
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                    ),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildQuantitySelector(),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addCustomItemToCart,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('Add to Cart'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: _customItemQty > 1
                ? () => setState(() => _customItemQty--)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$_customItemQty',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => setState(() => _customItemQty++),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _addCustomItemToCart() {
    final name = _customItemNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    final double price =
        double.tryParse(_customItemPriceCtrl.text.trim()) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final String desc = _customItemDescCtrl.text.trim();
    final String customId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    final customItemMap = {
      'id': customId,
      'name': name,
      'category': 'Custom',
      'description': desc,
      'color': desc,
      'size': '',
      'price': price,
      'retailPrice': price,
      'stock': 999999,
      'isCustom': true,
    };

    setState(() {
      if (_cart.containsKey(customId)) {
        _cart[customId]!['quantity'] += _customItemQty;
      } else {
        _cart[customId] = {'item': customItemMap, 'quantity': _customItemQty};
      }

      _customItemNameCtrl.clear();
      _customItemDescCtrl.clear();
      _customItemPriceCtrl.clear();
      _customItemQty = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to cart!'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
