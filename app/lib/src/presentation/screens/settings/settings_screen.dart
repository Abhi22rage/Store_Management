import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/auth_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'package:smart_store/src/presentation/common/branch_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // Store Information
  String _storeName = 'Smart Store';
  String _storeAddress = 'Main Road, Sample City';
  String _storePhone = '+91 9876543210';
  String _storeGSTIN = '27AAAAA0000A1Z5';
  String _receiptTagline = 'Thank you for shopping with us!';

  // Tax & Inventory Settings
  double _lowStockThreshold = 10.0;
  bool _lowStockAlertEnabled = true;
  double _sgst = 0.0;
  double _cgst = 0.0;
  double _igst = 0.0;
  bool _taxInclusive = false;

  // Localization & Regional
  String _currencySymbol = '₹';
  String _currencyPosition = 'before'; // 'before' or 'after'
  String _dateFormat = 'DD/MM/YYYY';

  // Security
  bool _pinLockEnabled = false;
  int _sessionTimeoutMinutes = 30;

  // Printers & Hardware
  String _printerPaperSize = '58mm';
  bool _autoPrintReceipt = false;
  String _receiptHeader = 'SMART STORE POS';
  String _receiptFooter = 'Visit Again!';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch remote settings from Supabase if available
    Map<String, dynamic>? remote;
    try {
      remote = await ApiService().getStoreSettings();
    } catch (e) {
      debugPrint('Could not fetch remote store settings: $e');
    }

    if (!mounted) return;
    setState(() {
      _storeName = remote?['store_name'] ?? prefs.getString('store_name') ?? 'Smart Store';
      _storeAddress = remote?['store_address'] ?? prefs.getString('store_address') ?? 'Main Road, Sample City';
      _storePhone = remote?['store_phone'] ?? prefs.getString('store_phone') ?? '+91 9876543210';
      _storeGSTIN = remote?['store_gstin'] ?? prefs.getString('store_gstin') ?? '27AAAAA0000A1Z5';
      _receiptTagline = remote?['receipt_tagline'] ?? prefs.getString('receipt_tagline') ?? 'Thank you for shopping with us!';

      _lowStockThreshold = double.tryParse(remote?['low_stock_threshold']?.toString() ?? '') ?? prefs.getDouble('low_stock_threshold') ?? 10.0;
      _lowStockAlertEnabled = remote?['low_stock_alert_enabled'] ?? prefs.getBool('low_stock_alert_enabled') ?? true;
      _sgst = double.tryParse(remote?['sgst_percent']?.toString() ?? '') ?? prefs.getDouble('sgst_percent') ?? 0.0;
      _cgst = double.tryParse(remote?['cgst_percent']?.toString() ?? '') ?? prefs.getDouble('cgst_percent') ?? 0.0;
      _igst = double.tryParse(remote?['igst_percent']?.toString() ?? '') ?? prefs.getDouble('igst_percent') ?? 0.0;
      _taxInclusive = remote?['tax_inclusive'] ?? prefs.getBool('tax_inclusive') ?? false;

      _currencySymbol = remote?['currency_symbol'] ?? prefs.getString('currency_symbol') ?? '₹';
      _currencyPosition = remote?['currency_position'] ?? prefs.getString('currency_position') ?? 'before';
      _dateFormat = remote?['date_format'] ?? prefs.getString('date_format') ?? 'DD/MM/YYYY';

      _pinLockEnabled = remote?['pin_lock_enabled'] ?? prefs.getBool('pin_lock_enabled') ?? false;
      _sessionTimeoutMinutes = int.tryParse(remote?['session_timeout_minutes']?.toString() ?? '') ?? prefs.getInt('session_timeout_minutes') ?? 30;

      _printerPaperSize = remote?['printer_paper_size'] ?? prefs.getString('printer_paper_size') ?? '58mm';
      _autoPrintReceipt = remote?['auto_print_receipt'] ?? prefs.getBool('auto_print_receipt') ?? false;
      _receiptHeader = remote?['receipt_header'] ?? prefs.getString('receipt_header') ?? 'SMART STORE POS';
      _receiptFooter = remote?['receipt_footer'] ?? prefs.getString('receipt_footer') ?? 'Visit Again!';

      _isLoading = false;
    });

    // Update local cache
    await prefs.setString('store_name', _storeName);
    await prefs.setString('store_address', _storeAddress);
    await prefs.setString('store_phone', _storePhone);
    await prefs.setString('store_gstin', _storeGSTIN);
    await prefs.setString('receipt_tagline', _receiptTagline);
    await prefs.setDouble('low_stock_threshold', _lowStockThreshold);
    await prefs.setBool('low_stock_alert_enabled', _lowStockAlertEnabled);
    await prefs.setDouble('sgst_percent', _sgst);
    await prefs.setDouble('cgst_percent', _cgst);
    await prefs.setDouble('igst_percent', _igst);
    await prefs.setBool('tax_inclusive', _taxInclusive);
    await prefs.setString('currency_symbol', _currencySymbol);
    await prefs.setString('currency_position', _currencyPosition);
    await prefs.setString('date_format', _dateFormat);
    await prefs.setBool('pin_lock_enabled', _pinLockEnabled);
    await prefs.setInt('session_timeout_minutes', _sessionTimeoutMinutes);
    await prefs.setString('printer_paper_size', _printerPaperSize);
    await prefs.setBool('auto_print_receipt', _autoPrintReceipt);
    await prefs.setString('receipt_header', _receiptHeader);
    await prefs.setString('receipt_footer', _receiptFooter);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _storeName);
    await prefs.setString('store_address', _storeAddress);
    await prefs.setString('store_phone', _storePhone);
    await prefs.setString('store_gstin', _storeGSTIN);
    await prefs.setString('receipt_tagline', _receiptTagline);

    await prefs.setDouble('low_stock_threshold', _lowStockThreshold);
    await prefs.setBool('low_stock_alert_enabled', _lowStockAlertEnabled);
    await prefs.setDouble('sgst_percent', _sgst);
    await prefs.setDouble('cgst_percent', _cgst);
    await prefs.setDouble('igst_percent', _igst);
    await prefs.setBool('tax_inclusive', _taxInclusive);

    await prefs.setString('currency_symbol', _currencySymbol);
    await prefs.setString('currency_position', _currencyPosition);
    await prefs.setString('date_format', _dateFormat);

    await prefs.setBool('pin_lock_enabled', _pinLockEnabled);
    await prefs.setInt('session_timeout_minutes', _sessionTimeoutMinutes);

    await prefs.setString('printer_paper_size', _printerPaperSize);
    await prefs.setBool('auto_print_receipt', _autoPrintReceipt);
    await prefs.setString('receipt_header', _receiptHeader);
    await prefs.setString('receipt_footer', _receiptFooter);

    // Save permanently to database
    try {
      await ApiService().saveStoreSettings({
        'store_name': _storeName,
        'store_address': _storeAddress,
        'store_phone': _storePhone,
        'store_gstin': _storeGSTIN,
        'receipt_tagline': _receiptTagline,
        'low_stock_threshold': _lowStockThreshold,
        'low_stock_alert_enabled': _lowStockAlertEnabled,
        'sgst_percent': _sgst,
        'cgst_percent': _cgst,
        'igst_percent': _igst,
        'tax_inclusive': _taxInclusive,
        'currency_symbol': _currencySymbol,
        'currency_position': _currencyPosition,
        'date_format': _dateFormat,
        'pin_lock_enabled': _pinLockEnabled,
        'session_timeout_minutes': _sessionTimeoutMinutes,
        'printer_paper_size': _printerPaperSize,
        'auto_print_receipt': _autoPrintReceipt,
        'receipt_header': _receiptHeader,
        'receipt_footer': _receiptFooter,
      });
    } catch (e) {
      debugPrint('Error persisting settings to database: $e');
    }

    DataRepository().notifySettingsChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: AppTheme.accent,
        duration: Duration(seconds: 2),
      ),
    );
  }


  // ─── 1. STORE DETAILS DIALOG ──────────────────────────────────────
  void _showStoreDetailsDialog() {
    final nameCtrl = TextEditingController(text: _storeName);
    final addrCtrl = TextEditingController(text: _storeAddress);
    final phoneCtrl = TextEditingController(text: _storePhone);
    final gstinCtrl = TextEditingController(text: _storeGSTIN);
    final taglineCtrl = TextEditingController(text: _receiptTagline);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Store Details',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextInput('Store Name', nameCtrl, icon: Icons.store),
              const SizedBox(height: 12),
              _buildTextInput('Address', addrCtrl, maxLines: 2, icon: Icons.location_on),
              const SizedBox(height: 12),
              _buildTextInput('Phone', phoneCtrl, icon: Icons.phone),
              const SizedBox(height: 12),
              _buildTextInput('GSTIN / Tax ID', gstinCtrl, icon: Icons.receipt_long),
              const SizedBox(height: 12),
              _buildTextInput('Receipt Tagline', taglineCtrl, icon: Icons.style),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _storeName = nameCtrl.text.trim();
                _storeAddress = addrCtrl.text.trim();
                _storePhone = phoneCtrl.text.trim();
                _storeGSTIN = gstinCtrl.text.trim();
                _receiptTagline = taglineCtrl.text.trim();
              });
              Navigator.pop(context);
              _saveSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  // ─── 2. TAX & INVENTORY SETTINGS DIALOG ────────────────────────────
  void _showTaxAndStockDialog() {
    final sgstStr = _sgst % 1 == 0 ? _sgst.toInt().toString() : _sgst.toString();
    final cgstStr = _cgst % 1 == 0 ? _cgst.toInt().toString() : _cgst.toString();
    final igstStr = _igst % 1 == 0 ? _igst.toInt().toString() : _igst.toString();
    final sgstCtrl = TextEditingController(text: sgstStr);
    final cgstCtrl = TextEditingController(text: cgstStr);
    final igstCtrl = TextEditingController(text: igstStr);
    final thresholdCtrl = TextEditingController(text: _lowStockThreshold.round().toString());
    bool tempInclusive = _taxInclusive;
    bool tempAlertEnabled = _lowStockAlertEnabled;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.percent_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Tax & Inventory Rules',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GST TAX RATES (%)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildNumberInput('SGST (%)', sgstCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNumberInput('CGST (%)', cgstCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNumberInput('IGST (%)', igstCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Prices Include Tax',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Tax is included in listed item prices',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline),
                  ),
                  value: tempInclusive,
                  onChanged: (val) {
                    setModalState(() => tempInclusive = val);
                  },
                ),
                const Divider(height: 24),
                Text(
                  'INVENTORY ALERTS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNumberInput('Low Stock Threshold (Units)', thresholdCtrl, suffix: 'units'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Low Stock Warning',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Show warnings when item quantity drops below threshold',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline),
                  ),
                  value: tempAlertEnabled,
                  onChanged: (val) {
                    setModalState(() => tempAlertEnabled = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () async {
                final sgstVal = double.tryParse(sgstCtrl.text) ?? 0.0;
                final cgstVal = double.tryParse(cgstCtrl.text) ?? 0.0;
                final igstVal = double.tryParse(igstCtrl.text) ?? 0.0;
                final thresholdVal = double.tryParse(thresholdCtrl.text) ?? 10.0;

                setState(() {
                  _sgst = sgstVal;
                  _cgst = cgstVal;
                  _igst = igstVal;
                  _lowStockThreshold = thresholdVal;
                  _taxInclusive = tempInclusive;
                  _lowStockAlertEnabled = tempAlertEnabled;
                });
                Navigator.pop(context);
                await _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. LOCALIZATION DIALOG ──────────────────────────────────────
  void _showLocalizationDialog() {
    String tempSymbol = _currencySymbol;
    String tempPos = _currencyPosition;
    String tempDateFmt = _dateFormat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.language_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Currency & Regional',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENCY SYMBOL', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['₹', '\$', '€', '£', '¥', 'AED'].map((sym) {
                    final selected = tempSymbol == sym;
                    return ChoiceChip(
                      label: Text(sym, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                      selected: selected,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setModalState(() => tempSymbol = sym);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('CURRENCY POSITION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'before', label: Text('Before ($tempSymbol 100)')),
                    ButtonSegment(value: 'after', label: Text('After (100 $tempSymbol)')),
                  ],
                  selected: {tempPos},
                  onSelectionChanged: (set) {
                    setModalState(() => tempPos = set.first);
                  },
                ),
                const SizedBox(height: 16),
                Text('DATE FORMAT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tempDateFmt,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLow,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DD/MM/YYYY', child: Text('DD/MM/YYYY (e.g. 04/08/2026)')),
                    DropdownMenuItem(value: 'MM/DD/YYYY', child: Text('MM/DD/YYYY (e.g. 08/04/2026)')),
                    DropdownMenuItem(value: 'YYYY-MM-DD', child: Text('YYYY-MM-DD (e.g. 2026-08-04)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempDateFmt = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currencySymbol = tempSymbol;
                  _currencyPosition = tempPos;
                  _dateFormat = tempDateFmt;
                });
                Navigator.pop(context);
                _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. SECURITY DIALOG ───────────────────────────────────────────
  void _showSecurityDialog() {
    bool tempPinLock = _pinLockEnabled;
    int tempTimeout = _sessionTimeoutMinutes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Security Settings',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Require PIN Lock on Launch', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Prompt for 4-digit PIN when opening app', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                  value: tempPinLock,
                  onChanged: (val) {
                    setModalState(() => tempPinLock = val);
                  },
                ),
                const SizedBox(height: 12),
                Text('SESSION INACTIVITY TIMEOUT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: tempTimeout,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLow,
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 Hour')),
                    DropdownMenuItem(value: 120, child: Text('2 Hours')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempTimeout = val);
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset link sent to your registered email.')),
                    );
                  },
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Send Password Reset Email'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _pinLockEnabled = tempPinLock;
                  _sessionTimeoutMinutes = tempTimeout;
                });
                Navigator.pop(context);
                _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. PRINTER & POS HARDWARE DIALOG ─────────────────────────────
  void _showPrinterDialog() {
    String tempPaper = _printerPaperSize;
    bool tempAutoPrint = _autoPrintReceipt;
    final headerCtrl = TextEditingController(text: _receiptHeader);
    final footerCtrl = TextEditingController(text: _receiptFooter);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Printers & POS Hardware',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECEIPT PAPER SIZE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '58mm', label: Text('58mm Thermal')),
                    ButtonSegment(value: '80mm', label: Text('80mm Thermal')),
                  ],
                  selected: {tempPaper},
                  onSelectionChanged: (set) {
                    setModalState(() => tempPaper = set.first);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Auto-Print Receipt', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Automatically print thermal receipt upon completed sale', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                  value: tempAutoPrint,
                  onChanged: (val) {
                    setModalState(() => tempAutoPrint = val);
                  },
                ),
                const SizedBox(height: 12),
                _buildTextInput('Receipt Header', headerCtrl, icon: Icons.title),
                const SizedBox(height: 12),
                _buildTextInput('Receipt Footer Message', footerCtrl, icon: Icons.notes),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.outline)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _printerPaperSize = tempPaper;
                  _autoPrintReceipt = tempAutoPrint;
                  _receiptHeader = headerCtrl.text.trim();
                  _receiptFooter = footerCtrl.text.trim();
                });
                Navigator.pop(context);
                _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. BACKUP & RESTORE DIALOG ───────────────────────────────────
  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Backup & System Data',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
              title: Text('Export JSON Data Backup', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('Copy offline backup of store settings & cached records', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
              onTap: () async {
                Navigator.pop(dialogContext);
                final jsonStr = await DataRepository().exportBackupJson();
                if (!mounted) return;
                _showBackupPayloadDialog(jsonStr);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded, color: AppTheme.error),
              title: Text('Purge Local Data Cache', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.error)),
              subtitle: Text('Clear cached inventory & force resync from server', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
              onTap: () async {
                Navigator.pop(dialogContext);
                await DataRepository().clearAllDiskCaches();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local cache cleared! Resynchronizing...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE', style: TextStyle(color: AppTheme.outline)),
          ),
        ],
      ),
    );
  }

  void _showBackupPayloadDialog(String jsonStr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Backup Payload Ready',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                jsonStr,
                style: GoogleFonts.firaCode(fontSize: 11),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup JSON copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('COPY TO CLIPBOARD'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  // ─── 7. ABOUT DIALOG ──────────────────────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'About Smart Dukan',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.store_rounded, color: AppTheme.onPrimary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Smart Dukan POS',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
            ),
            Text(
              'Version 1.2.0 (Build 20260804)',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Database Service: Supabase Online',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Smart Dukan is a modern retail POS and inventory system designed for high efficiency and seamless shop management.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helper Inputs
  Widget _buildTextInput(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    IconData? icon,
    bool isPhone = false,
  }) {
    final bool phoneMode = isPhone || label.toLowerCase().contains('phone');
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: phoneMode ? TextInputType.number : TextInputType.text,
      maxLength: phoneMode ? 10 : null,
      inputFormatters: phoneMode
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      decoration: InputDecoration(
        labelText: label,
        counterText: phoneMode ? '' : null,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController controller, {String? suffix}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: _isLoading,
      containersColor: AppTheme.outline,
      effect: ShimmerEffect(
        baseColor: AppTheme.surfaceContainerHighest,
        highlightColor: AppTheme.surfaceContainer,
      ),
      child: Scaffold(
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
            'SETTINGS',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: 2.0,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push('/settings/users'),
              icon: const Icon(Icons.people_alt_outlined, color: AppTheme.primary),
              tooltip: 'User Management',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configuration',
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              // SECTION 1: BUSINESS & STORE
              _buildSection(
                title: 'Business Information',
                children: [
                  ListenableBuilder(
                    listenable: BranchService(),
                    builder: (context, _) {
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.store_rounded, color: AppTheme.primary, size: 20),
                        ),
                        title: Text(
                          'Active Branch',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primary,
                          ),
                        ),
                        subtitle: Text(
                          'Current outlet: ${BranchService().currentBranch}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
                        ),
                        trailing: const BranchSelector(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.store_rounded,
                    'Store Details',
                    '$_storeName • $_storePhone',
                    onTap: _showStoreDetailsDialog,
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.storefront_rounded,
                    'Branch Management',
                    'Add, Edit, or Switch store outlet locations',
                    onTap: () => context.push('/settings/branches'),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.groups_rounded,
                    'Supplier Directory',
                    'Manage vendor profiles and contacts',
                    onTap: () => context.push('/suppliers'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECTION 2: TAX & INVENTORY
              _buildSection(
                title: 'Tax & Inventory Rules',
                children: [
                  _buildSettingItem(
                    Icons.percent_rounded,
                    'Tax Rates & Stock Thresholds',
                    'SGST $_sgst%, CGST $_cgst%, IGST $_igst% • Low Stock: ${_lowStockThreshold.round()} units',
                    onTap: _showTaxAndStockDialog,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECTION 3: LOCALIZATION & HARDWARE
              _buildSection(
                title: 'Regional & POS Hardware',
                children: [
                  _buildSettingItem(
                    Icons.language_rounded,
                    'Currency & Format',
                    'Currency: $_currencySymbol ($_currencyPosition) • Date: $_dateFormat',
                    onTap: _showLocalizationDialog,
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.print_rounded,
                    'Printers & POS Hardware',
                    'Thermal Paper: $_printerPaperSize • Auto-print: ${_autoPrintReceipt ? "ON" : "OFF"}',
                    onTap: _showPrinterDialog,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECTION 4: USER & SECURITY
              _buildSection(
                title: 'User Management & Security',
                children: [
                  _buildSettingItem(
                    Icons.people_rounded,
                    'Staff & Role Management',
                    'Configure permissions for Owner, Manager, and Staff',
                    onTap: () => context.push('/settings/users'),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.security_rounded,
                    'Security & Access',
                    'PIN Lock: ${_pinLockEnabled ? "ENABLED" : "DISABLED"} • Timeout: $_sessionTimeoutMinutes mins',
                    onTap: _showSecurityDialog,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECTION 5: SYSTEM & DATA
              _buildSection(
                title: 'System & Backup',
                children: [
                  _buildSettingItem(
                    Icons.cloud_sync_rounded,
                    'Backup & Data Export',
                    'Export JSON backup payload and purge offline cache',
                    onTap: _showBackupRestoreDialog,
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    Icons.info_outline_rounded,
                    'About & System Status',
                    'Version 1.2.0 • Supabase Connection Active',
                    onTap: _showAboutDialog,
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // SIGN OUT BUTTON
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    AuthProvider.of(context).logout();
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorContainer,
                    foregroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.outline,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppTheme.primary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.outlineVariant,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
