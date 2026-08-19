import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/presentation/common/success_popup.dart';

class ManualStockUploadSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ManualStockUploadSheet({super.key, this.onSuccess});

  @override
  State<ManualStockUploadSheet> createState() => _ManualStockUploadSheetState();
}

class _ManualStockUploadSheetState extends State<ManualStockUploadSheet> {
  final _apiService = ApiService();

  List<dynamic> _inventoryItems = [];
  bool _isLoadingInventory = true;
  bool _isSubmitting = false;

  String _note = '';
  final List<Map<String, dynamic>> _uploadItems = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _addRow(); // Start with one empty row
  }

  Future<void> _loadInventory() async {
    try {
      final branch = BranchService().currentBranch;
      final items = await _apiService.getInventory(branch: branch);
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInventory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load inventory: $e')),
        );
      }
    }
  }

  void _addRow() {
    setState(() {
      _uploadItems.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'itemId': null,
        'name': '',
        'quantity': 1,
        'costPrice': null, // optional
      });
    });
  }

  void _removeRow(int index) {
    setState(() => _uploadItems.removeAt(index));
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _uploadItems.isNotEmpty &&
      _uploadItems.every((r) => r['itemId'] != null && (r['quantity'] as int) > 0);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    try {
      final branch = BranchService().currentBranch;
      await _apiService.uploadManualStock(
        _uploadItems,
        branch: branch,
        note: _note.trim().isEmpty ? null : _note.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SuccessPopup(message: 'Stock uploaded successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_rounded, color: AppTheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Stock Upload',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Manually add received stock to inventory',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Note field
            TextField(
              decoration: InputDecoration(
                labelText: 'Note / Memo (optional)',
                hintText: 'e.g. Cash purchase from local vendor',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.surfaceContainerLow,
              ),
              onChanged: (v) => _note = v,
            ),

            const SizedBox(height: 24),

            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ITEMS TO UPLOAD',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.secondary,
                    letterSpacing: 1.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD ROW'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_isLoadingInventory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_uploadItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Tap "ADD ROW" to start',
                    style: GoogleFonts.inter(color: AppTheme.outline),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _uploadItems.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    _StockUploadRow(
                      key: ValueKey(_uploadItems[i]['id']),
                      rowData: _uploadItems[i],
                      inventoryItems: _inventoryItems,
                      onDelete: _uploadItems.length > 1 ? () => _removeRow(i) : null,
                      onChanged: (updated) {
                        setState(() => _uploadItems[i] = updated);
                      },
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isSubmitting ? 'UPLOADING...' : 'UPLOAD TO INVENTORY',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Individual row widget ────────────────────────────────────────────────────

class _StockUploadRow extends StatefulWidget {
  final Map<String, dynamic> rowData;
  final List<dynamic> inventoryItems;
  final VoidCallback? onDelete;
  final Function(Map<String, dynamic>) onChanged;

  const _StockUploadRow({
    super.key,
    required this.rowData,
    required this.inventoryItems,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_StockUploadRow> createState() => _StockUploadRowState();
}

class _StockUploadRowState extends State<_StockUploadRow> {
  late TextEditingController _qtyController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.rowData['quantity'].toString());
    _costController = TextEditingController(
      text: widget.rowData['costPrice']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _notify() {
    final updated = Map<String, dynamic>.from(widget.rowData);
    updated['quantity'] = int.tryParse(_qtyController.text) ?? 1;
    final cost = double.tryParse(_costController.text);
    updated['costPrice'] = cost;
    widget.onChanged(updated);
  }

  void _onProductSelected(String? itemId) {
    if (itemId == null) return;
    final Map<String, dynamic> inv = widget.inventoryItems.firstWhere(
      (e) => e['id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    if (inv.isEmpty) return;

    // Pre-fill cost price with existing item price
    final price = (inv['price'] as num?)?.toDouble();
    if (price != null && price > 0) {
      _costController.text = price.toStringAsFixed(2);
    }

    final updated = Map<String, dynamic>.from(widget.rowData);
    updated['itemId'] = itemId;
    updated['name'] = inv['name'];
    updated['costPrice'] = price;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: widget.rowData['itemId'],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Product',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.inventoryItems.map<DropdownMenuItem<String>>((item) {
                  return DropdownMenuItem<String>(
                    value: item['id'],
                    child: Text(
                      item['name'],
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: _onProductSelected,
              ),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                onPressed: widget.onDelete,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Qty
            Expanded(
              child: TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty Received',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            // Cost price (optional)
            Expanded(
              child: TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cost Price (optional)',
                  prefixText: '₹',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _notify(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
