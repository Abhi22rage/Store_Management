import 'dart:developer' as dev;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintInvoice(Map<String, dynamic> sale) async {
    try {
      final pdf = await _buildPdf(sale);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_${sale['invoiceNumber']}.pdf',
      );
    } catch (e) {
      dev.log('Error generating PDF: $e');
    }
  }

  static Future<void> generateAndShareInvoice(Map<String, dynamic> sale) async {
    try {
      final pdf = await _buildPdf(sale);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Invoice_${sale['invoiceNumber']}.pdf',
      );
    } catch (e) {
      dev.log('Error sharing PDF: $e');
    }
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  static Future<pw.Document> _buildPdf(Map<String, dynamic> sale) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    final storeName = prefs.getString('store_name') ?? 'Smart Store';
    final storeAddress = prefs.getString('store_address') ?? 'Main Road, Sample City';
    final storePhone = prefs.getString('store_phone') ?? '+91 9876543210';
    final storeGSTIN = prefs.getString('store_gstin') ?? '27AAAAA0000A1Z5';

    final defaultSgstPct = prefs.getDouble('sgst_percent') ?? 0.0;
    final defaultCgstPct = prefs.getDouble('cgst_percent') ?? 0.0;
    final defaultIgstPct = prefs.getDouble('igst_percent') ?? 0.0;

    final items = (sale['items'] as List?) ?? [];
    final date = DateTime.tryParse(sale['date']?.toString() ?? '') ?? 
                 DateTime.tryParse(sale['createdAt']?.toString() ?? '') ?? 
                 DateTime.now();
                 
    final formattedDate = DateFormat('dd-MMM-yyyy HH:mm').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('GSTIN: $storeGSTIN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 8),
                    pw.Text('Invoice #: ${sale['invoiceNumber'] ?? sale['id'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),

            // Customer Details
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey600)),
                    pw.Text(sale['customerName']?.toString() ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if (sale['customerPhone'] != null && sale['customerPhone'].toString().isNotEmpty)
                      pw.Text('Phone: ${sale['customerPhone']}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(50),
                3: const pw.FixedColumnWidth(40),
                4: const pw.FixedColumnWidth(70),
                5: const pw.FixedColumnWidth(70),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    'S.N.', 'Item Description', 'Size/Colour', 'Qty', 'Rate', 'Amount'
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  )).toList(),
                ),
                // Table Rows
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  final price = _toDouble(item['pricePerPiece'] ?? item['price']);
                  final total = _toDouble(item['totalPrice'] ?? item['amount']);
                  final s = item['size']?.toString() ?? '-';
                  final c = item['color']?.toString() ?? '';
                  final details = '$s${c.isNotEmpty ? ' ($c)' : ''}';
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item['name']?.toString() ?? '', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(details, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item['quantity']?.toString() ?? '0', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 15),

            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Sub Total', 'Rs. ${_toDouble(sale['subTotal'] ?? sale['totalAmount']).toStringAsFixed(2)}'),
                      if (sale['taxDetails'] != null) ...[
                        if (_toDouble(sale['taxDetails']['sgst']) > 0 || _toDouble(sale['taxDetails']['sgstPercent']) > 0)
                          _buildSummaryRow(
                            'SGST (${(_toDouble(sale['taxDetails']['sgstPercent']) > 0 ? _toDouble(sale['taxDetails']['sgstPercent']) : defaultSgstPct) % 1 == 0 ? (_toDouble(sale['taxDetails']['sgstPercent']) > 0 ? _toDouble(sale['taxDetails']['sgstPercent']) : defaultSgstPct).toInt() : (_toDouble(sale['taxDetails']['sgstPercent']) > 0 ? _toDouble(sale['taxDetails']['sgstPercent']) : defaultSgstPct)}%)',
                            'Rs. ${_toDouble(sale['taxDetails']['sgst']).toStringAsFixed(2)}',
                          ),
                        if (_toDouble(sale['taxDetails']['cgst']) > 0 || _toDouble(sale['taxDetails']['cgstPercent']) > 0)
                          _buildSummaryRow(
                            'CGST (${(_toDouble(sale['taxDetails']['cgstPercent']) > 0 ? _toDouble(sale['taxDetails']['cgstPercent']) : defaultCgstPct) % 1 == 0 ? (_toDouble(sale['taxDetails']['cgstPercent']) > 0 ? _toDouble(sale['taxDetails']['cgstPercent']) : defaultCgstPct).toInt() : (_toDouble(sale['taxDetails']['cgstPercent']) > 0 ? _toDouble(sale['taxDetails']['cgstPercent']) : defaultCgstPct)}%)',
                            'Rs. ${_toDouble(sale['taxDetails']['cgst']).toStringAsFixed(2)}',
                          ),
                        if (_toDouble(sale['taxDetails']['igst']) > 0 || _toDouble(sale['taxDetails']['igstPercent']) > 0)
                          _buildSummaryRow(
                            'IGST (${(_toDouble(sale['taxDetails']['igstPercent']) > 0 ? _toDouble(sale['taxDetails']['igstPercent']) : defaultIgstPct) % 1 == 0 ? (_toDouble(sale['taxDetails']['igstPercent']) > 0 ? _toDouble(sale['taxDetails']['igstPercent']) : defaultIgstPct).toInt() : (_toDouble(sale['taxDetails']['igstPercent']) > 0 ? _toDouble(sale['taxDetails']['igstPercent']) : defaultIgstPct)}%)',
                            'Rs. ${_toDouble(sale['taxDetails']['igst']).toStringAsFixed(2)}',
                          ),
                      ],
                      if (sale['discount'] != null && _toDouble(sale['discount']) > 0)
                        _buildSummaryRow('Discount', '-Rs. ${_toDouble(sale['discount']).toStringAsFixed(2)}', color: PdfColors.green700),
                      pw.Divider(thickness: 0.5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs. ${_toDouble(sale['grandTotal'] ?? sale['totalAmount']).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),
            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.Text('1. Goods once sold will not be taken back.', style: pw.TextStyle(fontSize: 7)),
                    pw.Text('2. Subject to local jurisdiction.', style: pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.SizedBox(height: 25, width: 80, child: pw.Divider(thickness: 0.5)),
                    pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryRow(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
