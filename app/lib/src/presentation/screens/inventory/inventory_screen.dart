import 'dart:convert';
import 'dart:io' as dart_io;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/core/services/export_service.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/utils/category_utils.dart';
import 'package:smart_store/src/core/utils/csv_helper.dart';
import 'package:smart_store/src/presentation/common/inventory_filter_bar.dart';
import 'package:smart_store/src/presentation/screens/inventory/widgets/inventory_item_form.dart';
import 'package:smart_store/src/presentation/screens/inventory/widgets/bulk_update_sheet.dart';
import 'package:smart_store/src/presentation/screens/inventory/widgets/bulk_add_sheet.dart';
import 'package:smart_store/src/core/models/item_variant_model.dart';

class InventoryScreen extends StatefulWidget {
  final bool showLowStockOnly;
  const InventoryScreen({super.key, this.showLowStockOnly = false});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  double _threshold = 10.0;

  // UI State
  bool _isListView = true;
  String _searchQuery = '';
  String _selectedCategory = 'All Collections';
  String _selectedSort = 'A to Z';
  late bool _showLowStockOnly;
  bool _lowStockAlertEnabled = true;
  final TextEditingController _searchController = TextEditingController();

  // Selection State
  // Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  List<InventoryDisplayRow> get _displayRows {
    if (_isLoading) {
      return List.generate(
        6,
        (index) => InventoryDisplayRow(
          item: {
            'id': 'skeleton_$index',
            'name': 'Loading Item Name Placeholder',
            'category': 'Category',
            'primeCategory': 'Prime Category',
            'stock': 100,
            'price': 100.0,
            'retailPrice': 200.0,
          },
          variant: null,
        ),
      );
    }

