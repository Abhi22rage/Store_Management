import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_store/src/core/services/api_service.dart';

enum PaymentStatus {
  pending,
  processing,
  paid,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static PaymentStatus fromString(String? val) {
    if (val == null) return PaymentStatus.pending;
    switch (val.toUpperCase()) {
      case 'PAID':
        return PaymentStatus.paid;
      case 'PROCESSING':
        return PaymentStatus.processing;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'CANCELLED':
        return PaymentStatus.cancelled;
      case 'PENDING':
      default:
        return PaymentStatus.pending;
    }
  }
}

class UpiPaymentTransaction {
  final String id;
  final String invoiceNumber;
  final String transactionRefId;
  final String paymentProvider;
  final String paymentMethod;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? gatewayTxnId;
  final String? upiId;
  final String? customerVpa;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final Map<String, dynamic> metadata;

  const UpiPaymentTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.transactionRefId,
    this.paymentProvider = 'UPI_DIRECT',
    this.paymentMethod = 'UPI',
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.gatewayTxnId,
    this.upiId,
    this.customerVpa,
    required this.createdAt,
    this.verifiedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'transaction_ref_id': transactionRefId,
      'payment_provider': paymentProvider,
      'payment_method': paymentMethod,
      'amount': amount,
      'currency': currency,
      'payment_status': status.displayName.toUpperCase(),
      'gateway_txn_id': gatewayTxnId,
      'upi_id': upiId,
      'customer_vpa': customerVpa,
      'created_at': createdAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory UpiPaymentTransaction.fromMap(Map<String, dynamic> map) {
    return UpiPaymentTransaction(
      id: map['id']?.toString() ?? '',
      invoiceNumber: (map['invoice_number'] ?? map['invoiceNumber'] ?? '').toString(),
      transactionRefId: (map['transaction_ref_id'] ?? map['transactionRefId'] ?? '').toString(),
      paymentProvider: (map['payment_provider'] ?? 'UPI_DIRECT').toString(),
      paymentMethod: (map['payment_method'] ?? 'UPI').toString(),
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      currency: (map['currency'] ?? 'INR').toString(),
      status: PaymentStatus.fromString(map['payment_status']?.toString()),
      gatewayTxnId: map['gateway_txn_id']?.toString(),
      upiId: map['upi_id']?.toString(),
      customerVpa: map['customer_vpa']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      verifiedAt: map['verified_at'] != null
          ? DateTime.tryParse(map['verified_at'].toString())
          : null,
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'])
          : {},
    );
  }
}

class UpiPaymentService {
  static final UpiPaymentService _instance = UpiPaymentService._internal();
  factory UpiPaymentService() => _instance;
  UpiPaymentService._internal();

  /// Validates standard Indian UPI VPA/ID format (e.g. name@bank or shop@okaxis)
  static bool isValidUpiId(String upiId) {
    final clean = upiId.trim();
    if (clean.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return regex.hasMatch(clean);
  }

  /// Validates standard Indian IFSC Code (e.g. HDFC0001234, SBIN0000456)
  static bool isValidIfsc(String ifsc) {
    final clean = ifsc.trim().toUpperCase();
    if (clean.length != 11) return false;
    final regex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    return regex.hasMatch(clean);
  }

  /// Generates a standards-compliant NPCI UPI Deep Link / QR String
  ///
  /// Specification format:
  /// `upi://pay?pa={vpa}&pn={payeeName}&am={amount}&cu=INR&tn={note}&tr={refId}`
  static String buildUpiQrString({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String invoiceNumber,
    required String transactionRefId,
  }) {
    final cleanVpa = payeeVpa.trim();
    final cleanName = payeeName.trim().isEmpty ? 'Merchant' : payeeName.trim();
    final amountFormatted = amount.toStringAsFixed(2);
    final note = 'Invoice $invoiceNumber';

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': cleanVpa,
        'pn': cleanName,
        'am': amountFormatted,
        'cu': 'INR',
        'tn': note,
        'tr': transactionRefId,
      },
    );

