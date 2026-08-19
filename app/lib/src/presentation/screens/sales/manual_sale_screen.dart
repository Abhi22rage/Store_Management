import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';

class _LineItem {
  Map<String, dynamic>? selectedItem;
  String? selectedSize;
  String? selectedColor;
  int quantity = 1;
  double pricePerPiece = 0;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  bool showSuggestions = false;

  // Custom manual item fields
  bool isCustom = false;
  final TextEditingController customNameController = TextEditingController();
  final TextEditingController customDescController = TextEditingController();
  final TextEditingController customPriceController = TextEditingController();

  double get totalPrice => pricePerPiece * quantity;

  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    customNameController.dispose();
    customDescController.dispose();
    customPriceController.dispose();
  }
}

class ManualSaleScreen extends StatefulWidget {
  const ManualSaleScreen({super.key});

  @override
  State<ManualSaleScreen> createState() => _ManualSaleScreenState();
}

class _ManualSaleScreenState extends State<ManualSaleScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _inventoryItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Tax Settings
  double _sgstPercent = 0.0;
  double _cgstPercent = 0.0;
  double _igstPercent = 0.0;
  bool _isInterState = false;

  // Invoice header
  late String _invoiceNumber;
  DateTime _selectedDate = DateTime.now();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');

  // Line items
  final List<_LineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _invoiceNumber = _generateInvoiceNumber();
    _lineItems.add(_LineItem());
    BranchService().addListener(_loadData);
    DataRepository().addListener(_onDataRepoChanged);
    _loadData();
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    BranchService().removeListener(_loadData);
    DataRepository().removeListener(_onDataRepoChanged);
    for (var item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _onDataRepoChanged() {
    final cachedInv = DataRepository().getCachedInventory(BranchService().currentBranch);
    if (cachedInv != null && mounted) {
      setState(() {
        _inventoryItems = cachedInv;
      });
    }
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);
    final counter = (now.millisecondsSinceEpoch % 1000).toString().padLeft(
      3,
      '0',
    );
    return 'INV-$datePart-$counter';
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sgstPercent = prefs.getDouble('sgst_percent') ?? 0.0;
      _cgstPercent = prefs.getDouble('cgst_percent') ?? 0.0;
      _igstPercent = prefs.getDouble('igst_percent') ?? 0.0;

      final items = await _apiService.getInventory(branch: BranchService().currentBranch);
      if (!mounted) return;
      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<String> _getSizesForItem(Map<String, dynamic> item) {
    List<String> sizes = [];

    if (item['variants'] != null && item['variants'] is List) {
      for (var v in (item['variants'] as List)) {
        if (v is Map && v['sizes'] is List) {
          for (var sz in (v['sizes'] as List)) {
            if (sz is Map) {
              final sName = sz['size']?.toString().trim();
              if (sName != null && sName.isNotEmpty && !sizes.contains(sName)) {
                sizes.add(sName);
              }
            }
          }
        }
      }
    }

    final s = item['size']?.toString();
    if (s != null && s.trim().isNotEmpty && !sizes.contains(s.trim())) {
      sizes.add(s.trim());
    }

    return sizes;
  }

  List<String> _getColorsForItem(Map<String, dynamic> item) {
    List<String> colors = [];

    if (item['variants'] != null && item['variants'] is List) {
      for (var v in (item['variants'] as List)) {
        if (v is Map) {
          final cName = (v['color'] ?? v['variant_name'] ?? '').toString().trim();
          if (cName.isNotEmpty && cName.toLowerCase() != 'default' && !colors.contains(cName)) {
            colors.add(cName);
          }
        }
      }
    }

    final c = item['color']?.toString();
    if (c != null && c.trim().isNotEmpty && !colors.contains(c.trim())) {
      colors.add(c.trim());
    }

    return colors;
  }

  void _updatePriceForSelectedVariant(_LineItem li) {
    if (li.selectedItem == null || li.isCustom) return;

    final item = li.selectedItem!;
    double? foundPrice;

    if (item['variants'] != null && item['variants'] is List) {
      final List rawVars = item['variants'] as List;
      for (var v in rawVars) {
        if (v is Map) {
          final String colorName =
              (v['color'] ?? v['variant_name'] ?? v['name'] ?? '')
                  .toString()
                  .trim();
          final bool colorMatch = li.selectedColor == null ||
              li.selectedColor!.isEmpty ||
              colorName.toLowerCase() == li.selectedColor!.toLowerCase() ||
              colorName.isEmpty ||
              colorName.toLowerCase() == 'default';

          if (colorMatch && v['sizes'] is List) {
            final List sizesList = v['sizes'] as List;
            for (var sz in sizesList) {
              if (sz is Map) {
                final String szName = (sz['size'] ?? '').toString().trim();
                if (li.selectedSize == null ||
                    li.selectedSize!.isEmpty ||
                    szName.toLowerCase() == li.selectedSize!.toLowerCase()) {
                  final double ret = double.tryParse(
                          (sz['retailPrice'] ?? sz['retail_price'] ?? sz['pricePerPiece'] ?? sz['price'] ?? 0)
                              .toString()) ??
                      0.0;
                  final double cost = double.tryParse(
                          (sz['costPrice'] ?? sz['cost_price'] ?? 0)
                              .toString()) ??
                      0.0;

                  if (ret > 0) {
                    foundPrice = ret;
                    break;
                  } else if (cost > 0) {
                    foundPrice = cost * 2.0;
                    break;
                  }
                }
              }
            }
          }
          if (foundPrice != null) break;
        }
      }
    }

    if (foundPrice == null || foundPrice == 0.0) {
      final double mainRet = double.tryParse(
              (item['retailPrice'] ?? item['retail_price'] ?? 0).toString()) ??
          0.0;
      final double mainCost =
          double.tryParse((item['price'] ?? item['costPrice'] ?? 0).toString()) ??
              0.0;
      foundPrice = mainRet > 0 ? mainRet : (mainCost > 0 ? mainCost * 2.0 : 0.0);
    }

    li.pricePerPiece = foundPrice;
  }

  double get _subTotal => _lineItems.fold(0, (sum, li) => sum + li.totalPrice);

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;

  double get _sgst => _isInterState ? 0 : (_subTotal * _sgstPercent / 100);
  double get _cgst => _isInterState ? 0 : (_subTotal * _cgstPercent / 100);
  double get _igst => _isInterState ? (_subTotal * _igstPercent / 100) : 0;
  double get _totalTax => _sgst + _cgst + _igst;

  double get _grandTotal =>
      (_subTotal + _totalTax - _discount).clamp(0, double.infinity);

  void _addLineItem() {
    setState(() => _lineItems.add(_LineItem()));
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      final now = DateTime.now();
      final finalDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? now.hour,
        time?.minute ?? now.minute,
        now.second,
      );
      setState(() => _selectedDate = finalDate);
    }
  }

  Future<void> _saveSale() async {
    // Validation
    final validItems = _lineItems
        .where((li) {
          if (li.isCustom) {
            return li.customNameController.text.trim().isNotEmpty && li.pricePerPiece > 0;
          }
          return li.selectedItem != null;
        })
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter at least one valid item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final invoice = {
      'invoiceNumber': _invoiceNumber,
      'date': _selectedDate.toIso8601String(),
      'customerName': _customerNameCtrl.text.isEmpty
          ? 'Walk-in Customer'
          : _customerNameCtrl.text,
      'customerPhone': _customerPhoneCtrl.text,
      'items': validItems
          .map(
            (li) => {
              'itemId': li.isCustom
                  ? 'custom_${DateTime.now().millisecondsSinceEpoch}_${validItems.indexOf(li)}'
                  : li.selectedItem!['id'].toString(),
              'name': li.isCustom ? li.customNameController.text.trim() : li.selectedItem!['name'],
              'description': li.isCustom ? li.customDescController.text.trim() : '',
              'size': li.isCustom ? '' : (li.selectedSize ?? ''),
              'color': li.isCustom ? li.customDescController.text.trim() : (li.selectedColor ?? ''),
              'quantity': li.quantity,
              'costPrice': li.isCustom ? 0.0 : (double.tryParse(li.selectedItem!['price']?.toString() ?? '0') ?? 0.0),
              'pricePerPiece': li.pricePerPiece,
              'totalPrice': li.totalPrice,
            },
          )
          .toList(),
      'subTotal': _subTotal,
      'taxDetails': {
        'sgst': _sgst,
        'cgst': _cgst,
        'igst': _igst,
        'totalTax': _totalTax,
        'isInterState': _isInterState,
      },
      'discount': _discount,
      'grandTotal': _grandTotal,
      'branch': BranchService().currentBranch,
    };

    try {
      final createdSale = await _apiService.createInvoiceSale(
        invoice,
        branch: BranchService().currentBranch,
      );
      if (!mounted) return;

      final saleData =
          createdSale is Map<String, dynamic> ? createdSale : invoice;
      DataRepository().addLocalSale(
        saleData,
        branch: BranchService().currentBranch,
      );
      DataRepository().getSales(
        branch: BranchService().currentBranch,
        forceRefresh: true,
      );

      _showSuccessDialog(saleData);

      // Reset form
      setState(() {
        _invoiceNumber = _generateInvoiceNumber();
        _selectedDate = DateTime.now();
        _customerNameCtrl.clear();
        _customerPhoneCtrl.clear();
        _discountCtrl.text = '0';
        for (var li in _lineItems) {
          li.dispose();
        }
        _lineItems.clear();
        _lineItems.add(_LineItem());
        _isSaving = false;
      });
      _loadData(); // Refresh stock
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sale Successful!',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice ${invoice['invoiceNumber']} has been saved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        PdfService.generateAndPrintInvoice(invoice),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('PRINT'),
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
                        PdfService.generateAndShareInvoice(invoice),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('SHARE'),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              'https://img.icons8.com/3d-fluency/94/receipt-dollar.png',
              width: 24,
              height: 24,
              errorBuilder: (c, e, s) => const Icon(
                Icons.receipt_long,
                size: 24,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'DAILY SALES RECORD',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInvoiceHeader(),
                  const SizedBox(height: 24),
                  _buildLineItemsSection(),
                  const SizedBox(height: 16),
                  _buildAddItemButton(),
                  const SizedBox(height: 24),
                  _buildTotalsFooter(),
                ],
              ),
            ),
    );
  }

  // ─── INVOICE HEADER ───
  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVOICE DETAILS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.outline,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildReadOnlyField('Invoice #', _invoiceNumber),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDateField()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildReadOnlyField('Invoice #', _invoiceNumber),
                  const SizedBox(height: 16),
                  _buildDateField(),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Customer Name',
                        _customerNameCtrl,
                        hint: 'Walk-in Customer',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        'Phone Number',
                        _customerPhoneCtrl,
                        hint: 'Optional',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildTextField(
                    'Customer Name',
                    _customerNameCtrl,
                    hint: 'Walk-in Customer',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Phone Number',
                    _customerPhoneCtrl,
                    hint: 'Optional',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppTheme.outline,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    final bool isPhone = keyboardType == TextInputType.phone || label.toLowerCase().contains('phone');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isPhone ? TextInputType.number : keyboardType,
          maxLength: isPhone ? 10 : null,
          inputFormatters: isPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            counterText: isPhone ? '' : null,
            hintStyle: TextStyle(color: AppTheme.outline.withValues(alpha: 0.5)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: AppTheme.surfaceContainerLowest,
          ),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ─── LINE ITEMS ───
  Widget _buildLineItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'ITEMS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.outline,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...List.generate(
          _lineItems.length,
          (index) => _buildLineItemCard(index),
        ),
      ],
    );
  }

  Widget _buildLineItemCard(int index) {
    final li = _lineItems[index];
    final searchResults =
        li.showSuggestions && li.searchController.text.isNotEmpty
        ? _inventoryItems
              .where((item) {
                final name = (item['name'] ?? '').toString().toLowerCase();
                return name.contains(li.searchController.text.toLowerCase());
              })
              .take(5)
              .toList()
        : [];

    final sizes = li.selectedItem != null
        ? _getSizesForItem(li.selectedItem!)
        : <String>[];

    final colors = li.selectedItem != null
        ? _getColorsForItem(li.selectedItem!)
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: li.selectedItem != null
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Item ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_lineItems.length > 1)
                IconButton(
                  onPressed: () => _removeLineItem(index),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.errorContainer,
                    foregroundColor: AppTheme.error,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  'Search Inventory',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: !li.isCustom ? FontWeight.bold : FontWeight.normal,
                    color: !li.isCustom ? Colors.white : AppTheme.onSurface,
                  ),
                ),
                selected: !li.isCustom,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surfaceContainerLow,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      li.isCustom = false;
                      li.selectedItem = null;
                      li.pricePerPiece = 0;
                      li.quantity = 1;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Manual / Custom Item',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: li.isCustom ? FontWeight.bold : FontWeight.normal,
                    color: li.isCustom ? Colors.white : AppTheme.onSurface,
                  ),
                ),
                selected: li.isCustom,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surfaceContainerLow,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      li.isCustom = true;
                      li.selectedItem = null;
                      li.pricePerPiece = 0;
                      li.quantity = 1;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!li.isCustom) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item Name',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: li.searchController,
                  focusNode: li.searchFocus,
                  onChanged: (val) =>
                      setState(() => li.showSuggestions = val.isNotEmpty),
                  onTap: () => setState(
                    () =>
                        li.showSuggestions = li.searchController.text.isNotEmpty,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search item...',
                    hintStyle: TextStyle(
                      color: AppTheme.outline.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppTheme.outline,
                    ),
                    suffixIcon: li.selectedItem != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                li.selectedItem = null;
                                li.selectedSize = null;
                                li.selectedColor = null;
                                li.pricePerPiece = 0;
                                li.quantity = 1;
                                li.searchController.clear();
                                li.showSuggestions = false;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                    fillColor: AppTheme.surfaceContainerLowest,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
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
                      children: searchResults.map((item) {
                        final sizeStr = item['size']?.toString() ?? '';
                        final colorStr = item['color']?.toString() ?? '';
                        return ListTile(
                          dense: true,
                          title: Text(
                            item['name'] ?? '',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '₹${(() {
                              final double r = double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
                              final double c = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                              return (r > 0 ? r : (c > 0 ? c * 2.0 : 0)).toStringAsFixed(0);
                            })()} • Stock: ${item['stock']}'
                            '${sizeStr.isNotEmpty ? ' • Size: $sizeStr' : ''}'
                            '${colorStr.isNotEmpty ? ' • Colour: $colorStr' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.outline,
                            ),
                          ),
                          trailing: sizeStr.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sizeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                )
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () {
                            setState(() {
                              li.selectedItem = item;
                              li.searchController.text = item['name'] ?? '';
                              li.showSuggestions = false;
                              final itemSizes = _getSizesForItem(item);
                              li.selectedSize = itemSizes.isNotEmpty
                                  ? itemSizes.first
                                  : null;
                              final itemColors = _getColorsForItem(item);
                              li.selectedColor = itemColors.isNotEmpty
                                  ? itemColors.first
                                  : null;
                              li.quantity = 1;
                              _updatePriceForSelectedVariant(li);
                            });
                            li.searchFocus.unfocus();
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),

            if (li.selectedItem != null) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 450;
                  final children = [
                    if (sizes.isNotEmpty) _buildSizeSelector(li, sizes, isWide),
                    if (colors.isNotEmpty) _buildColorSelector(li, colors, isWide),
                    _buildQuantitySelector(li, isWide),
                    _buildInfoChip(
                      'Price/pc',
                      '₹${li.pricePerPiece.toStringAsFixed(0)}',
                      isWide,
                    ),
                    _buildInfoChip(
                      'Total',
                      '₹${li.totalPrice.toStringAsFixed(0)}',
                      isWide,
                      highlight: true,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: children
                          .map(
                            (w) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: w,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }
                  return Wrap(spacing: 12, runSpacing: 12, children: children);
                },
              ),
            ],
          ] else ...[
            _buildCustomItemForm(li),
          ],
        ],
      ),
    );
  }

  Widget _buildSizeSelector(_LineItem li, List<String> sizes, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Size',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: li.selectedSize,
              hint: Text(
                'Select',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.outline.withValues(alpha: 0.5),
                ),
              ),
              isExpanded: true,
              items: sizes
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  li.selectedSize = val;
                  _updatePriceForSelectedVariant(li);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector(_LineItem li, List<String> colors, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colour',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: li.selectedColor,
              hint: Text(
                'Select',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.outline.withValues(alpha: 0.5),
                ),
              ),
              isExpanded: true,
              items: colors
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  li.selectedColor = val;
                  _updatePriceForSelectedVariant(li);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(_LineItem li, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qty',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: li.quantity > 1
                    ? () => setState(() => li.quantity--)
                    : null,
                icon: const Icon(Icons.remove, size: 16),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  li.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final maxStock = li.selectedItem?['stock'] ?? 999;
                  if (li.quantity < maxStock) {
                    setState(() => li.quantity++);
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    String label,
    String value,
    bool isWide, {
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: isWide ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: highlight
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlight ? AppTheme.primary : AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // ─── ADD ITEM BUTTON ───
  Widget _buildAddItemButton() {
    return InkWell(
      onTap: _addLineItem,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Another Item',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOTALS + DISCOUNT FOOTER ───
  Widget _buildTotalsFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTotalRow(
            'Sub Total',
            '₹${_subTotal.toStringAsFixed(2)}',
            false,
          ),
          const SizedBox(height: 16),

          // Discount input
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                  ),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (!_isInterState) ...[
            _buildTotalRow(
              'SGST ($_sgstPercent%)',
              '₹${_sgst.toStringAsFixed(2)}',
              false,
            ),
            const SizedBox(height: 12),
            _buildTotalRow(
              'CGST ($_cgstPercent%)',
              '₹${_cgst.toStringAsFixed(2)}',
              false,
            ),
          ] else
            _buildTotalRow(
              'IGST ($_igstPercent%)',
              '₹${_igst.toStringAsFixed(2)}',
              false,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),

          _buildTotalRow(
            'Grand Total',
            '₹${_grandTotal.toStringAsFixed(2)}',
            true,
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Local GST',
                style: TextStyle(
                  fontSize: 10,
                  color: !_isInterState ? AppTheme.primary : AppTheme.outline,
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
                  color: _isInterState ? AppTheme.primary : AppTheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSale,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: AppTheme.surfaceContainerHigh,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SAVE SALE',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
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

  Widget _buildCustomItemForm(_LineItem li) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item Name *',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: li.customNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Alteration, Special Service',
                        hintStyle: TextStyle(fontSize: 12, color: AppTheme.outline.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLowest,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description (Optional)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: li.customDescController,
                      decoration: InputDecoration(
                        hintText: 'Details / description',
                        hintStyle: TextStyle(fontSize: 12, color: AppTheme.outline.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLowest,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price *',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: li.customPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          li.pricePerPiece = double.tryParse(val) ?? 0.0;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLowest,
                      ),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
                  ),
                  const SizedBox(height: 6),
                  _buildManualQuantitySelector(li),
                ],
              ),
              const SizedBox(width: 12),
              _buildManualInfoChip('Total', '₹${li.totalPrice.toStringAsFixed(0)}'),
            ],
          ),
        ] else ...[
          Text(
            'Item Name *',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: li.customNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Alteration, Custom Dress',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.outline.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'Description (Optional)',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: li.customDescController,
            decoration: InputDecoration(
              hintText: 'Details / description',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.outline.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.notes_outlined, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'Price *',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.outline),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: li.customPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (val) {
              setState(() {
                li.pricePerPiece = double.tryParse(val) ?? 0.0;
              });
            },
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '₹ ',
              prefixStyle: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
            ),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline),
                  ),
                  const SizedBox(height: 4),
                  _buildManualQuantitySelector(li),
                ],
              ),
              _buildManualInfoChip('Total', '₹${li.totalPrice.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManualQuantitySelector(_LineItem li) {
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
            onPressed: li.quantity > 1 ? () => setState(() => li.quantity--) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${li.quantity}',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => setState(() => li.quantity++),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInfoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