    final List<InventoryDisplayRow> list = [];
    for (var item in _filteredItems) {
      final rawVars = (item['variants'] as List?) ?? [];
      final bool hasVars = item['hasVariants'] == true || rawVars.isNotEmpty;

      if (hasVars && rawVars.isNotEmpty) {
        final variants = rawVars
            .map(
              (v) => ItemVariant.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList();
        for (var varObj in variants) {
          list.add(InventoryDisplayRow(item: item, variant: varObj));
        }
      } else {
        list.add(InventoryDisplayRow(item: item, variant: null));
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _showLowStockOnly = widget.showLowStockOnly;
    _loadSettings();
    _loadData();
    BranchService().addListener(_onBranchChanged);
    DataRepository().addListener(_onDataRepositoryChanged);
  }

  void _onBranchChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _onDataRepositoryChanged() {
    if (mounted) {
      _loadSettings();
      final cachedItems = DataRepository().getCachedInventory(BranchService().currentBranch);
      if (cachedItems != null && cachedItems.isNotEmpty) {
        setState(() {
          _allItems = List<dynamic>.from(cachedItems);
          _applyFilters();
        });
      }
    }
  }

  @override
  void dispose() {
    DataRepository().removeListener(_onDataRepositoryChanged);
    BranchService().removeListener(_onBranchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _threshold = prefs.getDouble('low_stock_threshold') ?? 10.0;
      _lowStockAlertEnabled = prefs.getBool('low_stock_alert_enabled') ?? true;
      _applyFilters();
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final currentBranch = BranchService().currentBranch;

    if (forceRefresh) {
      DataRepository().invalidateInventory(currentBranch);
    }

    final cachedItems = DataRepository().getCachedInventory(currentBranch);
    final cachedCats = DataRepository().getCachedCategories();

    if (!forceRefresh && cachedItems != null && cachedItems.isNotEmpty) {
      _allItems = List<dynamic>.from(cachedItems);
      _categories = cachedCats ?? [];
      _applyFilters();
      _isLoading = false;
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        DataRepository().getInventory(
          branch: currentBranch,
          forceRefresh: forceRefresh,
        ),
        DataRepository().getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _allItems = List<dynamic>.from(results[0]);
        _categories = results[1];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (_allItems.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load inventory: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
        final effectiveThreshold =
            double.tryParse(
              item['lowStockThreshold']?.toString() ??
                  item['minStockThreshold']?.toString() ??
                  '',
            ) ??
            _threshold;

        if (_showLowStockOnly) {
          if (!_lowStockAlertEnabled || stock > effectiveThreshold) return false;
        }

        final name = (item['name'] ?? '').toString().toLowerCase();
        final category = (item['category'] ?? 'Uncategorized').toString();
        final prime = (item['primeCategory'] ?? 'No Prime').toString();

        final matchesSearch = name.contains(_searchQuery.toLowerCase());

        if (_selectedCategory == 'All Collections') {
          return matchesSearch;
        }

        bool matchesCategory =
            (category == _selectedCategory || prime == _selectedCategory);

        // Recursive check if the item's category is a descendant of _selectedCategory
        if (!matchesCategory) {
          matchesCategory =
              CategoryUtils.isDescendant(
                _selectedCategory,
                category,
                _categories,
              ) ||
              CategoryUtils.isDescendant(_selectedCategory, prime, _categories);
        }

        return matchesSearch && matchesCategory;
      }).toList();

      if (_selectedSort == 'A to Z') {
        _filteredItems.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
      } else if (_selectedSort == 'Stock: Low to High') {
        _filteredItems.sort((a, b) {
          final sA = int.tryParse(a['stock']?.toString() ?? '0') ?? 0;
          final sB = int.tryParse(b['stock']?.toString() ?? '0') ?? 0;
          return sA.compareTo(sB);
        });
      } else if (_selectedSort == 'Stock: High to Low') {
        _filteredItems.sort((a, b) {
          final sA = int.tryParse(a['stock']?.toString() ?? '0') ?? 0;
          final sB = int.tryParse(b['stock']?.toString() ?? '0') ?? 0;
          return sB.compareTo(sA);
        });
      } else if (_selectedSort == 'Price: Low to High') {
        _filteredItems.sort((a, b) {
          final pA =
              double.tryParse(
                a['retailPrice']?.toString() ?? (a['price']?.toString() ?? '0'),
              ) ??
              0.0;
          final pB =
              double.tryParse(
                b['retailPrice']?.toString() ?? (b['price']?.toString() ?? '0'),
              ) ??
              0.0;
          return pA.compareTo(pB);
        });
      } else if (_selectedSort == 'Price: High to Low') {
        _filteredItems.sort((a, b) {
          final pA =
              double.tryParse(
                a['retailPrice']?.toString() ?? (a['price']?.toString() ?? '0'),
              ) ??
              0.0;
          final pB =
              double.tryParse(
                b['retailPrice']?.toString() ?? (b['price']?.toString() ?? '0'),
              ) ??
              0.0;
          return pB.compareTo(pA);
        });
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _showBulkUpdateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BulkUpdateSheet(
        selectedIds: _selectedIds.toList(),
        categories: _categories,
        onSave: () {
          _exitSelectionMode();
          _loadData(forceRefresh: true);
        },
      ),
    );
  }

  Future<void> _confirmBulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete ${_selectedIds.length} items permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.bulkDeleteInventoryItems(_selectedIds.toList());
        _exitSelectionMode();
        await _loadData(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Items deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedIds.length} Selected',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.edit_note_rounded,
            color: Colors.white,
            size: 28,
          ),
          onPressed: _showBulkUpdateSheet,
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: _confirmBulkDelete,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _showBulkAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BulkAddSheet(
        categories: _categories,
        onSave: () => _loadData(forceRefresh: true),
      ),
    );
  }

