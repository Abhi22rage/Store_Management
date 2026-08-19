import 'package:csv/csv.dart' as csv_pkg;
import 'package:excel/excel.dart' as excel_pkg;

class ExportService {
  static String inventoryToCsv(List<dynamic> items) {
    const header = [
      'ID',
      'Name',
      'Category',
      'Subcategory',
      'Cost Price',
      'Retail Price',
      'Stock',
      'Color',
      'Size',
      'Branch',
      'Created At',
    ];

    final rows = items
        .map(
          (item) => [
            item['id']?.toString() ?? '',
            item['name']?.toString() ?? '',
            item['category']?.toString() ?? '',
            item['subcategory']?.toString() ?? '',
            item['price']?.toString() ?? '0',
            item['retailPrice']?.toString() ?? '0',
            item['stock']?.toString() ?? '0',
            item['color']?.toString() ?? '',
            item['size']?.toString() ?? '',
            item['branch']?.toString() ?? '',
            item['createdAt']?.toString() ?? '',
          ],
        )
        .toList();

    return csv_pkg.Csv().encode([header, ...rows]);
  }

  static String salesToCsv(List<dynamic> sales) {
    const header = [
      'Invoice Number',
      'Date',
      'Customer Name',
      'Customer Phone',
      'Items Count',
      'Sub Total',
      'Discount',
      'Grand Total',
      'Payment Method',
      'Branch',
    ];

    final rows = sales.map((sale) {
      final items = sale['items'] as List? ?? [];
      return [
        sale['invoiceNumber']?.toString() ?? sale['id']?.toString() ?? '',
        sale['date']?.toString() ?? sale['createdAt']?.toString() ?? '',
        sale['customerName']?.toString() ?? 'Walk-in Customer',
        sale['customerPhone']?.toString() ?? '',
        items.length.toString(),
        sale['subTotal']?.toString() ?? sale['totalAmount']?.toString() ?? '0',
        sale['discount']?.toString() ?? '0',
        sale['grandTotal']?.toString() ??
            sale['totalAmount']?.toString() ??
            '0',
        sale['paymentMethod']?.toString() ?? 'Cash',
        sale['branch']?.toString() ?? '',
      ];
    }).toList();

    return csv_pkg.Csv().encode([header, ...rows]);
  }

  static String purchasesToCsv(List<dynamic> purchases) {
    const header = [
      'Purchase Number',
      'Date',
      'Supplier',
      'Items Count',
      'Sub Total',
      'Discount',
      'Grand Total',
      'Payment Method',
      'Status',
      'Branch',
    ];

    final rows = purchases.map((purchase) {
      final items = purchase['items'] as List? ?? [];
      return [
        purchase['purchaseNumber']?.toString() ?? '',
        purchase['date']?.toString() ?? purchase['createdAt']?.toString() ?? '',
        purchase['supplierName']?.toString() ?? 'Unknown',
        items.length.toString(),
        purchase['subTotal']?.toString() ?? '0',
        purchase['discount']?.toString() ?? '0',
        purchase['grandTotal']?.toString() ?? '0',
        purchase['paymentMethod']?.toString() ?? 'Cash',
        purchase['status']?.toString() ?? 'Received',
        purchase['branch']?.toString() ?? '',
      ];
    }).toList();

    return csv_pkg.Csv().encode([header, ...rows]);
  }

  static String suppliersToCsv(List<dynamic> suppliers) {
    const header = [
      'ID',
      'Name',
      'Phone',
      'Email',
      'GSTIN',
      'Address',
      'Branch',
    ];

    final rows = suppliers
        .map(
          (supplier) => [
            supplier['id']?.toString() ?? '',
            supplier['name']?.toString() ?? '',
            supplier['phone']?.toString() ?? '',
            supplier['email']?.toString() ?? '',
            supplier['gstin']?.toString() ?? '',
            supplier['address']?.toString() ?? '',
            supplier['branch']?.toString() ?? '',
          ],
        )
        .toList();

    return csv_pkg.Csv().encode([header, ...rows]);
  }

  static Future<List<int>> inventoryToXlsx(List<dynamic> items) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Inventory'];

    sheet.appendRow([
      excel_pkg.TextCellValue('ID'),
      excel_pkg.TextCellValue('Name'),
      excel_pkg.TextCellValue('Category'),
      excel_pkg.TextCellValue('Subcategory'),
      excel_pkg.TextCellValue('Cost Price'),
      excel_pkg.TextCellValue('Retail Price'),
      excel_pkg.TextCellValue('Stock'),
      excel_pkg.TextCellValue('Color'),
      excel_pkg.TextCellValue('Size'),
      excel_pkg.TextCellValue('Branch'),
    ]);

    for (final item in items) {
      sheet.appendRow([
        excel_pkg.TextCellValue(item['id']?.toString() ?? ''),
        excel_pkg.TextCellValue(item['name']?.toString() ?? ''),
        excel_pkg.TextCellValue(item['category']?.toString() ?? ''),
        excel_pkg.TextCellValue(item['subcategory']?.toString() ?? ''),
        excel_pkg.DoubleCellValue(
          double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.DoubleCellValue(
          double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.IntCellValue(
          int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.TextCellValue(item['color']?.toString() ?? ''),
        excel_pkg.TextCellValue(item['size']?.toString() ?? ''),
        excel_pkg.TextCellValue(item['branch']?.toString() ?? ''),
      ]);
    }

    return excel.encode()!;
  }

  static Future<List<int>> salesToXlsx(List<dynamic> sales) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Sales'];

    sheet.appendRow([
      excel_pkg.TextCellValue('Invoice Number'),
      excel_pkg.TextCellValue('Date'),
      excel_pkg.TextCellValue('Customer Name'),
      excel_pkg.TextCellValue('Customer Phone'),
      excel_pkg.TextCellValue('Items Count'),
      excel_pkg.TextCellValue('Sub Total'),
      excel_pkg.TextCellValue('Discount'),
      excel_pkg.TextCellValue('Grand Total'),
      excel_pkg.TextCellValue('Payment Method'),
      excel_pkg.TextCellValue('Branch'),
    ]);

    for (final sale in sales) {
      final items = sale['items'] as List? ?? [];
      sheet.appendRow([
        excel_pkg.TextCellValue(sale['invoiceNumber']?.toString() ?? ''),
        excel_pkg.TextCellValue(sale['date']?.toString() ?? ''),
        excel_pkg.TextCellValue(sale['customerName']?.toString() ?? ''),
        excel_pkg.TextCellValue(sale['customerPhone']?.toString() ?? ''),
        excel_pkg.IntCellValue(items.length),
        excel_pkg.DoubleCellValue(
          double.tryParse(sale['subTotal']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.DoubleCellValue(
          double.tryParse(sale['discount']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.DoubleCellValue(
          double.tryParse(sale['grandTotal']?.toString() ?? '0') ?? 0,
        ),
        excel_pkg.TextCellValue(sale['paymentMethod']?.toString() ?? 'Cash'),
        excel_pkg.TextCellValue(sale['branch']?.toString() ?? ''),
      ]);
    }

    return excel.encode()!;
  }
}
