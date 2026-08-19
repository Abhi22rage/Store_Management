import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/presentation/common/success_popup.dart';
import 'package:smart_store/src/presentation/common/image_cropper_dialog.dart';
import 'package:smart_store/src/core/models/item_variant_model.dart';
import 'package:smart_store/src/presentation/screens/inventory/widgets/variant_matrix_builder.dart';

class InventoryItemForm extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<dynamic> categories;
  final VoidCallback onSave;

  const InventoryItemForm({
    super.key,
    this.item,
    required this.categories,
    required this.onSave,
  });

  @override
  State<InventoryItemForm> createState() => _InventoryItemFormState();
}

class _InventoryItemFormState extends State<InventoryItemForm> {
  final _apiService = ApiService();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _colorController;
  late TextEditingController _priceController;
  late TextEditingController _retailPriceController;
  late TextEditingController _stockController;
  late TextEditingController _sizeController;
  late TextEditingController _barcodeController;
  late TextEditingController _lowStockThresholdController;

  List<dynamic> _categories = [];
  bool _isLoadingCategories = true;
  String? _selectedPrime;
  String? _selectedCat2;
  String? _selectedCat3;
  XFile? _selectedImageFile;
  bool _isSaving = false;
  bool _hasVariants = false;
  bool _isInitiallyVariantItem = false;
  List<ItemVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    _categories = widget.categories;
    _isLoadingCategories = widget.categories.isEmpty;

    final item = widget.item;
    final isEdit = item != null;

    _nameController = TextEditingController(text: isEdit ? item['name'] : '');
    _colorController = TextEditingController(
      text: isEdit ? (item['color'] ?? '') : '',
    );
    _priceController = TextEditingController(
      text: isEdit ? item['price'].toString() : '',
    );
    _retailPriceController = TextEditingController(
      text: isEdit ? (item['retailPrice']?.toString() ?? '') : '',
    );
    _stockController = TextEditingController(
      text: isEdit ? item['stock'].toString() : '',
    );
    _barcodeController = TextEditingController(
      text: isEdit ? (item['barcode']?.toString() ?? '') : '',
    );
    _lowStockThresholdController = TextEditingController(
      text: isEdit ? (item['lowStockThreshold']?.toString() ?? item['minStockThreshold']?.toString() ?? '') : '',
    );

    // Size logic
    String initialSize = '';
    if (isEdit && item['size'] != null && item['size'].toString().isNotEmpty) {
      initialSize = item['size']
          .toString()
          .replaceAll(RegExp(r'\s*Inches|\s*inches', caseSensitive: false), '')
          .trim();
    }
    _sizeController = TextEditingController(text: initialSize);

    if (isEdit) {
      _hasVariants =
          item['hasVariants'] == true ||
          (item['variants'] != null && (item['variants'] as List).isNotEmpty);
      _isInitiallyVariantItem = _hasVariants;
      if (item['variants'] != null && (item['variants'] as List).isNotEmpty) {
        _variants = (item['variants'] as List)
            .map(
              (v) => ItemVariant.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList();
      }
    }

    // Initial setup if categories are already loaded
    if (_categories.isNotEmpty) {
      _initCategorySelections();
    }

    // Always fetch latest to prevent stale category lists
    _loadCategories();
  }

