import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_store/src/core/services/upi_payment_service.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class UpiPaymentDialog extends StatefulWidget {
  final String invoiceNumber;
  final double payableAmount;
  final String storeName;
  final String merchantUpiId;
  final bool isSandbox;

  const UpiPaymentDialog({
    super.key,
    required this.invoiceNumber,
    required this.payableAmount,
    required this.storeName,
    required this.merchantUpiId,
    this.isSandbox = false,
  });

  @override
  State<UpiPaymentDialog> createState() => _UpiPaymentDialogState();
}

class _UpiPaymentDialogState extends State<UpiPaymentDialog> {
  final UpiPaymentService _paymentService = UpiPaymentService();
  final TextEditingController _utrController = TextEditingController();

  late String _transactionRefId;
  late String _upiQrString;
  UpiPaymentTransaction? _activeTransaction;

  bool _isCreating = true;
  bool _isVerifying = false;
  PaymentStatus _currentStatus = PaymentStatus.pending;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  void _initializePayment() async {
    _transactionRefId = UpiPaymentService.generateTransactionRefId(widget.invoiceNumber);

    _upiQrString = UpiPaymentService.buildUpiQrString(
      payeeVpa: widget.merchantUpiId,
      payeeName: widget.storeName,
      amount: widget.payableAmount,
      invoiceNumber: widget.invoiceNumber,
      transactionRefId: _transactionRefId,
    );

    try {
      final txn = await _paymentService.createPaymentRequest(
        invoiceNumber: widget.invoiceNumber,
        amount: widget.payableAmount,
        merchantUpiId: widget.merchantUpiId,
        transactionRefId: _transactionRefId,
        isSandbox: widget.isSandbox,
      );
      if (mounted) {
        setState(() {
          _activeTransaction = txn;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = 'Could not initialize cloud payment log: $e';
        });
      }
    }
  }

  Future<void> _handleConfirmPayment({bool isSandbox = false}) async {
    if (_isVerifying) return;

    final utrText = _utrController.text.trim();
    if (!isSandbox && utrText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 12-digit UPI UTR / Bank Reference Number from customer screen';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _currentStatus = PaymentStatus.processing;
    });

    try {
      final baseTxn = _activeTransaction ??
          UpiPaymentTransaction(
            id: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
            invoiceNumber: widget.invoiceNumber,
            transactionRefId: _transactionRefId,
            amount: widget.payableAmount,
            status: PaymentStatus.pending,
            upiId: widget.merchantUpiId,
            createdAt: DateTime.now(),
          );

      UpiPaymentTransaction verifiedTxn;
      if (isSandbox) {
        // Simulated network delay for realistic verification feedback
        await Future.delayed(const Duration(milliseconds: 1200));
        verifiedTxn = await _paymentService.simulateSandboxPayment(
          transaction: baseTxn,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
        verifiedTxn = await _paymentService.confirmPaymentWithUtr(
          transaction: baseTxn,
          utrNumber: utrText,
        );
      }

      if (!mounted) return;

      setState(() {
        _currentStatus = PaymentStatus.paid;
        _isVerifying = false;
      });

      // Brief pause to show celebration checkmark
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pop(verifiedTxn);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _currentStatus = PaymentStatus.failed;
        _errorMessage = 'Verification error: $e';
      });
    }
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Payment?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        content: Text(
          'Are you sure you want to cancel? The pending invoice will NOT be marked as paid.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NO, KEEP OPEN'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _paymentService.cancelPayment(_transactionRefId);
              Navigator.of(context).pop(null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = widget.payableAmount.toStringAsFixed(2);

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI Digital Payment',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            widget.invoiceNumber,
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.outline),
                    onPressed: _handleCancel,
                    tooltip: 'Cancel Payment',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Payable Amount Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF292524),
                      Color(0xFF44403C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL PAYABLE AMOUNT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹ ',
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                        Text(
                          formattedAmount,
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pay to: ${widget.storeName} (${widget.merchantUpiId})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dynamic QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 200,
                        width: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : QrImageView(
                        data: _upiQrString,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.primary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Instruction text
              Text(
                'Scan the QR code using any UPI app to complete your payment',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),

              // Supported UPI apps badges
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildAppBadge('GPay'),
                  _buildAppBadge('PhonePe'),
                  _buildAppBadge('Paytm'),
                  _buildAppBadge('BHIM'),
                  _buildAppBadge('Cred'),
                  _buildAppBadge('Any UPI'),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Cashier Verification Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 16, color: AppTheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          'CASHIER VERIFICATION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _utrController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Bank UTR / Reference No.',
                        hintText: 'e.g. 428719283741 or Ref ID',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
                        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.outlineVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _isVerifying ? null : () => _handleConfirmPayment(isSandbox: false),
                        icon: _isVerifying && _currentStatus == PaymentStatus.processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          _isVerifying ? 'VERIFYING...' : 'CONFIRM PAYMENT RECEIVED',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857), // Emerald Green
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Sandbox Simulation Button
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _isVerifying ? null : () => _handleConfirmPayment(isSandbox: true),
                  icon: const Icon(Icons.science_outlined, size: 16, color: AppTheme.secondary),
                  label: Text(
                    'Sandbox Test: Simulate Success (No Real Payment)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.secondary, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              TextButton.icon(
                onPressed: _isVerifying ? null : _handleCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.outline),
                label: Text(
                  'Cancel Payment Request',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
