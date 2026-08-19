import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_bloc.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_event.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_state.dart';
import 'package:image_picker/image_picker.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  String? _selectedSupplierId;
  String? _selectedBranch = 'Main Store';
  final List<Map<String, dynamic>> _items = [];
  
  double _discount = 0;
  String _paymentMethod = 'Cash';

  List<dynamic> _inventoryItems = [];
  bool _isLoadingInventory = true;
  XFile? _billFile;

  final TextEditingController _discountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    try {
      final items = await _apiService.getInventory();
      setState(() {
        _inventoryItems = items;
        _isLoadingInventory = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(), // Stable unique ID
        'itemId': null,
        'name': '',
        'quantity': 1,
        'costPrice': 0.0,
        'total': 0.0,
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _pickBillImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _billFile = image;
      });
    }
  }

  double get _subTotal => _items.fold(0, (sum, item) => sum + (item['total'] as double));
  double get _grandTotal => _subTotal - _discount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'NEW PURCHASE ORDER',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: BlocListener<PurchaseBloc, PurchaseState>(
        listener: (context, state) {
          if (state.status == PurchaseStatus.success && state.errorMessage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase order created successfully!')),
            );
            context.pop();
          } else if (state.status == PurchaseStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.errorMessage}')),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSupplierSection(),
                const SizedBox(height: 32),
                _buildOrderDetailsSection(),
                const SizedBox(height: 32),
                _buildItemsSection(),
                const SizedBox(height: 32),
                _buildSummarySection(),
                const SizedBox(height: 48),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierSection() {
    return BlocBuilder<PurchaseBloc, PurchaseState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPPLIER DETAILS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSupplierId,
                decoration: InputDecoration(
                  labelText: 'Select Supplier',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: state.suppliers.map<DropdownMenuItem<String>>((s) {
                  return DropdownMenuItem<String>(
                    value: s['id'],
                    child: Text(s['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSupplierId = val),
                validator: (val) => val == null ? 'Please select a supplier' : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER DETAILS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppTheme.secondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: const Icon(Icons.store),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Main Store', 'Warehouse', 'Branch A', 'Branch B'].map((b) {
                    return DropdownMenuItem(value: b, child: Text(b));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBranch = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: const Icon(Icons.payment),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Cash', 'UPI', 'Bank Transfer', 'Credit'].map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) => setState(() => _paymentMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickBillImage,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(_billFile == null ? 'Attach Physical Bill' : 'Bill Attached'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _billFile == null ? AppTheme.outlineVariant : AppTheme.primary,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_billFile != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.error),
                  onPressed: () => setState(() => _billFile = null),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER ITEMS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondary,
                  letterSpacing: 1.5,
                ),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('ADD ITEM'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingInventory)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No items added yet',
                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 32),
                  _PurchaseItemRow(
                    key: ValueKey(_items[i]['id']), // STABLE UNIQUE ID
                    item: _items[i],
                    inventoryItems: _inventoryItems,
                    onDelete: () => _removeItem(i),
                    onChanged: (updated) {
                      setState(() {
                         _items[i] = updated;
                      });
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', '₹${_subTotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount', style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant)),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    prefixText: '₹',
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _discount = double.tryParse(val) ?? 0),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildSummaryRow('Grand Total', '₹${_grandTotal.toStringAsFixed(2)}', isBold: true, color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 20 : 16,
            color: color ?? AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<PurchaseBloc, PurchaseState>(
      builder: (context, state) {
        final isLoading = state.status == PurchaseStatus.loading;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading || _items.isEmpty || _selectedSupplierId == null ? null : _submitOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('PLACE PURCHASE ORDER', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        );
      },
    );
  }

  void _submitOrder() {
    if (_formKey.currentState!.validate()) {
      final purchase = {
        'purchaseNumber': 'PO-${DateTime.now().millisecondsSinceEpoch}',
        'supplierId': _selectedSupplierId,
        'date': DateTime.now().toIso8601String(),
        'items': _items,
        'subTotal': _subTotal,
        'discount': _discount,
        'grandTotal': _grandTotal,
        'paymentMethod': _paymentMethod,
        'status': 'Received',
      };

      context.read<PurchaseBloc>().add(AddPurchaseOrder(
        purchase: purchase,
        branch: _selectedBranch,
        billFile: _billFile,
      ));
    }
  }
}

class _PurchaseItemRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<dynamic> inventoryItems;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onChanged;

  const _PurchaseItemRow({
    super.key,
    required this.item,
    required this.inventoryItems,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<_PurchaseItemRow> {
  late TextEditingController _qtyController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.item['quantity'].toString());
    _costController = TextEditingController(text: widget.item['costPrice'].toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _updateItem() {
    final updated = Map<String, dynamic>.from(widget.item);
    updated['quantity'] = int.tryParse(_qtyController.text) ?? 0;
    updated['costPrice'] = double.tryParse(_costController.text) ?? 0.0;
    updated['total'] = updated['quantity'] * updated['costPrice'];
    widget.onChanged(updated);
  }

  void _onProductChanged(String? itemId) {
    if (itemId == null) return;
    final invItem = widget.inventoryItems.firstWhere((e) => e['id'] == itemId);
    final price = (invItem['price'] as num).toDouble();
    
    setState(() {
      _costController.text = price.toString();
    });

    final updated = Map<String, dynamic>.from(widget.item);
    updated['itemId'] = itemId;
    updated['name'] = invItem['name'];
    updated['costPrice'] = price;
    updated['total'] = updated['quantity'] * price;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: widget.item['itemId'],
                decoration: InputDecoration(
                  labelText: 'Product',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.inventoryItems.map<DropdownMenuItem<String>>((item) {
                  return DropdownMenuItem<String>(
                    value: item['id'],
                    child: Text(item['name'], overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _onProductChanged,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _updateItem(),
                validator: (val) => (int.tryParse(val ?? '') ?? 0) <= 0 ? 'Min 1' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cost Price',
                  prefixText: '₹',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _updateItem(),
                validator: (val) => (double.tryParse(val ?? '') ?? 0.0) <= 0 ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                  Text(
                    '₹${widget.item['total'].toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
