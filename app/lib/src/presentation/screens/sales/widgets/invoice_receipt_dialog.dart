import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_store/src/core/utils/invoice_pdf_helper.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class InvoiceReceiptDialog extends StatefulWidget {
  final Map<String, dynamic> saleData;
  final Map<String, dynamic>? storeDetails;
  final VoidCallback? onNewSale;
  final VoidCallback? onClose;

  const InvoiceReceiptDialog({
    super.key,
    required this.saleData,
    this.storeDetails,
    this.onNewSale,
    this.onClose,
  });

  @override
  State<InvoiceReceiptDialog> createState() => _InvoiceReceiptDialogState();
}

class _InvoiceReceiptDialogState extends State<InvoiceReceiptDialog> {
  bool _isThermal = false;
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.saleData;
    final store = widget.storeDetails;

    final storeName = store?['store_name'] ?? store?['storeName'] ?? 'Smart Store';
    final storeAddress = store?['store_address'] ?? store?['address'] ?? 'Main Road, City Center';
    final storePhone = store?['store_phone'] ?? store?['phone'] ?? '+91 9876543210';
    final storeGstin = store?['store_gstin'] ?? store?['gstin'] ?? '27AAAAA0000A1Z5';

    final invoiceNumber = (sale['invoiceNumber'] ?? sale['invoice_number'] ?? 'INV-000').toString();
    final rawDate = sale['date'] ?? sale['createdAt'];
    DateTime date = DateTime.now();
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    final customerName = (sale['customerName'] ?? sale['customer_name'] ?? 'Walk-in Customer').toString();
    final customerPhone = (sale['customerPhone'] ?? sale['customer_phone'] ?? '').toString();

    final paymentMethod = (sale['paymentMethod'] ?? sale['payment_method'] ?? 'UPI').toString();
    final paymentStatus = (sale['paymentStatus'] ?? sale['payment_status'] ?? 'PAID').toString();
    final txnRef = (sale['transactionRefId'] ??
            sale['gateway_txn_id'] ??
            sale['payment_details'] ??
            'UPI-VERIFIED')
        .toString();

    final items = (sale['items'] as List? ?? []);
    final subTotal = double.tryParse((sale['subTotal'] ?? sale['total_amount'] ?? 0).toString()) ?? 0.0;
    final discount = double.tryParse((sale['discount'] ?? 0).toString()) ?? 0.0;
    final grandTotal = double.tryParse((sale['grandTotal'] ?? sale['final_amount'] ?? 0).toString()) ?? 0.0;

    final taxDetails = sale['taxDetails'] is Map ? sale['taxDetails'] : null;
    final totalTax = double.tryParse((taxDetails?['totalTax'] ?? sale['tax_amount'] ?? 0).toString()) ?? 0.0;

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 500 ? 18.0 : 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header with Title and Close Cross Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Receipt',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            invoiceNumber,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppTheme.onSurfaceVariant,
                      tooltip: 'Close and go back',
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (widget.onClose != null) {
                          widget.onClose!();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Success Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5), // Emerald light
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF047857), // Emerald
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Verified Successfully',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                          Text(
                            'Transaction Ref: $txnRef',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        paymentStatus.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Store and Invoice Metadata
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          storeAddress,
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                        ),
                        Text(
                          'Phone: $storePhone | GSTIN: $storeGstin',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoiceNumber,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline),
                      ),
                      Text(
                        'Method: $paymentMethod',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Customer Info
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.outline),
                      const SizedBox(width: 6),
                      Text(
                        'Customer: $customerName',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  if (customerPhone.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          customerPhone,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Items Table Container
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('ITEM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 1.0))),
                          Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 1.0))),
                          Expanded(flex: 2, child: Text('UNIT', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 1.0))),
                          Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 1.0))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Table Rows
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final it = items[i];
                          final name = (it['name'] ?? it['item_name'] ?? 'Item').toString();
                          final size = (it['size'] ?? '').toString();
                          final qty = int.tryParse((it['quantity'] ?? 1).toString()) ?? 1;
                          final price = double.tryParse((it['pricePerPiece'] ?? it['unit_price'] ?? 0).toString()) ?? 0.0;
                          final total = double.tryParse((it['totalPrice'] ?? it['subtotal'] ?? (price * qty)).toString()) ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (size.isNotEmpty)
                                        Text(
                                          'Size: $size',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${price.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary Calculation Breakdown
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', '₹${subTotal.toStringAsFixed(2)}'),
                    if (discount > 0) ...[
                      const SizedBox(height: 6),
                      _buildSummaryRow('Discount', '-₹${discount.toStringAsFixed(2)}', isNegative: true),
                    ],
                    if (totalTax > 0) ...[
                      const SizedBox(height: 6),
                      _buildSummaryRow('Taxes (GST)', '+₹${totalTax.toStringAsFixed(2)}'),
                    ],
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FINAL AMOUNT PAID',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          '₹${grandTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Format Selector (A4 vs POS Thermal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INVOICE LAYOUT FORMAT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('A4 Standard'),
                          icon: Icon(Icons.description_outlined, size: 15),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('80mm Thermal'),
                          icon: Icon(Icons.receipt_long_outlined, size: 15),
                        ),
                      ],
                      selected: {_isThermal},
                      onSelectionChanged: (val) {
                        setState(() => _isThermal = val.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons: Print, Download, Share
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf
                          ? null
                          : () async {
                              setState(() => _isGeneratingPdf = true);
                              try {
                                await InvoicePdfHelper.printInvoice(
                                  context,
                                  sale,
                                  isThermal: _isThermal,
                                  storeDetails: store,
                                );
                              } finally {
                                if (mounted) setState(() => _isGeneratingPdf = false);
                              }
                            },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('PRINT'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingPdf
                          ? null
                          : () async {
                              setState(() => _isGeneratingPdf = true);
                              try {
                                await InvoicePdfHelper.downloadInvoice(
                                  context,
                                  sale,
                                  isThermal: _isThermal,
                                  storeDetails: store,
                                );
                              } finally {
                                if (mounted) setState(() => _isGeneratingPdf = false);
                              }
                            },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('DOWNLOAD'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingPdf
                          ? null
                          : () async {
                              setState(() => _isGeneratingPdf = true);
                              try {
                                await InvoicePdfHelper.shareInvoice(
                                  context,
                                  sale,
                                  isThermal: _isThermal,
                                  storeDetails: store,
                                );
                              } finally {
                                if (mounted) setState(() => _isGeneratingPdf = false);
                              }
                            },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('SHARE'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF047857),
                        side: const BorderSide(color: Color(0xFF047857)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Done / New Sale Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.onNewSale != null) {
                      widget.onNewSale!();
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(
                    'START NEW SALE',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primary,
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

  Widget _buildSummaryRow(String label, String value, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isNegative ? AppTheme.error : AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
