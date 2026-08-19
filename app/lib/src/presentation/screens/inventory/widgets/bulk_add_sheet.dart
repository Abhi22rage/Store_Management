import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart' as csv;
import 'package:excel/excel.dart' as excel_pkg;

import 'dart:convert';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/presentation/common/success_popup.dart';
import 'package:smart_store/src/core/utils/csv_helper.dart';

class BulkAddSheet extends StatefulWidget {
  final List<dynamic> categories;
  final VoidCallback onSave;

  const BulkAddSheet({
    super.key,
    required this.categories,
    required this.onSave,
  });

  @override
  State<BulkAddSheet> createState() => _BulkAddSheetState();
}

class _BulkAddSheetState extends State<BulkAddSheet> {
  final _apiService = ApiService();
  final List<Map<String, dynamic>> _items = [];
  bool _isSaving = false;

  // Global Config State
  String _selectedBranch = 'Main Store';
  dynamic _selectedPrime;
  dynamic _selectedL2;
  String? _selectedL3;

  @override
  void initState() {
    super.initState();
    _selectedBranch = BranchService().currentBranch;

    // Add 5 empty rows by default
    for (int i = 0; i < 5; i++) {
      _items.add(_createEmptyItem());
    }
  }

  Map<String, dynamic> _createEmptyItem() {
    return {
      'name': '',
      'category': '',
      'primeCategory': '',
      'price': '',
      'retailPrice': '',
      'color': '',
      'size': '',
      'stock': '',
      'branch': _selectedBranch,
    };
  }

