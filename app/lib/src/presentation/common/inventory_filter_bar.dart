import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class InventoryFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final String selectedSort;
  final List<dynamic> categories;
  final Function(String) onSearchChanged;
  final Function(String) onCategoryChanged;
  final Function(String) onSortChanged;
  final String searchHint;

  const InventoryFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedSort,
    required this.categories,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    this.searchHint = 'Search by item name...',
  });

  @override
  State<InventoryFilterBar> createState() => _InventoryFilterBarState();
}

class _InventoryFilterBarState extends State<InventoryFilterBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Identify active category levels
        dynamic activePrime;
        dynamic activeCatL2;
        dynamic activeCatL3;

        for (var p in widget.categories) {
          final String pName = p['name'].toString();
          if (pName == widget.selectedCategory) { activePrime = p; break; }
          final List<dynamic> subsL2 = p['subcategories'] ?? [];
          for (var c2 in subsL2) {
            final String c2Name = c2 is Map ? c2['name'] : c2.toString();
            if (c2Name == widget.selectedCategory) { activePrime = p; activeCatL2 = c2; break; }
            if (c2 is Map) {
              final List<dynamic> subsL3 = c2['subcategories'] ?? [];
              for (var c3 in subsL3) {
                if (c3.toString() == widget.selectedCategory) {
                  activePrime = p; activeCatL2 = c2; activeCatL3 = c3; break;
                }
              }
            }
            if (activeCatL2 != null) break;
          }
          if (activePrime != null) break;
        }

        final List<String> primeNames = widget.categories.map((c) => c['name'].toString()).toList();
        final List<String> l2Names = activePrime != null
            ? (activePrime['subcategories'] as List<dynamic>)
                .map((e) => (e is Map ? e['name'] : e).toString())
                .toList()
            : [];
        final List<String> l3Names = activeCatL2 != null && activeCatL2 is Map
            ? (activeCatL2['subcategories'] as List<dynamic>).map((e) => e.toString()).toList()
            : [];

        // Search bar + sort button in a row
        final searchRow = Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.searchController,
                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.searchController.clear();
                            widget.onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildSortDropdown(),
          ],
        );

        // Category filter chips (no sort here)
        final filterChips = Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip(
                  'All Collections',
                  widget.selectedCategory == 'All Collections',
                  widget.onCategoryChanged,
                ),
                if (primeNames.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildPrimeCategoriesDropdown(
                    primeNames,
                    activePrime != null,
                    activePrime?['name'],
                    widget.onCategoryChanged,
                  ),
                ],
                if (l2Names.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildSubCategoriesDropdown(
                    l2Names,
                    activeCatL2 != null || (activePrime != null && widget.selectedCategory == activePrime?['name']),
                    activeCatL2 != null ? (activeCatL2 is Map ? activeCatL2['name'] : activeCatL2.toString()) : 'Select Category',
                    widget.onCategoryChanged,
                    levelLabel: 'CATEGORY',
                  ),
                ],
                if (l3Names.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildSubCategoriesDropdown(
                    l3Names,
                    activeCatL3 != null || (activeCatL2 != null && widget.selectedCategory == (activeCatL2 is Map ? activeCatL2['name'] : activeCatL2.toString())),
                    activeCatL3 != null ? activeCatL3.toString() : 'Select Subcat',
                    widget.onCategoryChanged,
                    levelLabel: 'SUB CATEGORY',
                  ),
                ],
                const SizedBox(width: 16),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchRow,
            const SizedBox(height: 12),
            filterChips,
          ],
        );
      },
    );
  }

  Widget _buildSortDropdown() {
    final List<String> sortOptions = [
      'A to Z',
      'Stock: Low to High',
      'Stock: High to Low',
      'Price: Low to High',
      'Price: High to Low',
    ];

    bool isSorted = widget.selectedSort != 'A to Z';

    return PopupMenuButton<String>(
      onSelected: widget.onSortChanged,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => sortOptions
          .map((opt) => PopupMenuItem<String>(
                value: opt,
                child: Text(
                  opt,
                  style: GoogleFonts.inter(
                    fontWeight: widget.selectedSort == opt
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: widget.selectedSort == opt
                        ? AppTheme.primary
                        : AppTheme.onSurface,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSorted ? AppTheme.primary : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 18,
              color: isSorted ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              widget.selectedSort == 'A to Z' ? 'SORT' : widget.selectedSort,
              style: TextStyle(
                color: isSorted ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSorted ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Function(String) onSelected) {
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? AppTheme.primary : AppTheme.surfaceContainerHigh,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      onPressed: () => onSelected(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildPrimeCategoriesDropdown(
    List<String> primes,
    bool isAnySelected,
    String? activePrimeName,
    Function(String) onSelected,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (BuildContext context) {
        return primes.map((String cat) {
          final bool isCurrent = activePrimeName == cat;
          return PopupMenuItem<String>(
            value: cat,
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: isCurrent ? AppTheme.primary : AppTheme.outline,
                ),
                const SizedBox(width: 12),
                Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    color: isCurrent ? AppTheme.primary : AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAnySelected
              ? AppTheme.primary
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 18,
              color: isAnySelected
                  ? AppTheme.onPrimary
                  : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              isAnySelected
                  ? (activePrimeName ?? 'PRIME CATEGORIES')
                  : 'PRIME CATEGORIES',
              style: TextStyle(
                color: isAnySelected
                    ? AppTheme.onPrimary
                    : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isAnySelected
                  ? AppTheme.onPrimary
                  : AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoriesDropdown(
    List<String> subs,
    bool isSelected,
    String selection,
    Function(String) onSelected, {
    String levelLabel = 'SUB CATEGORY',
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (BuildContext context) {
        return subs.map((String sub) {
          final bool isCurrent = selection == sub;
          return PopupMenuItem<String>(
            value: sub,
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: isCurrent ? AppTheme.primary : AppTheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppTheme.primary : AppTheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondary
              : AppTheme.surfaceContainerHighest,
          border: isSelected
              ? null
              : Border.all(color: AppTheme.outlineVariant),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subdirectory_arrow_right_rounded,
              size: 18,
              color: isSelected
                  ? AppTheme.onSecondary
                  : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              isSelected ? selection : levelLabel,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.onSecondary
                    : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected
                  ? AppTheme.onSecondary
                  : AppTheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
