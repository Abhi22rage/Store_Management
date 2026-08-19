import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/presentation/common/success_popup.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoading = true);
      final cats = await _apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats.map((c) {
          if (c['subcategories'] == null) {
            c['subcategories'] = [];
          }
          return c;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Primary Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g., Kids, Sportswear'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('ADD')),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      try {
        await _apiService.createCategory({'name': name.trim()});
        _loadCategories();
        _showSuccess('Category added successfully');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editCategory(dynamic cat) async {
    final controller = TextEditingController(text: cat['name']);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('UPDATE')),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty && name != cat['name']) {
      try {
        await _apiService.updateCategory(cat['id'], {'name': name.trim()});
        _loadCategories();
        _showSuccess('Category updated successfully');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCategory(dynamic cat) async {
    try {
      final items = await _apiService.getInventory();
      final catName = cat['name'].toString();
      final subNames = List<String>.from(cat['subcategories'] ?? []);
      
      final matchingItems = items.where((item) {
        final itemCat = item['category'].toString();
        final primeCat = item['primeCategory']?.toString();
        return primeCat == catName || itemCat == catName || subNames.contains(itemCat);
      }).toList();

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category?'),
          content: matchingItems.isNotEmpty 
            ? RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(color: AppTheme.onSurface, fontSize: 14),
                  children: [
                    TextSpan(text: 'Are you sure you want to delete "$catName"?\n\n'),
                    TextSpan(
                      text: 'WARNING: This category contains ${matchingItems.length} items. Deleting it will permanently delete all these items as well.',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Text('Are you sure you want to delete "$catName"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        
        // Delete cascading items first
        for (var item in matchingItems) {
          await _apiService.deleteInventoryItem(item['id']);
        }

        await _apiService.deleteCategory(cat['id']);
        await _loadCategories();
        _showSuccess('Category and related items deleted successfully');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addSubcategory(dynamic cat, {dynamic parentCategory}) async {
    final controller = TextEditingController();
    final isAddSubSub = parentCategory != null;
    
    final subName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAddSubSub 
          ? 'Add Sub-category to ${parentCategory['name']}' 
          : 'Add Category to ${cat['name']}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isAddSubSub ? 'Sub-category Name' : 'Category Name', 
            hintText: isAddSubSub ? 'e.g., Slim Fit' : 'e.g., School Uniform'
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('ADD')),
        ],
      ),
    );

    if (subName != null && subName.trim().isNotEmpty) {
      final List<dynamic> currentSubs = List<dynamic>.from(cat['subcategories'] ?? []);
      final name = subName.trim();

      if (isAddSubSub) {
        // Find the parent item in the subcategories list
        final parentIndex = currentSubs.indexWhere((s) => 
          s is Map && s['name'] == parentCategory['name']);
        
        if (parentIndex != -1) {
            final Map<String, dynamic> parent = Map<String, dynamic>.from(currentSubs[parentIndex]);
            final List<dynamic> subSubs = List<dynamic>.from(parent['subcategories'] ?? []);
            if (!subSubs.contains(name)) {
                subSubs.add(name);
                parent['subcategories'] = subSubs;
                currentSubs[parentIndex] = parent;
            }
        }
      } else {
        // Add a new category object to the prime category
        if (!currentSubs.any((s) => (s is String ? s : s['name']) == name)) {
          currentSubs.add({
              'name': name,
              'subcategories': []
          });
        }
      }

      try {
        await _apiService.updateCategory(cat['id'], {
          ...cat,
          'subcategories': currentSubs,
        });
        _loadCategories();
        _showSuccess('Added successfully');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeSubcategory(dynamic cat, dynamic subItem, {dynamic parentCategory}) async {
    final subName = subItem is Map ? subItem['name'] : subItem.toString();
    
    try {
      final items = await _apiService.getInventory();
      // Check if any items belong to this leaf category
      final matchingItems = items.where((item) => item['category'].toString() == subName).toList();

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete $subName?'),
          content: matchingItems.isNotEmpty
            ? RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(color: AppTheme.onSurface, fontSize: 14),
                  children: [
                    TextSpan(text: 'Are you sure you want to delete "$subName"?\n\n'),
                    TextSpan(
                      text: 'WARNING: This contains ${matchingItems.length} items. Deleting it will permanently delete all these items.',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Text('Are you sure you want to delete "$subName"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);

        for (var item in matchingItems) {
          await _apiService.deleteInventoryItem(item['id']);
        }

        final List<dynamic> currentSubs = List<dynamic>.from(cat['subcategories'] ?? []);
        
        if (parentCategory != null) {
            // Remove from sub-sub-category
            final parentIndex = currentSubs.indexWhere((s) => s is Map && s['name'] == parentCategory['name']);
            if (parentIndex != -1) {
                final Map<String, dynamic> parent = Map<String, dynamic>.from(currentSubs[parentIndex]);
                final List<dynamic> subSubs = List<dynamic>.from(parent['subcategories'] ?? []);
                subSubs.remove(subName);
                parent['subcategories'] = subSubs;
                currentSubs[parentIndex] = parent;
            }
        } else {
            // Remove the category or sub-category from Prime
            currentSubs.removeWhere((s) => (s is Map ? s['name'] : s.toString()) == subName);
        }
        
        await _apiService.updateCategory(cat['id'], {
          ...cat,
          'subcategories': currentSubs,
        });
        
        await _loadCategories();
        _showSuccess('Deleted successfully');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editSubcategory(dynamic cat, dynamic subItem, {dynamic parentCategory}) async {
    final oldName = subItem is Map ? subItem['name'] : subItem.toString();
    final controller = TextEditingController(text: oldName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('UPDATE')),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName.trim() != oldName) {
      final name = newName.trim();
      final List<dynamic> currentSubs = List<dynamic>.from(cat['subcategories'] ?? []);
      
      if (parentCategory != null) {
        final parentIndex = currentSubs.indexWhere((s) => s is Map && s['name'] == parentCategory['name']);
        if (parentIndex != -1) {
            final Map<String, dynamic> parent = Map<String, dynamic>.from(currentSubs[parentIndex]);
            final List<dynamic> subSubs = List<dynamic>.from(parent['subcategories'] ?? []);
            final index = subSubs.indexOf(oldName);
            if (index != -1) {
                subSubs[index] = name;
                parent['subcategories'] = subSubs;
                currentSubs[parentIndex] = parent;
            }
        }
      } else {
        final index = currentSubs.indexWhere((s) => (s is Map ? s['name'] : s.toString()) == oldName);
        if (index != -1) {
            if (currentSubs[index] is Map) {
                currentSubs[index]['name'] = name;
            } else {
                currentSubs[index] = name;
            }
        }
      }

      try {
        await _apiService.updateCategory(cat['id'], {
          ...cat,
          'subcategories': currentSubs,
        });
        _loadCategories();
        _showSuccess('Updated successfully');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessPopup(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Category Hierarchy', style: GoogleFonts.rubik(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCategories),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final List<dynamic> subcategories = cat['subcategories'] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: AppTheme.surfaceContainerLowest,
                        boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.folder_outlined, color: AppTheme.primary),
                          ),
                          title: Text(cat['name'], style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('Level 1: Prime Category', style: TextStyle(fontSize: 10, color: AppTheme.outline)),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) {
                              if (val == 'add') _addSubcategory(cat);
                              if (val == 'edit') _editCategory(cat);
                              if (val == 'delete') _deleteCategory(cat);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'add', child: Row(children: [Icon(Icons.add, size: 20), SizedBox(width: 8), Text('Add Category')])),
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit Prime')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                            ],
                          ),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.add, size: 18, color: AppTheme.primary),
                              title: const Text('Add level 2 category', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              onTap: () => _addSubcategory(cat),
                            ),
                            const Divider(height: 1),
                            ...subcategories.map((sub) {
                              final name = sub is Map ? sub['name'] : sub.toString();
                              final List<dynamic> children = (sub is Map && sub['subcategories'] != null) 
                                ? sub['subcategories'] : [];

                              return ExpansionTile(
                                leading: const SizedBox(width: 40, child: Icon(Icons.subdirectory_arrow_right, size: 16)),
                                title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text('Level 2: Category', style: TextStyle(fontSize: 10, color: AppTheme.outline)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => _addSubcategory(cat, parentCategory: sub)),
                                        IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _editSubcategory(cat, sub)),
                                        IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error), onPressed: () => _removeSubcategory(cat, sub)),
                                    ],
                                ),
                                children: [
                                    if (children.isEmpty)
                                        const Padding(padding: EdgeInsets.all(8.0), child: Text('No sub-categories', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                                    ...children.map((child) => ListTile(
                                        contentPadding: const EdgeInsets.only(left: 60, right: 20),
                                        title: Text(child.toString(), style: const TextStyle(fontSize: 13)),
                                        subtitle: Text('Level 3: Sub-category', style: TextStyle(fontSize: 9, color: AppTheme.outline)),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                IconButton(icon: const Icon(Icons.edit_outlined, size: 14), onPressed: () => _editSubcategory(cat, child, parentCategory: sub)),
                                                IconButton(icon: const Icon(Icons.remove_circle_outline, size: 14, color: AppTheme.error), onPressed: () => _removeSubcategory(cat, child, parentCategory: sub)),
                                            ],
                                        ),
                                    )),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        label: const Text('ADD PRIME CATEGORY'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
      ),
    );
  }
}