  /// Unwraps the typed CellValue from the excel package into a plain String.
  String _extractCellValue(excel_pkg.Data? cell) {
    if (cell == null) return '';
    final val = cell.value;
    if (val == null) return '';
    if (val is excel_pkg.TextCellValue) return val.value.toString();
    if (val is excel_pkg.IntCellValue) return val.value.toString();
    if (val is excel_pkg.DoubleCellValue) return val.value.toString();
    if (val is excel_pkg.BoolCellValue) return val.value.toString();
    if (val is excel_pkg.DateCellValue) return val.toString();
    if (val is excel_pkg.TimeCellValue) return val.toString();
    return '$val';
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        final extension = platformFile.extension?.toLowerCase();
        final bytes = await platformFile.readAsBytes();

        List<List<dynamic>> fields = [];

        if (extension == 'xlsx') {
          var excelFile = excel_pkg.Excel.decodeBytes(bytes);
          for (var table in excelFile.tables.keys) {
            final sheet = excelFile.tables[table];
            if (sheet == null) continue;
            for (var row in sheet.rows) {
              fields.add(
                row.map((cell) => _extractCellValue(cell)).toList(),
              );
            }
            break;
          }
        } else {
          final csvString = utf8.decode(bytes);
          fields = csv.Csv().decode(csvString);
        }

        if (fields.isEmpty) return;

        int startIdx = 0;
        final firstRow = fields[0];
        if (firstRow.isNotEmpty &&
            (firstRow[0].toString().toLowerCase().contains('name') ||
                firstRow[0].toString().toLowerCase().contains('product'))) {
          startIdx = 1;
        }

        final List<Map<String, dynamic>> importedItems = [];
        final List<String> errors = [];

        for (int i = startIdx; i < fields.length; i++) {
          final row = fields[i];
          if (row.isEmpty || (row.length == 1 && row[0].toString().isEmpty)) continue;

          final name = row.isNotEmpty ? row[0].toString().trim() : '';
          if (name.isEmpty && row.length < 2) continue;

          final priceStr = row.length > 1 ? row[1].toString().trim() : '';
          final retailStr = row.length > 2 ? row[2].toString().trim() : '';
          final stockStr = row.length > 3 ? row[3].toString().trim() : '';

          final price = double.tryParse(priceStr);
          final retail = double.tryParse(retailStr);
          final stock = int.tryParse(stockStr);

          final rowErrors = <String>[];
          if (name.isEmpty) rowErrors.add('Name is required');
          if (priceStr.isNotEmpty && price == null) rowErrors.add('Invalid cost price');
          if (retailStr.isNotEmpty && retail == null) rowErrors.add('Invalid retail price');
          if (stockStr.isNotEmpty && stock == null) rowErrors.add('Invalid stock');
          if (stock != null && stock < 0) rowErrors.add('Stock cannot be negative');

          final item = {
            'name': name,
            'price': priceStr,
            'retailPrice': retailStr,
            'stock': stockStr,
            'color': row.length > 4 ? row[4].toString().trim() : '',
            'size': row.length > 5 ? row[5].toString().trim() : '',
            'branch': _selectedBranch,
            'errors': rowErrors,
          };
          importedItems.add(item);

          if (rowErrors.isNotEmpty) {
            errors.add('Row ${i + 1 - startIdx}: ${rowErrors.join(", ")}');
          }
        }

        if (importedItems.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No valid items found in file')),
            );
          }
          return;
        }

        if (!mounted) return;
        _showImportPreview(importedItems, errors);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error parsing file: $e')));
      }
    }
  }

  void _showImportPreview(List<Map<String, dynamic>> importedItems, List<String> errors) {
    final hasErrors = errors.isNotEmpty;
    final validCount = importedItems.where((i) => (i['errors'] as List).isEmpty).length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasErrors ? AppTheme.accent.withValues(alpha: 0.1) : const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasErrors ? Icons.warning_amber_rounded : Icons.check_circle,
                        color: hasErrors ? AppTheme.accent : const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Preview',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            '$validCount valid / ${importedItems.length} total items',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (hasErrors)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text(
                            '${errors.length} validation error(s)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 80),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: errors.take(5).map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $e',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.error),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      if (errors.length > 5)
                        Text(
                          '...and ${errors.length - 5} more',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Sub')),
                        DataColumn(label: Text('Cost')),
                        DataColumn(label: Text('Retail')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: importedItems.take(20).toList().asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final hasItemErrors = (item['errors'] as List).isNotEmpty;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith((states) {
                            if (hasItemErrors) return AppTheme.errorContainer.withValues(alpha: 0.3);
                            return idx.isEven ? AppTheme.surfaceContainerLow : null;
                          }),
                          cells: [
                            DataCell(Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text(item['name'].toString(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500))),
                            DataCell(Text(item['primeCategory'].toString(), style: GoogleFonts.inter(fontSize: 10))),
                            DataCell(Text(item['category'].toString(), style: GoogleFonts.inter(fontSize: 10))),
                            DataCell(Text(item['price'].toString(), style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text(item['retailPrice'].toString(), style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text(item['stock'].toString(), style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(
                              hasItemErrors
                                  ? Icon(Icons.error_outline, size: 16, color: AppTheme.error)
                                  : Icon(Icons.check_circle, size: 16, color: const Color(0xFF16A34A)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (importedItems.length > 20)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Showing first 20 of ${importedItems.length} items',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _items.clear();
                            _items.addAll(importedItems.map((item) {
                              final copy = Map<String, dynamic>.from(item);
                              copy.remove('errors');
                              return copy;
                            }).where((item) => item['name'].toString().trim().isNotEmpty));
                            _applyBatchToAll(); // Apply current selection to imported items
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Import $validCount Valid Items',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  Future<void> _saveAll() async {
    String? finalCategory =
        _selectedL3 ??
        (_selectedL2 is Map ? _selectedL2['name'] : _selectedL2) ??
        (_selectedPrime is Map ? _selectedPrime['name'] : _selectedPrime);

    if (finalCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least a Prime Category'),
        ),
      );
      return;
    }

    final rawItems = _items
        .where((item) => item['name'].toString().trim().isNotEmpty)
        .toList();

    if (rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one item name')),
      );
      return;
    }

    final validItems = rawItems.map((item) {
      return {
        ...item,
        'branch': _selectedBranch,
        'category': finalCategory,
        'primeCategory': _selectedPrime != null ? _selectedPrime['name'] : '',
      };
    }).toList();

    setState(() => _isSaving = true);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Adding ${validItems.length} items...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we process your data',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      await _apiService.bulkCreateInventoryItems(validItems);
      
      if (mounted) {
        // 1. Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        
        // 2. Show Success Popup and handle post-save logic
        final navigator = Navigator.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => SuccessPopup(
            message: '${validItems.length} items added successfully!',
            onFinish: () {
              if (mounted) {
                navigator.pop(); // Close BulkAddSheet
                widget.onSave(); // Refresh InventoryScreen
              }
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog ONLY
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error adding items: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildBatchConfig(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return _buildAddRowButton();
                }
                return _buildItemRow(index);
              },
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.library_add_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Add Items',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      'Batch add multiple stock records',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                _buildHeaderActions(),
              ] else
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDownloadTemplateButton()),
                const SizedBox(width: 8),
                Expanded(child: _buildImportButton()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _downloadTemplate() {
    const content = 'Item Name,Cost Price,Retail Price,Stock,Color,Size\n';
    downloadCSV(content: content, filename: 'inventory_template.csv');
  }

  Widget _buildDownloadTemplateButton() {
    return TextButton.icon(
      onPressed: _downloadTemplate,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Download Template'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.07),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildImportButton() {
    return TextButton.icon(
      onPressed: _pickFile,
      icon: const Icon(Icons.file_upload_outlined, size: 18),
      label: const Text('Import CSV/XLSX'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.secondary,
        backgroundColor: AppTheme.secondary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDownloadTemplateButton(),
        const SizedBox(width: 8),
        _buildImportButton(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceContainerLow,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    // Use ObjectKey(item) to ensure the entire row rebuilds when the map object changes (e.g. after import)
    return Container(
      key: ObjectKey(item), 
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index Indicator
          Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Fields Column
          Expanded(
            child: Column(
              children: [
                // Top Row: Name, Size, color
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        'Item Name',
                        item['name'] ?? '',
                        (v) => item['name'] = v,
                        key: ValueKey('name_$index'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        'Size',
                        item['size'] ?? '',
                        (v) => item['size'] = v,
                        key: ValueKey('size_$index'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        'Color',
                        item['color'] ?? '',
                        (v) => item['color'] = v,
                        key: ValueKey('color_$index'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom Row: Cost, Retail, Stock
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        'Cost Price',
                        item['price'] ?? '',
                        (v) => item['price'] = v,
                        keyboardType: TextInputType.number,
                        key: ValueKey('price_$index'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        'Retail Price',
                        item['retailPrice'] ?? '',
                        (v) => item['retailPrice'] = v,
                        keyboardType: TextInputType.number,
                        key: ValueKey('retail_$index'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        'Stock',
                        item['stock'] ?? '',
                        (v) => item['stock'] = v,
                        keyboardType: TextInputType.number,
                        key: ValueKey('stock_$index'),
                      ),
                    ),
                  ],
                ),
                // Reflecting the Batch Category in each row for confirmation
                if (_selectedPrime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_important_outline, size: 14, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Category: ${_selectedPrime?['name']} > ${_selectedL3 ?? (_selectedL2 is Map ? _selectedL2['name'] : _selectedL2) ?? ''}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete Button
          Column(
            children: [
              const SizedBox(height: 4),
              IconButton(
                onPressed: () => setState(() => _items.removeAt(index)),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppTheme.error,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchConfig() {
    final List<String> branchNames = BranchService().branches
        .map((b) => b['name'].toString())
        .toList();

    // Category mapping logic based on filter bar patterns
    final List<String> primeNames = widget.categories
        .map((c) => c['name'].toString())
        .toList();
    final List<String> l2Names = _selectedPrime != null
        ? (_selectedPrime['subcategories'] as List<dynamic>)
              .map((e) => (e is Map ? e['name'] : e).toString())
              .toList()
        : [];
    final List<String> l3Names = _selectedL2 != null && _selectedL2 is Map
        ? (_selectedL2['subcategories'] as List<dynamic>)
              .map((e) => e.toString())
              .toList()
        : [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppTheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BATCH CONFIGURATION',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.outline,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.info_outline, size: 12, color: AppTheme.outline),
              const SizedBox(width: 4),
              Text(
                'Select category to enable bulk save',
                style: GoogleFonts.inter(fontSize: 9, color: AppTheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Branch Dropdown
          _buildDropdownContainer(
            label: 'TARGET BRANCH',
            value: _selectedBranch,
            icon: Icons.storefront_rounded,
            items: branchNames,
            onChanged: (val) => setState(() => _selectedBranch = val!),
          ),
          const SizedBox(height: 12),
          // Cascading Category Selectors
          Row(
            children: [
              Expanded(
                child: _buildDropdownContainer(
                  label: 'PRIME CATEGORY',
                  value: _selectedPrime?['name'],
                  hint: 'Select Category',
                  icon: Icons.category_rounded,
                  items: primeNames,
                  onChanged: (val) {
                    setState(() {
                      _selectedPrime = widget.categories.firstWhere(
                        (c) => c['name'] == val,
                      );
                      _selectedL2 = null;
                      _selectedL3 = null;
                      _applyBatchToAll();
                    });
                  },
                ),
              ),
              if (l2Names.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownContainer(
                    label: 'SUB CATEGORY (OPTIONAL)',
                    value: _selectedL2 is Map
                        ? _selectedL2['name']
                        : _selectedL2,
                    hint: 'Select L2',
                    icon: Icons.subdirectory_arrow_right_rounded,
                    items: ['-- Optional --', ...l2Names],
                    onChanged: (val) {
                      if (val == '-- Optional --') {
                        setState(() {
                          _selectedL2 = null;
                          _selectedL3 = null;
                          _applyBatchToAll();
                        });
                        return;
                      }
                      setState(() {
                        final dynamic subs = _selectedPrime['subcategories'];
                        _selectedL2 = subs.firstWhere(
                          (e) => (e is Map ? e['name'] : e) == val,
                        );
                        _selectedL3 = null;
                        _applyBatchToAll();
                      });
                    },
                  ),
                ),
              ],
              if (l3Names.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownContainer(
                    label: 'LEAF CATEGORY (OPTIONAL)',
                    value: _selectedL3,
                    hint: 'Select L3',
                    icon: Icons.list_rounded,
                    items: ['-- Optional --', ...l3Names],
                    onChanged: (val) {
                      if (val == '-- Optional --') {
                        setState(() {
                           _selectedL3 = null;
                           _applyBatchToAll();
                        });
                        return;
                      }
                      setState(() {
                        _selectedL3 = val;
                        _applyBatchToAll();
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _applyBatchToAll() {
    final String? prime = _selectedPrime?['name'];
    final String? sub = _selectedL3 ??
        (_selectedL2 is Map ? _selectedL2['name'] : _selectedL2) ??
        (_selectedPrime is Map ? _selectedPrime['name'] : _selectedPrime);

    if (prime == null) return;

    for (var item in _items) {
      item['primeCategory'] = prime;
      item['category'] = sub ?? '';
    }
  }

  Widget _buildDropdownContainer({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              hint: Text(hint ?? label, style: const TextStyle(fontSize: 13)),
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppTheme.primary,
              ),
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String initialValue,
    Function(String) onChanged, {
    TextInputType? keyboardType,
    Key? key,
  }) {
    return TextFormField(
      key: key,
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildAddRowButton() {
    return TextButton.icon(
      onPressed: () => setState(() => _items.add(_createEmptyItem())),
      icon: const Icon(Icons.add),
      label: const Text('Add Another Row'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildFooter() {
    final validCount = _items
        .where((i) => i['name'].toString().trim().isNotEmpty)
        .length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '$validCount items to add',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Add All Items',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
