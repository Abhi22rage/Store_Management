import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_bloc.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_event.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_state.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    // Ensure both suppliers and purchases are fetched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseBloc>().add(const FetchSuppliers());
      context.read<PurchaseBloc>().add(const FetchPurchases());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SUPPLIERS',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<PurchaseBloc>().add(const FetchSuppliers());
              context.read<PurchaseBloc>().add(const FetchPurchases());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<PurchaseBloc, PurchaseState>(
        builder: (context, state) {
          final allSuppliers = state.suppliers;
          final allPurchases = state.purchases;
          final query = _searchController.text.trim().toLowerCase();
          final suppliers = query.isEmpty
              ? allSuppliers
              : allSuppliers.where((s) {
                  final name = (s['name'] ?? '').toString().toLowerCase();
                  final phone = (s['phone'] ?? '').toString().toLowerCase();
                  final gstin = (s['gstin'] ?? '').toString().toLowerCase();
                  final address = (s['address'] ?? '').toString().toLowerCase();
                  final email = (s['email'] ?? '').toString().toLowerCase();
                  return name.contains(query) ||
                      phone.contains(query) ||
                      gstin.contains(query) ||
                      address.contains(query) ||
                      email.contains(query);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<PurchaseBloc>().add(const FetchSuppliers());
              context.read<PurchaseBloc>().add(const FetchPurchases());
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, allSuppliers.length),
                  const SizedBox(height: 20),
                  if (allSuppliers.isEmpty)
                    _buildEmptyState()
                  else if (suppliers.isEmpty)
                    _buildNoSearchResults()
                  else
                    _buildSupplierList(context, suppliers, allPurchases),
                  const SizedBox(height: 36),
                  _buildAnalysisSection(context, allSuppliers, allPurchases),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierFormDialog(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        icon: const Icon(Icons.person_add_alt_1, size: 20),
        label: Text('New Supplier', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppTheme.outline),
          const SizedBox(height: 12),
          Text(
            'No matching suppliers found',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching by name, address, GSTIN, or phone.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _searchController.clear(),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear Search'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.business_outlined, size: 56, color: AppTheme.outline),
          const SizedBox(height: 16),
          Text(
            'No suppliers yet',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Onboard your first vendor partner to start procurement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showSupplierFormDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Supplier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSupplierFormDialog(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailController = TextEditingController(text: existing?['email']?.toString() ?? '');
    final gstinController = TextEditingController(text: existing?['gstin']?.toString() ?? '');
    final addressController = TextEditingController(text: existing?['address']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEdit ? 'Edit Supplier' : 'Add New Supplier',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier / Business Name *',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address / Location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'City, Market, Street address...',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: gstinController,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN Number',
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'e.g. 07AAAAA0000A1Z5',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
            ),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final supplierData = {
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'gstin': gstinController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                };
                context.read<PurchaseBloc>().add(AddSupplier(supplier: supplierData));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Supplier "${nameController.text.trim()}" saved successfully.')),
                );
              }
            },
            child: Text(isEdit ? 'UPDATE' : 'SAVE SUPPLIER'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PARTNERS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.tertiary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount Vendors',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Vendor Directory',
              style: GoogleFonts.rubik(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        );

        final searchAndAdd = Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Address, GSTIN...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _showSupplierFormDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(isMobile ? 'ADD' : 'Add Supplier', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerText,
              const SizedBox(height: 14),
              searchAndAdd,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 24),
              SizedBox(width: 480, child: searchAndAdd),
            ],
          );
        }
      },
    );
  }

  Widget _buildSupplierList(BuildContext context, List<dynamic> suppliers, List<dynamic> allPurchases) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suppliers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = suppliers[index];
        return _buildCompactSupplierListItem(context, s, allPurchases);
      },
    );
  }

  Widget _buildCompactSupplierListItem(BuildContext context, dynamic s, List<dynamic> allPurchases) {
    final String id = s['id']?.toString() ?? '';
    final String name = s['name']?.toString() ?? 'Unnamed Supplier';
    final String address = (s['address'] != null && s['address'].toString().trim().isNotEmpty)
        ? s['address'].toString().trim()
        : '';
    final String gstin = (s['gstin'] != null && s['gstin'].toString().trim().isNotEmpty)
        ? s['gstin'].toString().trim()
        : 'N/A';
    final String balance = '₹ 0.00';

    // Find purchase orders associated with this supplier
    final supplierPurchases = allPurchases.where((p) {
      final pSuppId = p['supplierId']?.toString();
      final pSuppName = p['supplierName']?.toString().toLowerCase().trim();
      return (id.isNotEmpty && pSuppId == id) || (pSuppName != null && pSuppName == name.toLowerCase().trim());
    }).toList();

    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSupplierDetailsSheet(context, s, supplierPurchases),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              // Icon Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(
                    _getSupplierIcon(name),
                    size: 22,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name, Address, GSTIN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Name + Active chip
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onTertiaryFixed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Row 2: Address & GSTIN
                    Row(
                      children: [
                        if (address.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.outline),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              address,
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: AppTheme.outline, fontSize: 10)),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.badge_outlined, size: 13, color: AppTheme.outline),
                        const SizedBox(width: 3),
                        Text(
                          'GSTIN: $gstin',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BALANCE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.outline,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    balance,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupplierDetailsSheet(BuildContext context, dynamic s, List<dynamic> purchases) {
    final String name = s['name']?.toString() ?? 'Supplier';
    final String phone = s['phone']?.toString() ?? '';
    final String email = s['email']?.toString() ?? '';
    final String address = s['address']?.toString() ?? '';
    final String gstin = s['gstin']?.toString() ?? '';
    final double totalPurchasesAmount = purchases.fold<double>(
      0.0,
      (sum, p) => sum + (double.tryParse(p['grandTotal']?.toString() ?? '0') ?? 0.0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle & close
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getSupplierIcon(name), color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                              Text('Supplier Overview', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Top Quick Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile('Balance Due', '₹ 0.00', AppTheme.primary, Icons.account_balance_wallet_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile('Total Orders', '${purchases.length}', AppTheme.secondary, Icons.receipt_long_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              'Total Spend',
                              '₹${NumberFormat('#,###').format(totalPurchasesAmount)}',
                              AppTheme.primary,
                              Icons.payments_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Business & Contact Details Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Business & Contact Info', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _showSupplierFormDialog(context, existing: s);
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(Icons.location_on_outlined, 'Address', address.isNotEmpty ? address : 'No address provided'),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.badge_outlined, 'GSTIN', gstin.isNotEmpty ? gstin : 'Not registered', copyable: gstin.isNotEmpty),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.phone_outlined, 'Phone', phone.isNotEmpty ? phone : 'No phone provided', copyable: phone.isNotEmpty),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoRow(Icons.email_outlined, 'Email', email, copyable: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions Button Row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                context.push('/purchase/new');
                              },
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: const Text('New Purchase Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppTheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surfaceContainerHigh,
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.phone),
                              tooltip: 'Copy Phone Number',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: phone));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied $phone to clipboard')),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Purchase Orders & Bills Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Purchase Orders & Bills (${purchases.length})',
                            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (purchases.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 44, color: AppTheme.outline),
                              const SizedBox(height: 10),
                              Text('No purchase orders recorded yet', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Create your first purchase order to track inventory acquisition and bills.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: purchases.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final p = purchases[idx];
                            return _buildPurchaseOrderCard(context, p);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.outline),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurface, fontWeight: FontWeight.w600),
          ),
        ),
        if (copyable)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $value to clipboard')),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildPurchaseOrderCard(BuildContext context, dynamic p) {
    final String poNumber = p['purchaseNumber']?.toString() ?? 'PO-Unknown';
    final rawDate = p['date'] ?? p['createdAt'];
    final date = rawDate != null ? (DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now()) : DateTime.now();
    final String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final String grandTotal = '₹${NumberFormat('#,###.00').format(double.tryParse(p['grandTotal']?.toString() ?? '0') ?? 0.0)}';
    final String status = p['status']?.toString() ?? 'Received';
    final String paymentMethod = p['paymentMethod']?.toString() ?? 'Cash';
    final String billUrl = p['billUrl']?.toString() ?? '';
    final List<dynamic> items = p['items'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(poNumber, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusBg(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusText(status)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
              Text(grandTotal, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mode: $paymentMethod • ${items.length} items', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              if (billUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showBillPreviewDialog(context, billUrl, poNumber),
                  icon: const Icon(Icons.image_outlined, size: 14),
                  label: const Text('View Bill', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBillPreviewDialog(BuildContext context, String billUrl, String poNumber) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bill / Invoice ($poNumber)', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: billUrl,
                        placeholder: (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image, size: 48, color: AppTheme.outline),
                              const SizedBox(height: 8),
                              Text('Unable to load bill image', style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return AppTheme.tertiaryFixed;
      case 'in transit':
        return AppTheme.secondaryContainer;
      case 'pending':
        return AppTheme.surfaceContainerHigh;
      default:
        return AppTheme.surfaceContainerLow;
    }
  }

  Color _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return AppTheme.onTertiaryFixed;
      case 'in transit':
        return AppTheme.onSecondaryContainer;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  IconData _getSupplierIcon(String name) {
    if (name.contains('Textile')) return Icons.factory;
    if (name.contains('Hub')) return Icons.precision_manufacturing;
    if (name.contains('Ltd')) return Icons.style;
    return Icons.business;
  }

  Widget _buildAnalysisSection(BuildContext context, List<dynamic> suppliers, List<dynamic> purchases) {
    final double totalSpend = purchases.fold<double>(
      0.0,
      (sum, p) => sum + (double.tryParse(p['grandTotal']?.toString() ?? '0') ?? 0.0),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          Widget left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supply Chain Insight', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              Text('Visual breakdown of vendor activity and procurement performance.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              _buildInsightRow(AppTheme.primary, '${suppliers.length} Total Registered Vendors'),
              const SizedBox(height: 10),
              _buildInsightRow(AppTheme.secondary, '₹${NumberFormat('#,###').format(totalSpend)} Total Procurement Volume'),
            ],
          );

          Widget right = Row(
            children: [
              Expanded(child: _buildMetricCard('Vendors', suppliers.length.toString(), AppTheme.primary)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Orders', purchases.length.toString(), AppTheme.secondary)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Dues', '₹ 0', AppTheme.onSurfaceVariant)),
            ],
          );

          if (isMobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 20), right]);
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 1, child: left),
                const SizedBox(width: 32),
                Expanded(flex: 1, child: right),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildInsightRow(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }
}
