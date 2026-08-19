import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_store/src/core/models/item_variant_model.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class VariantMatrixBuilder extends StatefulWidget {
  final List<ItemVariant> initialVariants;
  final String productName;
  final ValueChanged<List<ItemVariant>> onChanged;

  const VariantMatrixBuilder({
    super.key,
    required this.initialVariants,
    required this.productName,
    required this.onChanged,
  });

  @override
  State<VariantMatrixBuilder> createState() => _VariantMatrixBuilderState();
}

class _VariantMatrixBuilderState extends State<VariantMatrixBuilder> {
  late List<ItemVariant> _variants;
  final TextEditingController _newColorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _variants = List.from(widget.initialVariants);
  }

  void _notifyParent() {
    widget.onChanged(_variants);
    setState(() {});
  }

  void _addVariantColor() {
    final color = _newColorController.text.trim();
    if (color.isEmpty) return;

    final newVar = ItemVariant(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      color: color,
      sizes: [],
    );
    _variants.add(newVar);
    _newColorController.clear();
    _notifyParent();
  }

  void _removeVariant(int index) {
    _variants.removeAt(index);
    _notifyParent();
  }

  // ─── SIZE GENERATION DIALOG ───────────────────────────────────────

  void _showSizeGeneratorDialog(ItemVariant variant) {
    int selectedMode = 0; // 0 = Numeric, 1 = Presets
    final startCtrl = TextEditingController(text: '20');
    final endCtrl = TextEditingController(text: '40');
    final stepCtrl = TextEditingController(text: '2');
    List<String> selectedPresets = ['S', 'M', 'L', 'XL'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Generate Size Matrix', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose Generation Mode:', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Numeric Range')),
                            selected: selectedMode == 0,
                            onSelected: (val) => setModalState(() => selectedMode = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Standard Presets')),
                            selected: selectedMode == 1,
                            onSelected: (val) => setModalState(() => selectedMode = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (selectedMode == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Start Size', hintText: '20'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'End Size', hintText: '40'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: stepCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Step', hintText: '2'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('e.g. 20, 22, 24, 26 ... 40', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    ] else ...[
                      Text('Select Presets:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ItemVariant.standardPresets().map((preset) {
                          final isSel = selectedPresets.contains(preset);
                          return FilterChip(
                            label: Text(preset),
                            selected: isSel,
                            onSelected: (sel) {
                              setModalState(() {
                                if (sel) {
                                  selectedPresets.add(preset);
                                } else {
                                  selectedPresets.remove(preset);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    List<String> generated = [];
                    if (selectedMode == 0) {
                      final start = int.tryParse(startCtrl.text) ?? 20;
                      final end = int.tryParse(endCtrl.text) ?? 40;
                      final step = int.tryParse(stepCtrl.text) ?? 2;
                      generated = ItemVariant.generateNumericSizes(start: start, end: end, step: step);
                    } else {
                      generated = List.from(selectedPresets);
                    }

                    if (generated.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid size range or no preset selected.')),
                      );
                      return;
                    }

                    // Add generated sizes without duplicating existing sizes
                    final existingSizes = variant.sizes.map((s) => s.size.toUpperCase()).toSet();
                    for (var szStr in generated) {
                      if (!existingSizes.contains(szStr.toUpperCase())) {
                        variant.sizes.add(VariantSize(
                          id: '${DateTime.now().microsecondsSinceEpoch}_$szStr',
                          size: szStr,
                          stock: 10,
                          costPrice: 0.0,
                          retailPrice: 0.0,
                        ));
                      }
                    }
                    variant.generateBarcodes(widget.productName);

                    Navigator.pop(ctx);
                    _notifyParent();
                  },
                  child: const Text('Generate Sizes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── RATE AUTOMATION DIALOG ───────────────────────────────────────

  void _showRateRuleDialog(ItemVariant variant) {
    if (variant.sizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate or add sizes first.')),
      );
      return;
    }

    final baseCostCtrl = TextEditingController(text: '200');
    final costStepCtrl = TextEditingController(text: '10');
    final baseRetailCtrl = TextEditingController(text: '350');
    final retailStepCtrl = TextEditingController(text: '15');

    String selectedFromSize = variant.sizes.first.size;
    String selectedToSize = variant.sizes.last.size;
    bool applyToAll = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Automated Pricing Rule',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set starting base rates, per-size tier increments, and target size range:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: baseCostCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base Cost (₹)',
                              prefixText: '₹',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: costStepCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '+ Step Cost',
                              prefixText: '₹',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: baseRetailCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base Retail (₹)',
                              prefixText: '₹',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: retailStepCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '+ Step Retail',
                              prefixText: '₹',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Target Size Range',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: applyToAll,
                                    activeColor: AppTheme.primary,
                                    onChanged: (val) {
                                      setModalState(() {
                                        applyToAll = val ?? true;
                                        if (applyToAll) {
                                          selectedFromSize =
                                              variant.sizes.first.size;
                                          selectedToSize =
                                              variant.sizes.last.size;
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    'All Sizes',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!applyToAll) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedFromSize,
                                    decoration: const InputDecoration(
                                      labelText: 'From Size',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: variant.sizes.map((sz) {
                                      return DropdownMenuItem<String>(
                                        value: sz.size,
                                        child: Text(sz.size),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedFromSize = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedToSize,
                                    decoration: const InputDecoration(
                                      labelText: 'To Size',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: variant.sizes.map((sz) {
                                      return DropdownMenuItem<String>(
                                        value: sz.size,
                                        child: Text(sz.size),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedToSize = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      applyToAll
                          ? 'Example: Size 1 = ₹350, Size 2 = ₹365 (+₹15)...'
                          : 'Rule applies from size "$selectedFromSize" up to size "$selectedToSize"',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final baseCost = double.tryParse(baseCostCtrl.text) ?? 0.0;
                    final costStep = double.tryParse(costStepCtrl.text) ?? 0.0;
                    final baseRetail =
                        double.tryParse(baseRetailCtrl.text) ?? 0.0;
                    final retailStep =
                        double.tryParse(retailStepCtrl.text) ?? 0.0;

                    variant.applyRateRule(
                      baseCost: baseCost,
                      costStep: costStep,
                      baseRetail: baseRetail,
                      retailStep: retailStep,
                      startSize: applyToAll ? null : selectedFromSize,
                      endSize: applyToAll ? null : selectedToSize,
                    );

                    Navigator.pop(ctx);
                    _notifyParent();
                  },
                  child: const Text('Apply Pricing Rule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_on_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Variant & Size Stock Matrix',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Configure sizes, stocks, custom rates, and barcodes per variant.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Add Variant Color input bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newColorController,
                  decoration: const InputDecoration(
                    hintText: 'Add Variant (e.g., White, Black, XL Red)',
                    prefixIcon: Icon(Icons.palette_outlined, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addVariantColor,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Color'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Variant Groups
          if (_variants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No variants added yet. Enter a color/variant name above and tap "Add Color".',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.outline,
                  ),
                ),
              ),
            ),
          ..._variants.asMap().entries.map((entry) {
            final idx = entry.key;
            final variant = entry.value;
            return _buildVariantCard(variant, idx);
          }),
        ],
      ),
    );
  }

  Widget _buildVariantCard(ItemVariant variant, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(), // remove divider
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                variant.color.trim().isEmpty ? 'Default' : variant.color,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${variant.sizes.length} Sizes | Total Stock: ${variant.totalStock}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
          onPressed: () => _removeVariant(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Action Bar
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showSizeGeneratorDialog(variant),
                      icon: const Icon(Icons.straighten, size: 16),
                      label: const Text('Generate Sizes'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showRateRuleDialog(variant),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Auto Price Rule'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          variant.generateBarcodes(widget.productName);
                        });
                        _notifyParent();
                      },
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Auto Barcodes'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Size Matrix Table
                if (variant.sizes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No sizes added yet. Click "Generate Sizes" to auto-create size matrix.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 8,
                      headingRowHeight: 36,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 52,
                      columns: const [
                        DataColumn(label: Text('Size')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Cost Rate (₹)')),
                        DataColumn(label: Text('Retail Rate (₹)')),
                        DataColumn(label: Text('Barcode / SKU')),
                        DataColumn(label: Text('')),
                      ],
                      rows: variant.sizes.asMap().entries.map((sizeEntry) {
                        final sIdx = sizeEntry.key;
                        final sizeObj = sizeEntry.value;
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  key: ValueKey('${sizeObj.id}_size'),
                                  initialValue: sizeObj.size,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  onChanged: (val) {
                                    sizeObj.size = val.trim();
                                    _notifyParent();
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  key: ValueKey('${sizeObj.id}_stock'),
                                  initialValue: sizeObj.stock.toString(),
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  onChanged: (val) {
                                    sizeObj.stock = int.tryParse(val) ?? 0;
                                    _notifyParent();
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: TextFormField(
                                  key: ValueKey('${sizeObj.id}_cost'),
                                  initialValue: sizeObj.costPrice.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  onChanged: (val) {
                                    sizeObj.costPrice = double.tryParse(val) ?? 0.0;
                                    _notifyParent();
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: TextFormField(
                                  key: ValueKey('${sizeObj.id}_retail'),
                                  initialValue: sizeObj.retailPrice.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  onChanged: (val) {
                                    sizeObj.retailPrice = double.tryParse(val) ?? 0.0;
                                    _notifyParent();
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 130,
                                child: TextFormField(
                                  key: ValueKey('${sizeObj.id}_barcode'),
                                  initialValue: sizeObj.barcode,
                                  style: GoogleFonts.inter(fontSize: 11),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  ),
                                  onChanged: (val) {
                                    sizeObj.barcode = val.trim();
                                    _notifyParent();
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 18),
                                onPressed: () {
                                  variant.sizes.removeAt(sIdx);
                                  _notifyParent();
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      variant.sizes.add(VariantSize(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        size: 'Custom',
                        stock: 5,
                        costPrice: 0.0,
                        retailPrice: 0.0,
                      ));
                      _notifyParent();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Single Size'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
