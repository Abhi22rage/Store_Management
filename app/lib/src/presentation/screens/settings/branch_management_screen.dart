import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/branch_service.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
    } catch (_) {
      return date.toString().length >= 10 ? date.toString().substring(0, 10) : date.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await BranchService().refreshBranches();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddEditDialog([Map<String, dynamic>? branch]) {
    final nameController = TextEditingController(text: branch?['name'] ?? '');
    final locationController = TextEditingController(text: branch?['location'] ?? '');
    final phoneController = TextEditingController(text: branch?['contact_phone'] ?? '');
    final bool isEdit = branch != null;
    final bool isMainStore = branch?['name'] == 'Main Store';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isEdit ? 'Edit Branch' : 'Add Branch',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: !isEdit,
              decoration: InputDecoration(
                labelText: 'Branch Name',
                hintText: 'e.g. Downtown Outlet',
                prefixIcon: const Icon(Icons.store_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              enabled: !isMainStore,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Address / Location',
                hintText: isMainStore ? 'Managed in Store Details' : 'e.g. 123 Main St, City',
                prefixIcon: const Icon(Icons.location_on_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: isMainStore ? 'Main location is managed in Store Details settings.' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Contact Phone',
                hintText: 'e.g. 9876543210',
                counterText: '',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              final name = nameController.text.trim();
              final location = locationController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty) return;
              
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                if (isEdit) {
                  await _apiService.updateBranch(
                    branch['id'].toString(), 
                    name, 
                    location: isMainStore ? null : location,
                    contactPhone: phone,
                  );
                } else {
                  await _apiService.createBranch(name, location: location, contactPhone: phone);
                }
                await BranchService().refreshBranches();
              } catch (e) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                _showErrorDialog('Operation Failed', e.toString());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEdit ? 'UPDATE' : 'ADD'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    if (branch['name'] == 'Main Store') {
      _showErrorDialog('Action Restricted', 'The Main Store branch cannot be deleted.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text('Are you sure you want to delete ${branch['name']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _apiService.deleteBranch(branch['id'].toString());
        await BranchService().refreshBranches();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showErrorDialog('Delete Failed', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: AppTheme.error)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('The system encountered an error:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.error),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tip: Make sure you have run the latest SQL setup script in your Supabase Editor.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'BRANCH MANAGEMENT',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: BranchService(),
        builder: (context, _) {
          final branches = BranchService().branches;
          
          if (_isLoading && branches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (branches.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildBranchList(branches);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        child: const Icon(Icons.add_business_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 64, color: AppTheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No branches configured',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first location using the + button',
            style: GoogleFonts.inter(color: AppTheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchList(List<Map<String, dynamic>> branches) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: branches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final b = branches[index];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: AppTheme.primary),
            ),
            title: Text(
              b['name'] ?? 'Unnamed Branch',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b['location'] != null && b['location'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            b['location'],
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (b['contact_phone'] != null && b['contact_phone'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 12, color: AppTheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          b['contact_phone'],
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ),
                if (b['createdAt'] != null && b['createdAt'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 10, color: AppTheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          'Added on: ${_formatDate(b['createdAt'])}',
                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ),
                if (b['name'] == BranchService().currentBranch)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'CURRENTLY ACTIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.secondary),
                  onPressed: () => _showAddEditDialog(b),
                ),
                if (b['name'] != 'Main Store')
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                    onPressed: () => _deleteBranch(b),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
