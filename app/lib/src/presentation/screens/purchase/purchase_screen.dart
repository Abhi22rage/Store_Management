import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_bloc.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_event.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_state.dart';
import 'manual_stock_upload_sheet.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'PURCHASES',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.primary),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<PurchaseBloc, PurchaseState>(
        builder: (context, state) {
          final isLoading = state.status == PurchaseStatus.loading && state.purchases.isEmpty;
          final displayPurchases = isLoading ? List.generate(3, (index) => {
            'id': index,
            'grandTotal': 1500.0,
            'status': 'Pending',
            'supplierName': 'Loading Supplier Ltd',
            'purchaseNumber': 'PO-LOAD-$index',
            'date': DateTime.now().toIso8601String(),
          }) : state.purchases;

          return Skeletonizer(
            enabled: isLoading,
            containersColor: AppTheme.outline,
            effect: ShimmerEffect(
              baseColor: AppTheme.surfaceContainerHighest,
              highlightColor: AppTheme.surfaceContainer,
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<PurchaseBloc>().add(const FetchPurchases());
                context.read<PurchaseBloc>().add(const FetchSuppliers());
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildActionArea(context),
                    const SizedBox(height: 32),
                    _buildSummaryStats(context, displayPurchases),
                    const SizedBox(height: 32),
                    _buildRecentOrders(context, displayPurchases),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/purchase/new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showManualUpload(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualStockUploadSheet(
        onSuccess: () {
          context.read<PurchaseBloc>().add(const FetchPurchases());
        },
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showVertically = constraints.maxWidth < 950;
        
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STOCK ACQUISITION',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppTheme.secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Collection Procurement',
              style: GoogleFonts.manrope(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        );

        final buttonsWidget = Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/purchase/new'),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Purchase Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showManualUpload(context),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Quick Stock Upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.secondary,
                side: const BorderSide(color: AppTheme.secondary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        );

        if (showVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 20),
              buttonsWidget,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 24),
              buttonsWidget,
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryStats(BuildContext context, List<dynamic> purchases) {
    final totalAmount = purchases.fold<double>(0, (sum, p) => sum + (p['grandTotal'] as num).toDouble());
    final pendingCount = purchases.where((p) => p['status'] == 'Pending' || p['status'] == 'In Transit').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        Widget card1 = _buildStatCard(
          'Total Purchases',
          '₹${NumberFormat('#,##,###.00').format(totalAmount)}',
          'Updated just now',
          Icons.payments,
          AppTheme.secondaryContainer,
          AppTheme.secondary,
        );
        Widget card2 = _buildStatCard(
          'Active Orders',
          pendingCount.toString().padLeft(2, '0'),
          'Awaiting delivery',
          Icons.local_shipping,
          AppTheme.primaryContainer,
          AppTheme.onPrimaryContainer,
        );

        if (isMobile) {
          return Column(children: [card1, const SizedBox(height: 16), card2]);
        } else {
          return Row(children: [Expanded(child: card1), const SizedBox(width: 16), Expanded(child: card2)]);
        }
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color iconBgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, List<dynamic> purchases) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Purchase History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (purchases.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.outline),
                const SizedBox(height: 16),
                Text('No purchase orders found', style: TextStyle(color: AppTheme.onSurfaceVariant)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: purchases.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = purchases[index];
                final rawDate = p['date'] ?? p['createdAt'];
                final date = rawDate != null ? (DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now()) : DateTime.now();
                return _buildOrderItem(
                  p['supplierName'],
                  DateFormat('dd MMM yyyy, hh:mm a').format(date),
                  '₹${NumberFormat('#,###.00').format(p['grandTotal'])}',
                  p['purchaseNumber'],
                  p['status'],
                  _getStatusColor(p['status']),
                  _getStatusTextColor(p['status']),
                  _getSupplierIcon(p['supplierName']),
                );
              },
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
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

  Color _getStatusTextColor(String status) {
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

  Widget _buildOrderItem(String name, String date, String amount, String poNumber, String status, Color statusBgColor, Color statusColor, IconData icon) {
    return Container(
      color: AppTheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          Widget left = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                    Text('Placed on $date', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          );

          Widget right = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                  Text(poNumber, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              )
            ],
          );

          if (isMobile) {
            return Column(
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: left),
                right,
              ],
            );
          }
        },
      ),
    );
  }
}
