import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<PurchaseBloc, PurchaseState>(
        builder: (context, state) {
          final suppliers = state.suppliers;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<PurchaseBloc>().add(const FetchSuppliers());
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  if (suppliers.isEmpty)
                    _buildEmptyState()
                  else
                    _buildSupplierGrid(context, suppliers),
                  const SizedBox(height: 48),
                  _buildAnalysisSection(context, suppliers),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(64),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.business_outlined, size: 64, color: AppTheme.outline),
          const SizedBox(height: 24),
          Text(
            'No suppliers yet',
            style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Onboard your first vendor partner to start procurement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstinController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        title: Text('Add New Supplier', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Supplier Name', prefixIcon: Icon(Icons.business)),
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
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  counterText: '',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gstinController,
                decoration: const InputDecoration(labelText: 'GSTIN', prefixIcon: Icon(Icons.fingerprint)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<PurchaseBloc>().add(AddSupplier(
                  supplier: {
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'email': emailController.text,
                    'gstin': gstinController.text,
                  },
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE SUPPLIER'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PARTNERS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppTheme.tertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vendor Directory',
              style: GoogleFonts.rubik(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Manage your clothing collection supply chain and payment cycles.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        );

        final actions = Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search suppliers...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.person_add),
              label: isMobile ? const Text('ADD') : const Text('Add Supplier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerText,
              const SizedBox(height: 32),
              actions,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 48),
              SizedBox(width: 500, child: actions),
            ],
          );
        }
      },
    );
  }

  Widget _buildSupplierGrid(BuildContext context, List<dynamic> suppliers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.25,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: suppliers.length + 1,
          itemBuilder: (context, index) {
            if (index == suppliers.length) {
              return _buildAddSupplierCard();
            }
            final s = suppliers[index];
            return _buildSupplierCard(
              s['name'],
              s['phone'],
              s['gstin'],
              '₹ 0.00', // Mock balance for now
              AppTheme.primary,
              'Active',
              _getSupplierIcon(s['name']),
              isZero: true,
            );
          },
        );
      },
    );
  }

  IconData _getSupplierIcon(String name) {
    if (name.contains('Textile')) return Icons.factory;
    if (name.contains('Hub')) return Icons.precision_manufacturing;
    if (name.contains('Ltd')) return Icons.style;
    return Icons.business;
  }

  Widget _buildSupplierCard(String name, String phone, String gstin, String balance, Color borderColor, String status, IconData icon, {bool isZero = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: borderColor, size: 32),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: borderColor == AppTheme.error ? AppTheme.errorContainer : AppTheme.tertiaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: borderColor == AppTheme.error ? AppTheme.onErrorContainer : AppTheme.onTertiaryFixed,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.call, size: 14, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(phone, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GSTIN', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline, fontWeight: FontWeight.bold)),
              Text(gstin, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Outstanding Balance', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline, fontWeight: FontWeight.bold)),
              Text(balance, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: isZero ? AppTheme.onSurface : borderColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddSupplierCard() {
    return InkWell(
      onTap: () => _showAddDialog(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant, style: BorderStyle.solid, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppTheme.surfaceContainer, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppTheme.outline),
            ),
            const SizedBox(height: 16),
            Text('New Supplier', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Onboard a new vendor', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(BuildContext context, List<dynamic> suppliers) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          Widget left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supply Chain Insight', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 16),
              Text('Visual breakdown of vendor activity and procurement performance across your supplier ecosystem.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              _buildInsightRow(AppTheme.primary, '${suppliers.length} Total Registered Vendors'),
              const SizedBox(height: 16),
              _buildInsightRow(AppTheme.secondary, 'Active Procurement Cycle'),
            ],
          );

          Widget right = GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Reliability', 'High', AppTheme.primary),
              _buildMetricCard('Tier-1', suppliers.length.toString(), AppTheme.secondary),
              _buildMetricCard('Dues', '₹ 0', AppTheme.error),
              _buildMetricCard('Active', suppliers.length.toString(), AppTheme.onSurfaceVariant),
            ],
          );

          if (isMobile) {
            return Column(children: [left, const SizedBox(height: 32), right]);
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 1, child: left),
                const SizedBox(width: 48),
                Expanded(flex: 2, child: right),
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
        const SizedBox(width: 16),
        Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }
}