  Future<void> _exportData(String format) async {
    if (_filteredItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items to export')));
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
        final csvContent = ExportService.inventoryToCsv(_filteredItems);
        downloadCSV(content: csvContent, filename: 'inventory_$timestamp.csv');
      } else {
        final bytes = await ExportService.inventoryToXlsx(_filteredItems);
        final tempPath = (await getApplicationDocumentsDirectory()).path;
        final file = dart_io.File('$tempPath/inventory_$timestamp.xlsx');
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
            subject: 'Smart Store Inventory Export',
          ),
        );
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${_filteredItems.length} items'),
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

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen width for responsive grid
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 5;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : AppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    'https://img.icons8.com/3d-fluency/94/package.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'INVENTORY',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.refresh,
                    size: 24,
                    color: AppTheme.primary,
                  ),
                  onPressed: _loadData,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 24,
                    color: AppTheme.primary,
                  ),
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.primary,
                  ),
                  onSelected: (val) {
                    if (val == 'view') {
                      setState(() => _isListView = !_isListView);
                    }
                    if (val == 'categories') {
                      context.push('/inventory/categories');
                    }
                    if (val == 'export_csv') _exportData('csv');
                    if (val == 'export_xlsx') _exportData('xlsx');
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            _isListView
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(_isListView ? 'Grid View' : 'List View'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'categories',
                      child: Row(
                        children: [
                          Icon(Icons.category_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Categories'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
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
      body: Skeletonizer(
        enabled: _isLoading,
        containersColor: AppTheme.outline,
        effect: ShimmerEffect(
          baseColor: AppTheme.surfaceContainerHighest,
          highlightColor: AppTheme.surfaceContainer,
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Stock & Price Overview',
                          style: GoogleFonts.manrope(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/inventory/categories'),
                          icon: const Icon(Icons.category_outlined, size: 20),
                          label: Text(
                            'PRIME CATEGORIES',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Real-time stock tracking and pricing management.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSearchAndFilter(),
                    if (_showLowStockOnly) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Chip(
                            label: const Text('Low Stock Alerts Only'),
                            backgroundColor: AppTheme.errorContainer,
                            labelStyle: const TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.error,
                            ),
                            onDeleted: () {
                              setState(() {
                                _showLowStockOnly = false;
                                _applyFilters();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: _isListView
                  ? _buildSliverList()
                  : _buildSliverGrid(crossAxisCount),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              isExtended: true,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeOption(
                          icon: Icons.add_circle_outline,
                          title: 'Single Item',
                          desc: 'Add one item manually with full details',
                          onTap: () {
                            Navigator.pop(context);
                            _showAddDialog(context, 'Add New Inventory Item');
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModeOption(
                          icon: Icons.library_add_rounded,
                          title: 'Bulk / Batch Add',
                          desc: 'Add multiple items at once or import CSV',
                          onTap: () {
                            Navigator.pop(context);
                            _showBulkAddDialog();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add New Item'),
            ),
    );
  }

  Widget _buildSliverGrid(int crossAxisCount) {
    double aspectRatio = 0.65;
    if (crossAxisCount >= 4) aspectRatio = 0.72;

    final rows = _displayRows;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        if (!_isLoading && index == rows.length) return _buildAddPlaceholder();
        if (index >= rows.length) return const SizedBox.shrink();
        final displayRow = rows[index];
        final String itemId = displayRow.item['id']?.toString() ?? '';

        return VariantItemGridCard(
          key: ValueKey(
            'grid_${displayRow.item['id']}_${displayRow.variant?.id ?? index}',
          ),
          item: displayRow.item,
          variant: displayRow.variant,
          lowStockThreshold: _threshold,
          lowStockAlertEnabled: _lowStockAlertEnabled,
          isSelected: _selectedIds.contains(itemId),
          isSelectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(itemId);
            }
          },
          onLongPress: () => _enterSelectionMode(itemId),
          onEdit: () => _showItemForm(context: context, item: displayRow.item),
          onDelete: () => _showDeleteConfirmation(displayRow.item),
        );
      }, childCount: rows.length + (_isLoading ? 0 : 1)),
    );
  }

  Widget _buildSliverList() {
    final rows = _displayRows;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (!_isLoading && index == rows.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildAddPlaceholder(),
          );
        }
        if (index >= rows.length) return const SizedBox.shrink();
        final displayRow = rows[index];
        final String itemId = displayRow.item['id']?.toString() ?? '';

        return VariantItemRowCard(
          key: ValueKey(
            'list_${displayRow.item['id']}_${displayRow.variant?.id ?? index}',
          ),
          item: displayRow.item,
          variant: displayRow.variant,
          lowStockThreshold: _threshold,
          lowStockAlertEnabled: _lowStockAlertEnabled,
          isSelected: _selectedIds.contains(itemId),
          isSelectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(itemId);
            }
          },
          onLongPress: () => _enterSelectionMode(itemId),
          onEdit: () => _showItemForm(context: context, item: displayRow.item),
          onDelete: () => _showDeleteConfirmation(displayRow.item),
        );
      }, childCount: rows.length + (_isLoading ? 0 : 1)),
    );
  }

  void _showAddDialog(BuildContext context, String title) {
    _showItemForm(context: context);
  }

  Widget _buildSearchAndFilter() {
    return InventoryFilterBar(
      searchController: _searchController,
      searchQuery: _searchQuery,
      selectedCategory: _selectedCategory,
      selectedSort: _selectedSort,
      categories: _categories,
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applyFilters();
        });
      },
      onCategoryChanged: (value) {
        setState(() {
          _selectedCategory = value;
          _applyFilters();
        });
      },
      onSortChanged: (value) {
        setState(() {
          _selectedSort = value;
          _applyFilters();
        });
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'Are you sure you want to remove "${item['name']}" from inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _apiService.deleteInventoryItem(item['id']);
                if (!mounted) return;
                await _loadData(forceRefresh: true);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemForm({BuildContext? context, Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InventoryItemForm(
        item: item,
        categories: _categories,
        onSave: () => _loadData(forceRefresh: true),
      ),
    );
  }

  Widget _buildAddPlaceholder() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outline.withValues(alpha: 0.3),
          width: 2,
          style: BorderStyle.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showItemForm(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 24, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'New Item',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Register stock arrival',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryDisplayRow {
  final Map<String, dynamic> item;
  final ItemVariant? variant;

  InventoryDisplayRow({required this.item, this.variant});
}

void _showEnlargedImage(BuildContext context, Map<String, dynamic> item) {
  final image = item['image'] ?? item['image_url'];
  final String imgStr = image?.toString() ?? '';
  if (imgStr.isEmpty) return;

  final String itemName = item['name']?.toString() ?? 'Item Image';

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogCtx).size.height * 0.75,
                    maxWidth: MediaQuery.of(dialogCtx).size.width * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    minScale: 0.8,
                    child: imgStr.startsWith('data:image/')
                        ? Image.memory(
                            base64Decode(imgStr.split(',').last),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 48,
                              ),
                            ),
                          )
                        : Image.network(
                            imgStr,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class VariantItemRowCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final ItemVariant? variant;
  final double lowStockThreshold;
  final bool lowStockAlertEnabled;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VariantItemRowCard({
    super.key,
    required this.item,
    this.variant,
    this.lowStockThreshold = 10.0,
    this.lowStockAlertEnabled = true,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<VariantItemRowCard> createState() => _VariantItemRowCardState();
}

class _VariantItemRowCardState extends State<VariantItemRowCard> {
  late VariantSize? _selectedSize;

  @override
  void initState() {
    super.initState();
    if (widget.variant != null && widget.variant!.sizes.isNotEmpty) {
      _selectedSize = widget.variant!.sizes.first;
    } else {
      _selectedSize = null;
    }
  }

  @override
  void didUpdateWidget(covariant VariantItemRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.variant != oldWidget.variant) {
      if (widget.variant != null && widget.variant!.sizes.isNotEmpty) {
        _selectedSize = widget.variant!.sizes.first;
      } else {
        _selectedSize = null;
      }
    }
  }

  Widget _buildImageContainer(Map<String, dynamic> item) {
    final image = item['image'] ?? item['image_url'];
    final String imgStr = image?.toString() ?? '';
    return GestureDetector(
      onTap: imgStr.isNotEmpty ? () => _showEnlargedImage(context, item) : null,
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: imgStr.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imgStr.startsWith('data:image/')
                          ? Image.memory(
                              base64Decode(imgStr.split(',').last),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.checkroom_outlined,
                                      color: AppTheme.outline,
                                      size: 36,
                                    ),
                                  ),
                            )
                          : Image.network(
                              imgStr,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.checkroom_outlined,
                                      color: AppTheme.outline,
                                      size: 36,
                                    ),
                                  ),
                            ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.checkroom_outlined,
                        color: AppTheme.outline,
                        size: 36,
                      ),
                    ),
            ),
            if (imgStr.isNotEmpty)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.item['name'] ?? 'Unknown Item';
    final String category =
        widget.item['category']?.toString().isNotEmpty == true
        ? widget.item['category'].toString()
        : (widget.item['primeCategory']?.toString() ?? '');

    final color =
        widget.variant?.color ?? (widget.item['color']?.toString() ?? '');
    final sizes = widget.variant?.sizes ?? [];

    VariantSize? activeSize;
    if (widget.variant != null && sizes.isNotEmpty) {
      if (_selectedSize != null) {
        activeSize = sizes.where((s) => s.id == _selectedSize!.id || s.size == _selectedSize!.size).firstOrNull;
      }
      activeSize ??= sizes.first;
    } else {
      activeSize = null;
    }

    double cost = 0.0;
    double retail = 0.0;
    int stock = 0;
    String barcode = '';

    if (activeSize != null) {
      cost = activeSize.costPrice;
      retail = activeSize.retailPrice;
      stock = activeSize.stock;
      barcode = activeSize.barcode;
    } else {
      cost = double.tryParse(widget.item['price']?.toString() ?? '0') ?? 0.0;
      retail =
          double.tryParse(widget.item['retailPrice']?.toString() ?? '0') ?? 0.0;
      if (retail == 0 && cost > 0) {
        retail = cost * 2.0;
      }
      stock = (widget.item['stock'] as num?)?.toInt() ?? 0;
      barcode = widget.item['barcode']?.toString() ?? '';
    }

    String marginStr = '0%';
    if (retail > 0) {
      final double marginVal = ((retail - cost) / retail) * 100;
      marginStr = '${marginVal.toStringAsFixed(0)}%';
    }

    final double effectiveThreshold =
        double.tryParse(
          widget.item['lowStockThreshold']?.toString() ??
              widget.item['minStockThreshold']?.toString() ??
              '',
        ) ??
        widget.lowStockThreshold;

    final String statusLabel;
    final Color statusBgColor;

    if (stock <= 0) {
      statusLabel = 'OUT OF STOCK';
      statusBgColor = const Color.fromARGB(255, 204, 99, 99);
    } else if (widget.lowStockAlertEnabled && stock <= effectiveThreshold) {
      statusLabel = 'LOW STOCK';
      statusBgColor = const Color.fromARGB(255, 225, 201, 108);
    } else {
      statusLabel = 'IN STOCK';
      statusBgColor = const Color.fromARGB(255, 122, 206, 126);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.primary.withValues(alpha: 0.05)
              : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? AppTheme.primary
                : AppTheme.outlineVariant.withValues(alpha: 0.5),
            width: widget.isSelected ? 1.5 : 1,
          ),
          boxShadow: widget.isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.only(top: 36.0, right: 16.0),
                child: Icon(
                  widget.isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: widget.isSelected
                      ? AppTheme.primary
                      : AppTheme.outline,
                  size: 24,
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageContainer(widget.item),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        parentName,
                                        style: GoogleFonts.manrope(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      if (color.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'Variant: $color',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  AppTheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.outline,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Size dropdown & Cost Rate
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (sizes.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceContainerLow,
                                                borderRadius: BorderRadius.circular(
                                                  10,
                                                ),
                                                border: Border.all(
                                                  color: AppTheme.outlineVariant,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Size: ',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.outline,
                                                    ),
                                                  ),
                                                  DropdownButtonHideUnderline(
                                                    child: DropdownButton<String>(
                                                      value: activeSize?.id,
                                                      icon: const Icon(
                                                        Icons.arrow_drop_down,
                                                        color: AppTheme.primary,
                                                      ),
                                                      isDense: true,
                                                      items: sizes.map((sz) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: sz.id,
                                                          child: Text(
                                                            sz.size,
                                                            style:
                                                                GoogleFonts.inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 13,
                                                                  color: AppTheme
                                                                      .primary,
                                                                ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: (newId) {
                                                        if (newId != null) {
                                                          setState(() {
                                                            _selectedSize = sizes
                                                                .firstWhere(
                                                                  (s) =>
                                                                      s.id == newId,
                                                                  orElse: () =>
                                                                      sizes.first,
                                                                );
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (widget.item['size'] != null &&
                                              widget.item['size']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceContainerLow,
                                                borderRadius: BorderRadius.circular(
                                                  10,
                                                ),
                                                border: Border.all(
                                                  color: AppTheme.outlineVariant,
                                                ),
                                              ),
                                              child: Text(
                                                'Size: ${widget.item['size']}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'COST RATE',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.outline,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${cost.toStringAsFixed(2)}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Row 2: Margin & Barcode / SKU
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'MARGIN',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.outline,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                marginStr,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (barcode.isNotEmpty)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'BARCODE / SKU',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.outline,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  barcode,
                                                  style: GoogleFonts.jetBrainsMono(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.secondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppTheme.surfaceVariant,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'STOCK',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$stock units',
                                      style: GoogleFonts.manrope(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: stock > 0
                                            ? AppTheme.onSurface
                                            : AppTheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RETAIL PRICE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.outline,
                            ),
                          ),
                          Text(
                            '₹${retail.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.more_vert,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppTheme.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEdit();
                          } else if (value == 'delete') {
                            widget.onDelete();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VariantItemGridCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final ItemVariant? variant;
  final double lowStockThreshold;
  final bool lowStockAlertEnabled;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VariantItemGridCard({
    super.key,
    required this.item,
    this.variant,
    this.lowStockThreshold = 10.0,
    this.lowStockAlertEnabled = true,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<VariantItemGridCard> createState() => _VariantItemGridCardState();
}

class _VariantItemGridCardState extends State<VariantItemGridCard> {
  late VariantSize? _selectedSize;

  @override
  void initState() {
    super.initState();
    if (widget.variant != null && widget.variant!.sizes.isNotEmpty) {
      _selectedSize = widget.variant!.sizes.first;
    } else {
      _selectedSize = null;
    }
  }

  @override
  void didUpdateWidget(covariant VariantItemGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.variant != oldWidget.variant) {
      if (widget.variant != null && widget.variant!.sizes.isNotEmpty) {
        _selectedSize = widget.variant!.sizes.first;
      } else {
        _selectedSize = null;
      }
    }
  }

  Widget _buildGridBannerImage(Map<String, dynamic> item) {
    final image = item['image'] ?? item['image_url'];
    final String imgStr = image?.toString() ?? '';
    return GestureDetector(
      onTap: imgStr.isNotEmpty ? () => _showEnlargedImage(context, item) : null,
      child: Container(
        decoration: const BoxDecoration(color: AppTheme.surfaceContainerLow),
        child: Stack(
          children: [
            Positioned.fill(
              child: imgStr.isNotEmpty
                  ? ClipRRect(
                      child: imgStr.startsWith('data:image/')
                          ? Image.memory(
                              base64Decode(imgStr.split(',').last),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.checkroom_outlined,
                                      color: AppTheme.outline,
                                      size: 48,
                                    ),
                                  ),
                            )
                          : Image.network(
                              imgStr,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.checkroom_outlined,
                                      color: AppTheme.outline,
                                      size: 48,
                                    ),
                                  ),
                            ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.checkroom_outlined,
                        color: AppTheme.outline,
                        size: 48,
                      ),
                    ),
            ),
            if (imgStr.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.item['name'] ?? 'Unknown Item';
    final String category =
        widget.item['category']?.toString().isNotEmpty == true
        ? widget.item['category'].toString()
        : (widget.item['primeCategory']?.toString() ?? '');

    final color =
        widget.variant?.color ?? (widget.item['color']?.toString() ?? '');
    final sizes = widget.variant?.sizes ?? [];

    VariantSize? activeSize = _selectedSize;
    if (widget.variant != null && sizes.isNotEmpty) {
      if (activeSize != null && !sizes.any((s) => s.id == activeSize!.id)) {
        activeSize = sizes.where((s) => s.size == activeSize!.size).firstOrNull;
      }
      activeSize ??= sizes.first;
    } else {
      activeSize = null;
    }

    double cost = 0.0;
    double retail = 0.0;
    int stock = 0;
    String barcode = '';

    if (activeSize != null) {
      cost = activeSize.costPrice;
      retail = activeSize.retailPrice;
      stock = activeSize.stock;
      barcode = activeSize.barcode;
    } else {
      cost = double.tryParse(widget.item['price']?.toString() ?? '0') ?? 0.0;
      retail =
          double.tryParse(widget.item['retailPrice']?.toString() ?? '0') ?? 0.0;
      if (retail == 0 && cost > 0) {
        retail = cost * 2.0;
      }
      stock = (widget.item['stock'] as num?)?.toInt() ?? 0;
      barcode = widget.item['barcode']?.toString() ?? '';
    }

    final double effectiveThreshold =
        double.tryParse(
          widget.item['lowStockThreshold']?.toString() ??
              widget.item['minStockThreshold']?.toString() ??
              '',
        ) ??
        widget.lowStockThreshold;

    final String statusLabel;
    final Color statusBgColor;

    if (stock <= 0) {
      statusLabel = 'OUT OF STOCK';
      statusBgColor = AppTheme.errorContainer;
    } else if (widget.lowStockAlertEnabled && stock <= effectiveThreshold) {
      statusLabel = 'LOW STOCK';
      statusBgColor = AppTheme.tertiaryContainer;
    } else {
      statusLabel = 'IN STOCK';
      statusBgColor = const Color(0xFF2E7D32);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.primary.withValues(alpha: 0.05)
              : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? AppTheme.primary
                : AppTheme.outlineVariant.withValues(alpha: 0.5),
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildGridBannerImage(widget.item)),
                  if (widget.isSelectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: widget.isSelected
                              ? AppTheme.primary
                              : AppTheme.outline,
                          size: 24,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          parentName,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (color.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            color,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    Text(
                      category,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (sizes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeSize?.id,
                          isDense: true,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                          items: sizes.map((sz) {
                            return DropdownMenuItem<String>(
                              value: sz.id,
                              child: Text(
                                'Size: ${sz.size}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              setState(() {
                                _selectedSize = sizes.firstWhere(
                                  (s) => s.id == newId,
                                  orElse: () => sizes.first,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    )
                  else if (widget.item['size'] != null &&
                      widget.item['size'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: Text(
                        'Size: ${widget.item['size']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  if (barcode.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SKU: $barcode',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'C: ₹${cost.toStringAsFixed(0)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.outline,
                            ),
                          ),
                          Text(
                            'R: ₹${retail.toStringAsFixed(0)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'STOCK',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.outline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$stock',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: stock > 0
                                  ? AppTheme.onSurface
                                  : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: widget.onEdit,
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppTheme.outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
