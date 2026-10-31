import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoicePdfHelper {
  /// Generates the PDF bytes for either Standard A4 or POS Thermal Receipt
  static Future<Uint8List> generateInvoicePdf(
    Map<String, dynamic> saleData, {
    bool isThermal = false,
    Map<String, dynamic>? storeDetails,
  }) async {
    final pdf = pw.Document();

    final storeName = storeDetails?['store_name'] ??
        storeDetails?['storeName'] ??
        saleData['storeName'] ??
        'SMART STORE';
    final storeAddress = storeDetails?['store_address'] ??
        storeDetails?['address'] ??
        'Main Retail Market, City Center';
    final storePhone = storeDetails?['store_phone'] ??
        storeDetails?['phone'] ??
        '+91 9876543210';
    final storeGstin = storeDetails?['store_gstin'] ??
        storeDetails?['gstin'] ??
        '27AAAAA0000A1Z5';
    final receiptTagline = storeDetails?['receipt_tagline'] ??
        'Thank you for shopping with us!';

    final invoiceNumber = (saleData['invoiceNumber'] ??
            saleData['invoice_number'] ??
            'INV-${DateTime.now().millisecondsSinceEpoch % 100000}')
        .toString();
    final rawDate = saleData['date'] ?? saleData['createdAt'];
    DateTime saleDateTime = DateTime.now();
    if (rawDate != null) {
      saleDateTime = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }
    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(saleDateTime);

    final customerName = (saleData['customerName'] ??
            saleData['customer_name'] ??
            'Walk-in Customer')
        .toString();
    final customerPhone = (saleData['customerPhone'] ??
            saleData['customer_phone'] ??
            '')
        .toString();

    final paymentMethod = (saleData['paymentMethod'] ??
            saleData['payment_method'] ??
            'UPI')
        .toString();
    final paymentStatus = (saleData['paymentStatus'] ??
            saleData['payment_status'] ??
            'PAID')
        .toString();
    final txnRef = (saleData['transactionRefId'] ??
            saleData['gateway_txn_id'] ??
            saleData['payment_details'] ??
            'UPI-CONFIRMED')
        .toString();

    final items = (saleData['items'] as List? ?? []);
    final subTotal = double.tryParse((saleData['subTotal'] ?? saleData['total_amount'] ?? 0).toString()) ?? 0.0;
    final discount = double.tryParse((saleData['discount'] ?? 0).toString()) ?? 0.0;
    final grandTotal = double.tryParse((saleData['grandTotal'] ?? saleData['final_amount'] ?? 0).toString()) ?? 0.0;
    
    // Tax extraction
    final taxDetails = saleData['taxDetails'] is Map ? saleData['taxDetails'] : null;
    final sgst = double.tryParse((taxDetails?['sgst'] ?? 0).toString()) ?? 0.0;
    final cgst = double.tryParse((taxDetails?['cgst'] ?? 0).toString()) ?? 0.0;
    final igst = double.tryParse((taxDetails?['igst'] ?? 0).toString()) ?? 0.0;
    final totalTax = (sgst + cgst + igst) > 0 
        ? (sgst + cgst + igst) 
        : (double.tryParse((saleData['tax_amount'] ?? 0).toString()) ?? 0.0);

    if (isThermal) {
      // 80mm POS Thermal Receipt Layout
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(12),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  storeName.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                pw.Text('Tel: $storePhone | GSTIN: $storeGstin', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('INV: $invoiceNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(dateFormatted, style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 8)),
                    if (customerPhone.isNotEmpty)
                      pw.Text(customerPhone, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Item Header
                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Expanded(flex: 1, child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('PRICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.SizedBox(height: 4),

                // Items List
                ...items.map((it) {
                  final name = (it['name'] ?? it['item_name'] ?? 'Item').toString();
                  final size = (it['size'] ?? '').toString();
                  final qty = int.tryParse((it['quantity'] ?? 1).toString()) ?? 1;
                  final price = double.tryParse((it['pricePerPiece'] ?? it['unit_price'] ?? 0).toString()) ?? 0.0;
                  final total = double.tryParse((it['totalPrice'] ?? it['subtotal'] ?? (price * qty)).toString()) ?? 0.0;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            size.isNotEmpty ? '$name ($size)' : name,
                            style: const pw.TextStyle(fontSize: 8),
                            maxLines: 2,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(total.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('INR ${subTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                if (discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('- INR ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                if (totalTax > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Taxes (GST):', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('INR ${totalTax.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Payment Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('$paymentMethod ($paymentStatus)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Txn Ref / UTR:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(txnRef, style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),

                pw.SizedBox(height: 8),
                pw.Text(receiptTagline, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                pw.Text('*** Visit Again ***', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
              ],
            );
          },
        ),
      );
    } else {
      // Standard A4 Tax Invoice Layout (GST Compliant Modern Format)
      final isInterState = taxDetails?['isInterState'] == true || igst > 0;
      final reverseCharge = (saleData['reverseCharge'] ?? saleData['reverse_charge'] ?? 'No').toString();
      final placeOfSupply = (saleData['placeOfSupply'] ?? saleData['place_of_supply'] ?? storeDetails?['state'] ?? 'Assam').toString();
      final customerAddress = (saleData['customerAddress'] ?? saleData['customer_address'] ?? 'Guwahati - 781008').toString();
      final customerState = (saleData['customerState'] ?? saleData['customer_state'] ?? placeOfSupply).toString();
      final invoiceDateOnly = DateFormat('dd MMM yyyy').format(saleDateTime);

      pw.Font? regularFont;
      pw.Font? boldFont;
      pw.Font? italicFont;
      try {
        regularFont = await PdfGoogleFonts.interRegular();
        boldFont = await PdfGoogleFonts.interBold();
        italicFont = await PdfGoogleFonts.interItalic();
      } catch (_) {
        regularFont = null;
        boldFont = null;
        italicFont = null;
      }
      final currencySymbol = regularFont != null ? '₹' : 'Rs. ';

      final pageTheme = (regularFont != null && boldFont != null)
          ? pw.ThemeData.withFont(
              base: regularFont,
              bold: boldFont,
              italic: italicFont ?? regularFont,
            )
          : pw.ThemeData.base();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pageTheme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          build: (context) {
            return [
              // 1. Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Company / Store Info (Popular Collection)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        storeName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 15,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      if (storePhone.isNotEmpty)
                        pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      if (storeGstin.isNotEmpty)
                        pw.Text('GSTIN: $storeGstin', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey800)),
                    ],
                  ),

                  // Right: Tax Invoice Title & Meta
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                          color: PdfColor.fromHex('#0F172A'),
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('No.: ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                          pw.Text(
                            invoiceNumber,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#0F172A')),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Date: ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                          pw.Text(
                            invoiceDateOnly,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#0F172A')),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('Reverse Charge: ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                          pw.Text(
                            reverseCharge,
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 2. Bill To & Place of Supply Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Bill To
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL TO',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 7.5,
                            color: PdfColor.fromHex('#64748B'),
                            letterSpacing: 0.4,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          customerName,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        if (customerAddress.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(customerAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ),
                        if (customerState.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 1),
                            child: pw.Text(customerState, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ),
                        if (customerPhone.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 1),
                            child: pw.Text('Phone: $customerPhone', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ),
                      ],
                    ),

                    // Place of Supply & Tax Mode Badge
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'PLACE OF SUPPLY',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 7.5,
                            color: PdfColor.fromHex('#64748B'),
                            letterSpacing: 0.4,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          placeOfSupply,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#ECFDF5'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                            border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0'), width: 0.8),
                          ),
                          child: pw.Text(
                            isInterState ? 'Interstate (IGST)' : 'Intrastate (CGST + SGST)',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#065F46'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // 3. GST Itemized Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.6),
                columnWidths: isInterState
                    ? const {
                        0: pw.FlexColumnWidth(0.6), // #
                        1: pw.FlexColumnWidth(4.5), // Description
                        2: pw.FlexColumnWidth(1.4), // HSN/SAC
                        3: pw.FlexColumnWidth(1.2), // Qty
                        4: pw.FlexColumnWidth(1.8), // Rate
                        5: pw.FlexColumnWidth(2.2), // IGST (% & AMT)
                        6: pw.FlexColumnWidth(2.2), // Amount
                      }
                    : const {
                        0: pw.FlexColumnWidth(0.6), // #
                        1: pw.FlexColumnWidth(3.8), // Description
                        2: pw.FlexColumnWidth(1.3), // HSN/SAC
                        3: pw.FlexColumnWidth(1.1), // Qty
                        4: pw.FlexColumnWidth(1.6), // Rate
                        5: pw.FlexColumnWidth(1.8), // CGST (% & AMT)
                        6: pw.FlexColumnWidth(1.8), // SGST (% & AMT)
                        7: pw.FlexColumnWidth(1.9), // Amount
                      },
                children: [
                  // Table Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569')), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569'))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: pw.Text('HSN/SAC', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569')), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569')), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: pw.Text('RATE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569')), textAlign: pw.TextAlign.right),
                      ),
                      if (isInterState)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: pw.Column(
                            children: [
                              pw.Text('IGST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569'))),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('%', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                  pw.Text('AMT', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                ],
                              ),
                            ],
                          ),
                        )
                      else ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: pw.Column(
                            children: [
                              pw.Text('CGST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569'))),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('%', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                  pw.Text('AMT', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: pw.Column(
                            children: [
                              pw.Text('SGST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569'))),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('%', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                  pw.Text('AMT', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: pw.Text('AMOUNT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#475569')), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),

                  // Item Rows
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final it = entry.value;
                    final name = (it['name'] ?? it['item_name'] ?? 'Item').toString();
                    final size = (it['size'] ?? '').toString();
                    final hsn = (it['hsn'] ?? it['hsn_code'] ?? it['hsnCode'] ?? '-').toString();
                    final qty = int.tryParse((it['quantity'] ?? 1).toString()) ?? 1;
                    final price = double.tryParse((it['pricePerPiece'] ?? it['unit_price'] ?? 0).toString()) ?? 0.0;
                    final total = double.tryParse((it['totalPrice'] ?? it['subtotal'] ?? (price * qty)).toString()) ?? 0.0;

                    final itemTaxRate = double.tryParse((it['tax_percent'] ?? it['gst_rate'] ?? (totalTax > 0 && subTotal > 0 ? (totalTax / subTotal * 100).round() : 0)).toString()) ?? 0.0;
                    final cgstPct = itemTaxRate / 2;
                    final sgstPct = itemTaxRate / 2;
                    final cgstAmt = total * (cgstPct / 100);
                    final sgstAmt = total * (sgstPct / 100);
                    final igstAmt = total * (itemTaxRate / 100);

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#0F172A'))),
                              if (size.isNotEmpty && size != '-')
                                pw.Text('Size: $size', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Text(hsn, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Text('$qty Pcs', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Text('$currencySymbol${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                        ),
                        if (isInterState)
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('${itemTaxRate.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7.5)),
                                pw.Text('$currencySymbol${igstAmt.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
                              ],
                            ),
                          )
                        else ...[
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('${cgstPct.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7.5)),
                                pw.Text('$currencySymbol${cgstAmt.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('${sgstPct.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7.5)),
                                pw.Text('$currencySymbol${sgstAmt.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
                              ],
                            ),
                          ),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Text(
                            '$currencySymbol${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 12),

              // 4. Amount in Words & Totals Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Amount in Words & Payment metadata
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'AMOUNT IN WORDS',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 7.5,
                            color: PdfColor.fromHex('#64748B'),
                            letterSpacing: 0.3,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          _numberToIndianWords(grandTotal),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColor.fromHex('#1E293B'),
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          children: [
                            pw.Text('Payment Mode: ', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                            pw.Text('$paymentMethod ($paymentStatus)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColor.fromHex('#047857'))),
                          ],
                        ),
                        if (txnRef.isNotEmpty && txnRef != 'N/A')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text('Txn Ref: $txnRef', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Right: Subtotals, Taxes & Total Due Box
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                            pw.Text('$currencySymbol${subTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                        if (discount > 0) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Discount', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              pw.Text('-$currencySymbol${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red800)),
                            ],
                          ),
                        ],
                        if (isInterState) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('IGST', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              pw.Text('$currencySymbol${(igst > 0 ? igst : totalTax).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                        ] else ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('CGST', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              pw.Text('$currencySymbol${(cgst > 0 ? cgst : totalTax / 2).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('SGST', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              pw.Text('$currencySymbol${(sgst > 0 ? sgst : totalTax / 2).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                        ],
                        pw.SizedBox(height: 8),

                        // Total Due Highlight Container (No purple, premium slate-50/100)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F1F5F9'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Total Due',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10.5,
                                  color: PdfColor.fromHex('#0F172A'),
                                ),
                              ),
                              pw.Text(
                                '$currencySymbol${grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 13,
                                  color: PdfColor.fromHex('#0F172A'),
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
              pw.SizedBox(height: 16),

              // 5. Terms & Conditions and Authorized Signatory
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Retail Store Terms & Conditions
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.7),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TERMS & CONDITIONS',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7.5,
                              color: PdfColor.fromHex('#334155'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('1. Goods once sold can be exchanged within 7 days with the original bill and tags intact.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text('2. No cash refund; exchange or store credit note will be issued for eligible items.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text('3. Discounted or promotional items are final sale and not eligible for return.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text('4. Warranty (if applicable) shall be serviced directly by the manufacturer.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text('5. This invoice is subject to local jurisdiction at the store\'s registered location.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text('6. E. & O.E.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Authorized Signatory
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'For $storeName',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColor.fromHex('#0F172A')),
                        ),
                        pw.SizedBox(height: 34),
                        pw.Container(
                          width: 130,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
                          ),
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text(
                              'Authorized Signatory',
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // 6. Footer Tagline
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(receiptTagline, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('This is a computer generated invoice.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                ],
              ),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Directly sends the invoice to standard print dialog
  static Future<void> printInvoice(
    BuildContext context,
    Map<String, dynamic> saleData, {
    bool isThermal = false,
    Map<String, dynamic>? storeDetails,
  }) async {
    final invoiceNumber = (saleData['invoiceNumber'] ?? saleData['invoice_number'] ?? 'INV').toString();
    final pdfBytes = await generateInvoicePdf(
      saleData,
      isThermal: isThermal,
      storeDetails: storeDetails,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Invoice_$invoiceNumber.pdf',
    );
  }

  /// Downloads the invoice as a formatted PDF file
  static Future<void> downloadInvoice(
    BuildContext context,
    Map<String, dynamic> saleData, {
    bool isThermal = false,
    Map<String, dynamic>? storeDetails,
  }) async {
    final invoiceNumber = (saleData['invoiceNumber'] ?? saleData['invoice_number'] ?? 'INV').toString();
    final pdfBytes = await generateInvoicePdf(
      saleData,
      isThermal: isThermal,
      storeDetails: storeDetails,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_$invoiceNumber.pdf',
    );
  }

  /// Shares invoice via native system share or WhatsApp intent
  static Future<void> shareInvoice(
    BuildContext context,
    Map<String, dynamic> saleData, {
    bool isThermal = false,
    Map<String, dynamic>? storeDetails,
  }) async {
    final invoiceNumber = (saleData['invoiceNumber'] ?? saleData['invoice_number'] ?? 'INV').toString();
    final customerPhone = (saleData['customerPhone'] ?? saleData['customer_phone'] ?? '').toString();
    final grandTotal = (saleData['grandTotal'] ?? saleData['final_amount'] ?? 0).toString();
    final storeName = storeDetails?['store_name'] ?? 'Smart Store';

    try {
      final pdfBytes = await generateInvoicePdf(
        saleData,
        isThermal: isThermal,
        storeDetails: storeDetails,
      );

      // Attempt native file sharing
      final xFile = XFile.fromData(
        pdfBytes,
        name: 'Invoice_$invoiceNumber.pdf',
        mimeType: 'application/pdf',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Tax Invoice $invoiceNumber from $storeName for INR $grandTotal. Thank you!',
          subject: 'Tax Invoice $invoiceNumber',
        ),
      );
    } catch (e) {
      debugPrint('[InvoicePdfHelper] Native share fallback: $e');
      // WhatsApp message fallback
      final cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final message = Uri.encodeComponent(
        'Hello! Here is your invoice $invoiceNumber from $storeName for amount INR $grandTotal.\nPayment Status: PAID via UPI.\nThank you for shopping with us!',
      );
      final waUrl = cleanPhone.isNotEmpty
          ? 'https://wa.me/91$cleanPhone?text=$message'
          : 'https://wa.me/?text=$message';

      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Converts a numeric amount to standard Indian currency words (Lakhs & Crores)
  static String _numberToIndianWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertBelowThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return units[n];
      if (n < 100) {
        final t = tens[n ~/ 10];
        final u = units[n % 10];
        return u.isEmpty ? t : '$t $u';
      }
      final h = units[n ~/ 100];
      final rest = convertBelowThousand(n % 100);
      return rest.isEmpty ? '$h Hundred' : '$h Hundred And $rest';
    }

    int rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    if (rupees == 0 && paise > 0) {
      return '${convertBelowThousand(paise)} Paise Only';
    }

    String result = '';
    // Crores
    if (rupees >= 10000000) {
      final cr = rupees ~/ 10000000;
      result += '${convertBelowThousand(cr)} Crore ';
      rupees %= 10000000;
    }
    // Lakhs
    if (rupees >= 100000) {
      final lk = rupees ~/ 100000;
      result += '${convertBelowThousand(lk)} Lakh ';
      rupees %= 100000;
    }
    // Thousands
    if (rupees >= 1000) {
      final th = rupees ~/ 1000;
      result += '${convertBelowThousand(th)} Thousand ';
      rupees %= 1000;
    }
    // Hundreds and remainder
    if (rupees > 0) {
      result += convertBelowThousand(rupees);
    }

    result = result.trim();
    result = '$result Rupees';
    if (paise > 0) {
      result += ' And ${convertBelowThousand(paise)} Paise';
    }
    return '$result Only';
  }
}