  void _initCategorySelections() {
    final item = widget.item;
    final isEdit = item != null;

    if (isEdit) {
      final itemCat = item['category']?.toString() ?? '';
      _resolveCategoryPath(itemCat);
    } else {
      if (_selectedPrime == null && _categories.isNotEmpty) {
        _selectedPrime = _categories.first['name']?.toString();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoadingCategories = false;
          _initCategorySelections();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _initCategorySelections();
        });
      }
    }
  }

  void _resolveCategoryPath(String categoryName) {
    if (categoryName.isEmpty) return;
    for (var prime in _categories) {
      final primeName = prime['name'].toString();
      if (primeName.toLowerCase() == categoryName.toLowerCase()) {
        _selectedPrime = primeName;
        _selectedCat2 = null;
        _selectedCat3 = null;
        return;
      }

      final List<dynamic> cat2List = prime['subcategories'] ?? [];
      for (var cat2 in cat2List) {
        final cat2Name = cat2 is Map
            ? cat2['name'].toString()
            : cat2.toString();
        if (cat2Name.toLowerCase() == categoryName.toLowerCase()) {
          _selectedPrime = primeName;
          _selectedCat2 = cat2Name;
          _selectedCat3 = null;
          return;
        }

        if (cat2 is Map && cat2['subcategories'] != null) {
          final List<dynamic> cat3List = cat2['subcategories'];
          for (var cat3 in cat3List) {
            final cat3Name = cat3.toString();
            if (cat3Name.toLowerCase() == categoryName.toLowerCase()) {
              _selectedPrime = primeName;
              _selectedCat2 = cat2Name;
              _selectedCat3 = cat3Name;
              return;
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    _retailPriceController.dispose();
    _stockController.dispose();
    _sizeController.dispose();
    _barcodeController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      String finalCat = _selectedPrime ?? '';
      if (_selectedCat2 != null && _selectedCat2!.isNotEmpty) {
        finalCat = _selectedCat2!;
      }
      if (_selectedCat3 != null && _selectedCat3!.isNotEmpty) {
        finalCat = _selectedCat3!;
      }

      double finalPrice = double.tryParse(_priceController.text) ?? 0;
      double finalRetailPrice =
          double.tryParse(_retailPriceController.text) ?? 0;
      int finalStock = int.tryParse(_stockController.text) ?? 0;
      final double? customThreshold =
          double.tryParse(_lowStockThresholdController.text.trim());

      List<Map<String, dynamic>> variantsPayload = [];
      if (_hasVariants) {
        variantsPayload = _variants.map((v) => v.toJson()).toList();
        int totalMatStock = 0;
        double minCost = double.infinity;
        double minRetail = double.infinity;

        for (var v in _variants) {
          totalMatStock += v.totalStock;
          for (var sz in v.sizes) {
            if (sz.costPrice < minCost) minCost = sz.costPrice;
            if (sz.retailPrice < minRetail) minRetail = sz.retailPrice;
          }
        }

        if (totalMatStock > 0) finalStock = totalMatStock;
        if (minCost != double.infinity) finalPrice = minCost;
        if (minRetail != double.infinity) finalRetailPrice = minRetail;
      }

      String finalBarcode = _barcodeController.text.trim();
      if (finalBarcode.isEmpty && !_hasVariants) {
        final name = _nameController.text
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .toUpperCase();
        final color = _colorController.text
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .toUpperCase();
        final size = _sizeController.text
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .toUpperCase();
        finalBarcode =
            '${name.isNotEmpty ? name : "PRD"}${color.isNotEmpty ? "-$color" : ""}${size.isNotEmpty ? "-$size" : ""}';
      }

      final itemData = {
        'name': _nameController.text,
        'price': finalPrice,
        'retailPrice': finalRetailPrice,
        'stock': finalStock,
        'color': _colorController.text.trim(),
        'category': finalCat,
        'primeCategory': _selectedPrime,
        'size': _sizeController.text.trim(),
        'barcode': finalBarcode,
        'hasVariants': _hasVariants,
        'variants': variantsPayload,
        'lowStockThreshold': ?customThreshold,
      };

      final currentBranch = BranchService().currentBranch;

      if (finalBarcode.isNotEmpty) {
        await DataRepository().saveItemBarcode(
          widget.item?['id']?.toString(),
          _nameController.text,
          finalBarcode,
        );
        if (widget.item?['name'] != null && widget.item!['name'].toString().isNotEmpty) {
          await DataRepository().saveItemBarcode(
            widget.item?['id']?.toString(),
            widget.item!['name'].toString(),
            finalBarcode,
          );
        }
      }

      if (widget.item != null) {
        widget.item!['barcode'] = finalBarcode;
        await _apiService.updateInventoryItem(
          widget.item!['id'],
          <String, dynamic>{
            ...itemData,
            'branch': widget.item!['branch'] ?? currentBranch,
          },
          imageFile: _selectedImageFile,
        );
      } else {
        await _apiService.createInventoryItem(
          itemData,
          imageFile: _selectedImageFile,
          branch: currentBranch,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close modal
        widget.onSave();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SuccessPopup(
            message: widget.item != null
                ? 'Product updated successfully'
                : 'Product added successfully',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primeData = _categories.any((c) => c['name'] == _selectedPrime)
        ? _categories.firstWhere((c) => c['name'] == _selectedPrime)
        : null;
    final List<dynamic> cat2List = primeData != null
        ? (primeData['subcategories'] ?? [])
        : [];

    final cat2Data =
        _selectedCat2 != null &&
            _selectedCat2!.isNotEmpty &&
            cat2List.any(
              (c) => (c is Map ? c['name'] : c.toString()) == _selectedCat2,
            )
        ? cat2List.firstWhere(
            (c) => (c is Map ? c['name'] : c.toString()) == _selectedCat2,
          )
        : null;
    final List<dynamic> cat3List =
        (cat2Data is Map && cat2Data['subcategories'] != null)
        ? cat2Data['subcategories']
        : [];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        32,
        32,
        32,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  widget.item != null ? 'Update Item' : 'Add New Item',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Image Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: _buildImagePreview(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                prefixIcon: Icon(Icons.abc),
              ),
            ),
            const SizedBox(height: 16),

            // Variant Switch
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: SwitchListTile(
                title: Text(
                  'Enable Multi-Size & Variant Matrix',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _isInitiallyVariantItem
                      ? 'Variant matrix is enabled for this item and cannot be turned off.'
                      : 'Configure different variants & sizes with individual stocks, rates & barcodes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _isInitiallyVariantItem
                        ? AppTheme.outline
                        : AppTheme.onSurfaceVariant,
                  ),
                ),
                value: _hasVariants,
                onChanged: _isInitiallyVariantItem
                    ? null
                    : (val) {
                        setState(() {
                          _hasVariants = val;
                        });
                      },
              ),
            ),
            const SizedBox(height: 16),

            if (_hasVariants) ...[
              VariantMatrixBuilder(
                initialVariants: _variants,
                productName: _nameController.text,
                onChanged: (list) {
                  _variants = list;
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              TextField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Variant (Optional)',
                  hintText: 'e.g., White, Black, Red',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price (₹)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _retailPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Retail Price (₹)',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _sizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Size (Optional)',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode / SKU (Optional)',
                  hintText: 'e.g., TSHIRT-WH-20 or 890123456789',
                  prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Auto-generate Barcode',
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    onPressed: () {
                      final name = _nameController.text
                          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                          .toUpperCase();
                      final color = _colorController.text
                          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                          .toUpperCase();
                      final size = _sizeController.text
                          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                          .toUpperCase();
                      final String generated =
                          '${name.isNotEmpty ? name : "PRD"}-${color.isNotEmpty ? color : "DEF"}${size.isNotEmpty ? "-$size" : ""}';
                      _barcodeController.text = generated;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lowStockThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Alert Threshold (Optional)',
                  hintText: 'Leave empty to use store default',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isLoadingCategories) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              // Level 1: Prime Category
              DropdownButtonFormField<String>(
                initialValue: _selectedPrime,
                decoration: const InputDecoration(
                  labelText: 'Prime Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['name'].toString(),
                        child: Text(c['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedPrime = v;
                    _selectedCat2 = null;
                    _selectedCat3 = null;
                  });
                },
              ),

              // Level 2: Category
              if (cat2List.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCat2,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                  items: cat2List.map((c) {
                    final name = c is Map ? c['name'].toString() : c.toString();
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedCat2 = v;
                      _selectedCat3 = null;
                    });
                  },
                ),
              ],

              // Level 3: Sub-category
              if (cat3List.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCat3,
                  hint: const Text('Select Sub-category'),
                  decoration: const InputDecoration(
                    labelText: 'Sub-category',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                  items: cat3List
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.toString(),
                          child: Text(s.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCat3 = v),
                ),
              ],
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.item != null ? 'UPDATE PRODUCT' : 'ADD PRODUCT',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: _selectedImageFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: BoxFit.contain);
            }
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        ),
      );
    }
    if (widget.item != null &&
        widget.item!['image'] != null &&
        widget.item!['image'].toString().isNotEmpty) {
      final imgUrl = widget.item!['image'].toString();
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imgUrl.startsWith('data:image/')
            ? Image.memory(
                base64Decode(imgUrl.split(',').last),
                fit: BoxFit.contain,
              )
            : Image.network(
                imgUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  size: 32,
                  color: AppTheme.outline,
                ),
              ),
      );
    }
    return const Icon(
      Icons.add_a_photo_outlined,
      size: 32,
      color: AppTheme.outline,
    );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source != null) {
      try {
        final image = await _picker.pickImage(source: source);
        if (image != null && mounted) {
          final croppedFile = await ImageCropperDialog.cropImage(
            context,
            image,
          );
          if (croppedFile != null) {
            setState(() => _selectedImageFile = croppedFile);
          }
        }
      } catch (e) {
        debugPrint('[InventoryItemForm] Pick image error: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      }
    }
  }
}
