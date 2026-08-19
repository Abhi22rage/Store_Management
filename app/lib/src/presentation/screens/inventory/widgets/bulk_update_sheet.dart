import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/presentation/common/success_popup.dart';

class BulkUpdateSheet extends StatefulWidget {
  final List<String> selectedIds;
  final List<dynamic> categories;
  final VoidCallback onSave;

  const BulkUpdateSheet({
    super.key,
    required this.selectedIds,
    required this.categories,
    required this.onSave,
  });

  @override
  State<BulkUpdateSheet> createState() => _BulkUpdateSheetState();
}

class _BulkUpdateSheetState extends State<BulkUpdateSheet> {
  final _apiService = ApiService();
  
  // Selection toggles
  bool _updatePrice = false;
  bool _updateRetailPrice = false;
  bool _updateCategory = false;
  final bool _updateBranch = false;
  bool _updateColor = false;
  bool _updateSize = false;

  // Controllers
  final _priceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  
  // Selection values
  String? _selectedPrime;
  String? _selectedCat2;
  String? _selectedCat3;

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildToggleField(
                    'Cost Price',
                    _updatePrice,
                    (v) => setState(() => _updatePrice = v),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('New Cost Price (₹)'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildToggleField(
                    'Color',
                    _updateColor,
                    (v) => setState(() => _updateColor = v),
                    TextField(
                      controller: _colorController,
                      decoration: _inputDecoration('New Color (e.g. Red, Blue, Green)'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildToggleField(
                    'Size',
                    _updateSize,
                    (v) => setState(() => _updateSize = v),
                    TextField(
                      controller: _sizeController,
                      decoration: _inputDecoration('New Size (e.g. S, M, L, XL)'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildToggleField(
                    'Retail Price',
                    _updateRetailPrice,
                    (v) => setState(() => _updateRetailPrice = v),
                    TextField(
                      controller: _retailPriceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('New Retail Price (₹)'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildToggleField(
                    'Category',
                    _updateCategory,
                    (v) => setState(() => _updateCategory = v),
                    _buildCategorySelectors(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bulk Update'.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.tertiary,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${widget.selectedIds.length} items selected',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceContainerLow,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleField(String title, bool isActive, Function(bool) onChanged, Widget field) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppTheme.surfaceContainerLow : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
                ),
              ),
              Switch.adaptive(
                value: isActive,
                onChanged: onChanged,
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            field,
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySelectors() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedPrime,
          decoration: _inputDecoration('Prime Category'),
          items: widget.categories.map((c) {
            return DropdownMenuItem<String>(
              value: c['name'].toString(),
              child: Text(c['name'].toString()),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedPrime = val;
              _selectedCat2 = null;
              _selectedCat3 = null;
            });
          },
        ),
        if (_selectedPrime != null) ...[
          const SizedBox(height: 12),
          _buildCat2Dropdown(),
        ],
        if (_selectedCat2 != null) ...[
          const SizedBox(height: 12),
          _buildCat3Dropdown(),
        ],
      ],
    );
  }

  Widget _buildCat2Dropdown() {
    final prime = widget.categories.firstWhere((c) => c['name'] == _selectedPrime, orElse: () => {});
    final List<dynamic> subs = prime['subcategories'] ?? [];
    if (subs.isEmpty) return const SizedBox();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCat2,
      decoration: _inputDecoration('Category'),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('-- All Categories --')),
        ...subs.map((s) {
          final name = s is Map ? s['name'].toString() : s.toString();
          return DropdownMenuItem<String>(value: name, child: Text(name));
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedCat2 = val;
          _selectedCat3 = null;
        });
      },
    );
  }

  Widget _buildCat3Dropdown() {
    final prime = widget.categories.firstWhere((c) => c['name'] == _selectedPrime, orElse: () => {});
    final List<dynamic> subsL2 = prime['subcategories'] ?? [];
    final l2Raw = subsL2.firstWhere(
      (s) => (s is Map ? s['name'].toString() : s.toString()) == _selectedCat2,
      orElse: () => null,
    );

    if (l2Raw == null || l2Raw is! Map || l2Raw['subcategories'] == null) return const SizedBox();
    final List<dynamic> subsL3 = l2Raw['subcategories'];

    return DropdownButtonFormField<String>(
      initialValue: _selectedCat3,
      decoration: _inputDecoration('Sub Category'),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('-- All Subcategories --')),
        ...subsL3.map((s) => DropdownMenuItem<String>(value: s.toString(), child: Text(s.toString()))),
      ],
      onChanged: (val) => setState(() => _selectedCat3 = val),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool hasActive = _updatePrice || _updateRetailPrice || _updateCategory || _updateBranch || _updateColor || _updateSize;

    return ElevatedButton(
      onPressed: (_isSaving || !hasActive) ? null : _handleBulkUpdate,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _isSaving
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
              'UPDATE ${widget.selectedIds.length} ITEMS',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
    );
  }

  Future<void> _handleBulkUpdate() async {
    final Map<String, dynamic> updateData = {};
    
    if (_updatePrice) {
      final val = double.tryParse(_priceController.text);
      if (val != null) updateData['price'] = val;
    }
    
    if (_updateRetailPrice) {
      final val = double.tryParse(_retailPriceController.text);
      if (val != null) updateData['retail_price'] = val;
    }
    
    if (_updateColor) {
      updateData['color'] = _colorController.text.trim();
    }
    
    if (_updateSize) {
      updateData['size'] = _sizeController.text.trim();
    }
    
    if (_updateCategory) {
      updateData['category'] = _selectedCat3 ?? _selectedCat2 ?? _selectedPrime ?? '';
      updateData['subcategory'] = _selectedCat3 ?? _selectedCat2 ?? '';
    }

    if (updateData.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _apiService.bulkUpdateInventoryItems(widget.selectedIds, updateData);
      if (!mounted) return;
      
      final navigator = Navigator.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessPopup(
          message: 'Successfully updated ${widget.selectedIds.length} items.',
          onFinish: () {
            if (mounted) {
              navigator.pop(); // Close BulkUpdateSheet
              widget.onSave(); // Refresh Inventory
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _retailPriceController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    super.dispose();
  }
}