    return uri.toString();
  }

  /// Generates a clean, unique transaction reference ID
  static String generateTransactionRefId(String invoiceNumber) {
    final cleanInv = invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TXN-${cleanInv.isNotEmpty ? cleanInv : "INV"}-$timestamp';
  }

  /// Retrieves merchant UPI configuration from SharedPreferences or Remote Settings
  Future<Map<String, String>> getMerchantPaymentConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check local preferences first
    String upiId = prefs.getString('merchant_upi_id') ?? '';
    String upiName = prefs.getString('upi_display_name') ?? '';
    String storeName = prefs.getString('store_name') ?? 'Smart Store';
    String gatewayStatus = prefs.getString('gateway_status') ?? 'DEMO';

    // Fallback to Supabase remote settings if not found locally
    if (upiId.isEmpty) {
      try {
        final remote = await ApiService().getStoreSettings();
        if (remote != null) {
          upiId = remote['merchant_upi_id']?.toString() ?? '';
          upiName = remote['upi_display_name']?.toString() ?? '';
          if (remote['store_name'] != null) {
            storeName = remote['store_name'].toString();
          }
          if (remote['gateway_status'] != null) {
            gatewayStatus = remote['gateway_status'].toString();
          }
        }
      } catch (e) {
        debugPrint('[UpiPaymentService] Fallback to defaults on remote config read: $e');
      }
    }

    // Safe default placeholder for testing if admin hasn't configured one yet
    if (upiId.isEmpty) {
      upiId = 'smartdukan@okhdfcbank';
      upiName = storeName;
    }

    return {
      'upiId': upiId,
      'upiName': upiName.isNotEmpty ? upiName : storeName,
      'gatewayStatus': gatewayStatus,
    };
  }

  /// Creates and records a pending payment transaction in Supabase and local cache
  Future<UpiPaymentTransaction> createPaymentRequest({
    required String invoiceNumber,
    required double amount,
    required String merchantUpiId,
    String? transactionRefId,
    bool isSandbox = false,
  }) async {
    final refId = transactionRefId ?? generateTransactionRefId(invoiceNumber);
    final now = DateTime.now();

    final txn = UpiPaymentTransaction(
      id: 'PAY-${now.millisecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      transactionRefId: refId,
      paymentProvider: isSandbox ? 'SANDBOX_SIMULATOR' : 'UPI_DIRECT',
      paymentMethod: 'UPI',
      amount: amount,
      currency: 'INR',
      status: PaymentStatus.pending,
      upiId: merchantUpiId,
      createdAt: now,
      metadata: {
        'is_sandbox': isSandbox,
        'client_platform': defaultTargetPlatform.name,
      },
    );

    try {
      await ApiService().recordPaymentTransaction(txn.toMap());
    } catch (e) {
      debugPrint('[UpiPaymentService] Could not persist payment txn to cloud: $e');
    }

    return txn;
  }

  /// Confirms payment via Cashier / Customer UTR Bank Reference Number
  Future<UpiPaymentTransaction> confirmPaymentWithUtr({
    required UpiPaymentTransaction transaction,
    required String utrNumber,
  }) async {
    final now = DateTime.now();
    final cleanUtr = utrNumber.trim();

    final updatedTxn = UpiPaymentTransaction(
      id: transaction.id,
      invoiceNumber: transaction.invoiceNumber,
      transactionRefId: transaction.transactionRefId,
      paymentProvider: transaction.paymentProvider,
      paymentMethod: 'UPI',
      amount: transaction.amount,
      currency: transaction.currency,
      status: PaymentStatus.paid,
      gatewayTxnId: cleanUtr.isNotEmpty ? cleanUtr : 'UTR-${now.millisecondsSinceEpoch}',
      upiId: transaction.upiId,
      customerVpa: transaction.customerVpa,
      createdAt: transaction.createdAt,
      verifiedAt: now,
      metadata: {
        ...transaction.metadata,
        'verified_via': 'CASHIER_UTR_CONFIRMATION',
        'utr': cleanUtr,
      },
    );

    try {
      await ApiService().updatePaymentTransactionStatus(
        transactionRefId: transaction.transactionRefId,
        status: PaymentStatus.paid.displayName.toUpperCase(),
        gatewayTxnId: updatedTxn.gatewayTxnId,
        verifiedAt: now,
      );
    } catch (e) {
      debugPrint('[UpiPaymentService] Cloud update warning: $e');
    }

    return updatedTxn;
  }

  /// Simulates payment completion in Sandbox / Demo mode
  Future<UpiPaymentTransaction> simulateSandboxPayment({
    required UpiPaymentTransaction transaction,
  }) async {
    final now = DateTime.now();
    final mockUtr = 'DEMO-UTR-${now.millisecondsSinceEpoch}';

    final updatedTxn = UpiPaymentTransaction(
      id: transaction.id,
      invoiceNumber: transaction.invoiceNumber,
      transactionRefId: transaction.transactionRefId,
      paymentProvider: 'SANDBOX_SIMULATOR',
      paymentMethod: 'UPI',
      amount: transaction.amount,
      currency: transaction.currency,
      status: PaymentStatus.paid,
      gatewayTxnId: mockUtr,
      upiId: transaction.upiId,
      createdAt: transaction.createdAt,
      verifiedAt: now,
      metadata: {
        ...transaction.metadata,
        'sandbox_simulation': true,
      },
    );

    try {
      await ApiService().updatePaymentTransactionStatus(
        transactionRefId: transaction.transactionRefId,
        status: PaymentStatus.paid.displayName.toUpperCase(),
        gatewayTxnId: mockUtr,
        verifiedAt: now,
      );
    } catch (e) {
      debugPrint('[UpiPaymentService] Cloud update warning: $e');
    }

    return updatedTxn;
  }

  /// Cancels an in-progress payment request
  Future<void> cancelPayment(String transactionRefId) async {
    try {
      await ApiService().updatePaymentTransactionStatus(
        transactionRefId: transactionRefId,
        status: PaymentStatus.cancelled.displayName.toUpperCase(),
      );
    } catch (e) {
      debugPrint('[UpiPaymentService] Cancel status warning: $e');
    }
  }
}
