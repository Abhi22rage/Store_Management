import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_store/src/presentation/common/inventory_filter_bar.dart';
import 'package:smart_store/src/core/utils/category_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ItemPriceScreen extends StatefulWidget {
  const ItemPriceScreen({super.key});

  @override
  State<ItemPriceScreen> createState() => _ItemPriceScreenState();
}

class _ItemPriceScreenState extends State<ItemPriceScreen> {
  final ApiService _apiService = ApiService();
  double _lowStockThreshold = 10.0;
  bool _lowStockAlertEnabled = true;
  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;

  // Search/Filter State
  String _searchQuery = '';
  String _selectedCategory = 'All Collections';
  String _selectedSort = 'Default';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    BranchService().addListener(_onBranchChanged);
  }

  void _onBranchChanged() {
    if (mounted) _loadData();
  }

  @override
  void dispose() {
    BranchService().removeListener(_onBranchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentBranch = BranchService().currentBranch;
      final results = await Future.wait([
        _apiService.getInventory(branch: currentBranch),
        _apiService.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _lowStockThreshold = prefs.getDouble('low_stock_threshold') ?? 10.0;
        _lowStockAlertEnabled = prefs.getBool('low_stock_alert_enabled') ?? true;
        _allItems = results[0];
        _categories = results[1];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final category = (item['category'] ?? 'Uncategorized').toString();
        // primeCategory fallback if not enriched
        final prime = (item['primeCategory'] ?? 'No Prime').toString();

        final matchesSearch = name.contains(_searchQuery.toLowerCase());

        if (_selectedCategory == 'All Collections') {
          return matchesSearch;
        }

        bool matchesCategory = (category == _selectedCategory || prime == _selectedCategory);

        if (!matchesCategory) {
          matchesCategory = CategoryUtils.isDescendant(_selectedCategory, category, _categories) || 
                           CategoryUtils.isDescendant(_selectedCategory, prime, _categories);
        }

        return matchesSearch && matchesCategory;
      }).toList();

      // Apply Sorting
      if (_selectedSort == 'Stock: Low to High') {
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
          final pA = double.tryParse(a['retailPrice']?.toString() ?? (a['price']?.toString() ?? '0')) ?? 0.0;
          final pB = double.tryParse(b['retailPrice']?.toString() ?? (b['price']?.toString() ?? '0')) ?? 0.0;
          return pA.compareTo(pB);
        });
      } else if (_selectedSort == 'Price: High to Low') {
        _filteredItems.sort((a, b) {
          final pA = double.tryParse(a['retailPrice']?.toString() ?? (a['price']?.toString() ?? '0')) ?? 0.0;
          final pB = double.tryParse(b['retailPrice']?.toString() ?? (b['price']?.toString() ?? '0')) ?? 0.0;
          return pB.compareTo(pA);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: context.canPop() ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ) : null,
        title: Text(
          'ITEM PRICING',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _loadData,
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
        child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MARGINS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.secondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Price Strategy',
                    style: GoogleFonts.manrope(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Update and manage your seasonal collection margins and retail price points.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  InventoryFilterBar(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedSort: _selectedSort,
                    categories: _categories,
                    searchHint: 'Search by product name or SKU...',
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
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    ...List.generate(3, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPriceCard(
                          item: const {},
                          name: 'Loading Item Name',
                          sku: 'LOADSKU',
                          size: 'M',
                          cost: '₹100.00',
                          margin: '50%',
                          retailPrice: '₹200.00',
                          label: 'In Stock',
                          labelColor: AppTheme.tertiaryContainer,
                          onLabelColor: Colors.white,
                        ),
                      );
                    })
                  else if (_filteredItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'No items found matching your filters.',
                          style: GoogleFonts.inter(color: AppTheme.outline),
                        ),
                      ),
                    )
                  else
                    ..._filteredItems.map((item) {
                      String rawPrice = (item['price'] ?? '0').toString();
                      rawPrice = rawPrice.replaceAll(RegExp(r'[₹, ]'), '');
                      final double cost = double.tryParse(rawPrice) ?? 0;
                      
                      // Use persistent retailPrice if available, else default (e.g. 50% margin = cost * 2.0)
                      double retail = double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
                      if (retail == 0 && cost > 0) {
                        retail = cost * 2.0;
                      }

                      String marginStr = '0%';
                      if (retail > 0) {
                        final double marginVal = ((retail - cost) / retail) * 100;
                        marginStr = '${marginVal.toStringAsFixed(0)}%';
                      }

                      String sku = item['id']?.toString() ?? 'N/A';
                      if (sku.length > 8) {
                        try {
                          sku = sku.substring(0, 8);
                        } catch (e) {
                          // Ignore substring error
                        }
                      }
                      sku = sku.toUpperCase();

                      final int stockVal = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
                      final double thresholdVal = double.tryParse(
                        item['lowStockThreshold']?.toString() ?? item['minStockThreshold']?.toString() ?? '',
                      ) ?? _lowStockThreshold;
                      final bool isLow = _lowStockAlertEnabled && stockVal <= thresholdVal;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPriceCard(
                          item: item,
                          name: item['name'] ?? 'Unknown',
                          sku: sku,
                          size: item['size']?.toString(),
                          cost: '₹${cost.toStringAsFixed(2)}',
                          margin: marginStr,
                          retailPrice: '₹${retail.toStringAsFixed(2)}',
                          label: stockVal <= 0 ? 'Out of Stock' : (isLow ? 'Low Stock' : 'In Stock'),
                          labelColor: stockVal <= 0 ? AppTheme.errorContainer : (isLow ? AppTheme.errorContainer : AppTheme.tertiaryContainer),
                          onLabelColor: Colors.white,
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Could add global pricing rule logic
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditPriceDialog(Map<String, dynamic> item) {
    // Initial value for edit is the current retail price
    final double cost = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
    double currentRetail = double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0;
    if (currentRetail == 0 && cost > 0) currentRetail = cost * 2.0;

    final TextEditingController priceController = TextEditingController(
      text: currentRetail > 0 ? currentRetail.toStringAsFixed(2) : ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Retail Price',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['name'] ?? 'Product', 
                 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Retail Price (₹)',
                hintText: 'Enter new selling price',
                prefixText: '₹ ',
                filled: true,
                fillColor: AppTheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = priceController.text.trim();
              if (newPrice.isEmpty) return;
              
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isLoading = true);
              try {
                // Update only the retailPrice field while preserving others
                await _apiService.updateInventoryItem(item['id'].toString(), {
                  ...item,
                  'retailPrice': newPrice,
                });
                _loadData(); // Refresh list
              } catch (e) {
                setState(() => _isLoading = false);
                messenger.showSnackBar(
                  SnackBar(content: Text('Error updating price: $e')),
                );
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard({
    required Map<String, dynamic> item,
    required String name,
    required String sku,
    String? size,
    required String cost,
    required String margin,
    required String retailPrice,
    required String label,
    required Color labelColor,
    required Color onLabelColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          Widget content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 96,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sell_outlined,
                    color: AppTheme.outline, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(name,
                                style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: labelColor,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(label.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: onLabelColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('SKU: $sku',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppTheme.outline)),
                        if (size != null && size.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Size: $size',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COST',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.outline)),
                            Text(cost,
                                style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurface)),
                          ],
                        ),
                        Container(
                            width: 1,
                            height: 32,
                            color: AppTheme.surfaceVariant,
                            margin: const EdgeInsets.symmetric(horizontal: 16)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MARGIN',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.outline)),
                            Text(margin,
                                style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondary)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          Widget rightSide = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('RETAIL PRICE',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.outline)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(retailPrice,
                          style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: () => _showEditPriceDialog(item),
                icon: const Icon(Icons.edit),
                color: AppTheme.primary,
                style: IconButton.styleFrom(
                  shape: CircleBorder(
                      side: BorderSide(
                          color: AppTheme.outline.withValues(alpha: 0.5))),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              children: [
                content,
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                rightSide,
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(flex: 3, child: content),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: rightSide),
              ],
            );
          }
        },
      ),
    );
  }
}
