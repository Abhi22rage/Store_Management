import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DataRepository _repository = DataRepository();

  DashboardBloc() : super(DashboardInitial()) {
    on<FetchDashboardData>((event, emit) => _onLoadData(emit));
    on<RefreshSalesData>((event, emit) => _onLoadData(emit));
    on<ChangeSalesView>(_onChangeView);
    on<SetCustomRange>(_onSetCustomRange);

    BranchService().addListener(_onBranchChanged);
    _repository.addListener(_onRepositoryChanged);
  }

  void _onBranchChanged() {
    add(const FetchDashboardData());
  }

  void _onRepositoryChanged() {
    add(const FetchDashboardData());
  }

  @override
  Future<void> close() {
    BranchService().removeListener(_onBranchChanged);
    _repository.removeListener(_onRepositoryChanged);
    return super.close();
  }

  Future<void> _onLoadData(Emitter<DashboardState> emit) async {
    try {
      final currentBranch = BranchService().currentBranch;
      final cachedInv = _repository.getCachedInventory(currentBranch);
      final cachedSales = _repository.getCachedSales(currentBranch);
      final hasCache = (cachedInv != null && cachedInv.isNotEmpty) || (cachedSales != null && cachedSales.isNotEmpty);

      if (!hasCache) {
        emit(DashboardLoading());
      }

      final prefs = await SharedPreferences.getInstance();
      double threshold = prefs.getDouble('low_stock_threshold') ?? 10.0;
      bool alertEnabled = prefs.getBool('low_stock_alert_enabled') ?? true;

      final results = await Future.wait([
        _repository.getInventory(branch: currentBranch),
        _repository.getSales(branch: currentBranch),
      ]);
      final inventory = results[0];
      final sales = results[1];

      int count = 0;
      double totalValue = 0;
      for (var item in inventory) {
        final itemThreshold =
            double.tryParse(
              item['lowStockThreshold']?.toString() ??
                  item['minStockThreshold']?.toString() ??
                  '',
            ) ??
            threshold;
        final stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
        if (stock <= itemThreshold) {
          count++;
        }
        final price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
        totalValue += price * stock;
      }
      final now = DateTime.now();

      final currentViewState = (state is DashboardInitial || state is DashboardLoading)
        ? SalesPerformanceView.weekly
        : (state is DashboardLoaded) ? (state as DashboardLoaded).currentView : SalesPerformanceView.weekly;
      
      final currentRange = (state is DashboardLoaded)
        ? (state as DashboardLoaded).customDateRange
        : null;

      final performanceData = _calculatePerformance(sales, currentViewState, currentRange);

      double todayTotal = 0;
      double yesterdayTotal = 0;
      double monthlyTotal = 0;
      double lastMonthTotal = 0;
      double monthlyProfit = 0;
      
      // Cost price & Name lookup maps from inventory
      final Map<String, double> costPrices = {};
      final Map<String, double> costByName = {};
      for (var item in inventory) {
        final idStr = item['id']?.toString() ?? '';
        final nameKey = (item['name']?.toString() ?? '').toLowerCase().trim();
        final cost = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        if (idStr.isNotEmpty) costPrices[idStr] = cost;
        if (nameKey.isNotEmpty) costByName[nameKey] = cost;
      }
      
      final prevDay = now.subtract(const Duration(days: 1));
      final lastMonthDate = DateTime(now.year, now.month - 1); // wraps to December if month is 1

      for (var sale in sales) {
        final dateStr = sale['createdAt'] ?? sale['date'];
        if (dateStr == null) continue;
        final saleDate = DateTime.parse(dateStr.toString()).toLocal();
        final amountStr = sale['grandTotal'] ?? sale['totalAmount'] ?? '0';
        final amount = double.tryParse(amountStr.toString()) ?? 0.0;
        
        // This Month
        if (saleDate.year == now.year && saleDate.month == now.month) {
          monthlyTotal += amount;
          if (saleDate.day == now.day) {
            todayTotal += amount;
          }
        }
        
        // Yesterday
        if (saleDate.year == prevDay.year && saleDate.month == prevDay.month && saleDate.day == prevDay.day) {
          yesterdayTotal += amount;
        }

        // Last Month
        if (saleDate.year == lastMonthDate.year && saleDate.month == lastMonthDate.month) {
          lastMonthTotal += amount;
        }

        // Monthly Profit Calculation
        if (saleDate.year == now.year && saleDate.month == now.month) {
          final List<dynamic> saleItems = (sale['items'] is List && (sale['items'] as List).isNotEmpty)
              ? (sale['items'] as List)
              : ((sale['sale_items'] is List) ? (sale['sale_items'] as List) : []);

          for (var si in saleItems) {
            final itemDetails = si is Map && si.containsKey('items') && si['items'] is Map ? si['items'] : si;
            final id = (itemDetails['itemId'] ?? itemDetails['item_id'] ?? itemDetails['id'])?.toString();
            final nameKey = (itemDetails['name'] ?? '').toString().toLowerCase().trim();
            final qty = int.tryParse((si['quantity'] ?? itemDetails['quantity'] ?? '0').toString()) ?? 0;
            if (qty <= 0) continue;

            final sell = double.tryParse(
              (si['unit_price'] ?? si['pricePerPiece'] ?? si['price'] ?? itemDetails['retailPrice'] ?? itemDetails['price'] ?? 0).toString(),
            ) ?? 0.0;

            // Multi-layer cost price resolution
            double cost = double.tryParse(
              (si['costPrice'] ?? si['cost_price'] ?? itemDetails['costPrice'] ?? itemDetails['price'] ?? 0).toString(),
            ) ?? 0.0;

            if (cost <= 0 && id != null && costPrices.containsKey(id)) {
              cost = costPrices[id]!;
            }
            if (cost <= 0 && nameKey.isNotEmpty && costByName.containsKey(nameKey)) {
              cost = costByName[nameKey]!;
            }

            // Profit = (selling price - cost price) * quantity
            final profitPerUnit = (sell > cost && cost > 0) ? (sell - cost) : (sell * 0.20);
            monthlyProfit += profitPerUnit * qty;
          }
        }
      }

      // Projections & Margins
      final margin = monthlyTotal > 0 ? (monthlyProfit / monthlyTotal) * 100 : 0.0;
      
      // Revenue Projection (simple linear)
      final daysPassed = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final projectedRevenue = (monthlyTotal / daysPassed) * daysInMonth;

      final topPerformers = _calculateTopPerformers(sales, inventory);

      emit(DashboardLoaded(
        currentView: currentViewState,
        customDateRange: currentRange,
        todaySales: todayTotal,
        yesterdaySales: yesterdayTotal,
        monthlySales: monthlyTotal,
        lastMonthSales: lastMonthTotal,
        lowStockCount: alertEnabled ? count : 0,
        isLowStockAlertEnabled: alertEnabled,
        totalStockValue: totalValue,
        sales: sales,
        performanceData: performanceData,
        topPerformers: topPerformers,
        monthlyGrossProfit: monthlyProfit,
        profitMargin: margin,
        projectedRevenue: projectedRevenue,
      ));
      } catch (e) {
      String errorMessage = 'Error loading dashboard: $e';
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        errorMessage =
            'Unable to connect to Smart Store cloud. Please check your internet connection and refresh.';
      }
      emit(DashboardError(errorMessage));
    }
  }

  void _onChangeView(ChangeSalesView event, Emitter<DashboardState> emit) {
    if (state is DashboardLoaded) {
      final s = state as DashboardLoaded;
      final performanceData = _calculatePerformance(s.sales, event.view, s.customDateRange);
      emit(s.copyWith(currentView: event.view, performanceData: performanceData));
    }
  }

  void _onSetCustomRange(SetCustomRange event, Emitter<DashboardState> emit) {
    if (state is DashboardLoaded) {
      final s = state as DashboardLoaded;
      final performanceData = _calculatePerformance(s.sales, SalesPerformanceView.custom, event.range);
      emit(s.copyWith(
        currentView: SalesPerformanceView.custom, 
        customDateRange: event.range, 
        performanceData: performanceData
      ));
    }
  }

  /// Aggregates all sale line-items, groups by item name, sums quantity + revenue.
  /// Cross-references inventory retail prices for exact calculation.
  /// Returns the top 5 items sorted by quantity descending.
  List<Map<String, dynamic>> _calculateTopPerformers(List<dynamic> sales, List<dynamic> inventory) {
    final Map<String, Map<String, dynamic>> aggregated = {};

    // Build retail selling price lookup maps from inventory
    final Map<String, double> inventoryRetailPrices = {};
    final Map<String, double> inventoryRetailByName = {};

    for (var item in inventory) {
      final idStr = item['id']?.toString() ?? '';
      final nameKey = (item['name']?.toString() ?? '').toLowerCase().trim();
      final retPrice = double.tryParse(item['retailPrice']?.toString() ?? '0') ?? 0.0;
      final costPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final effectiveRetail = retPrice > 0 ? retPrice : (costPrice > 0 ? costPrice * 2.0 : 0.0);

      if (idStr.isNotEmpty && effectiveRetail > 0) {
        inventoryRetailPrices[idStr] = effectiveRetail;
      }
      if (nameKey.isNotEmpty && effectiveRetail > 0) {
        inventoryRetailByName[nameKey] = effectiveRetail;
      }
    }

    for (final sale in sales) {
      final items = sale['items'];
      if (items == null || items is! List) continue;

      for (final item in items) {
        final name = item['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;

        final qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        if (qty <= 0) continue;

        final idStr = item['itemId']?.toString() ?? item['id']?.toString() ?? '';
        final nameKey = name.toLowerCase();

        // 1st priority: sale item pricePerPiece / retailPrice
        double unitSellingPrice = double.tryParse(
          (item['pricePerPiece'] ?? item['retailPrice'] ?? item['unitPrice'] ?? 0).toString(),
        ) ?? 0.0;

        // 2nd priority: inventory retail price lookup by ID
        if (unitSellingPrice <= 0 && idStr.isNotEmpty && inventoryRetailPrices.containsKey(idStr)) {
          unitSellingPrice = inventoryRetailPrices[idStr]!;
        }

        // 3rd priority: inventory retail price lookup by Name
        if (unitSellingPrice <= 0 && nameKey.isNotEmpty && inventoryRetailByName.containsKey(nameKey)) {
          unitSellingPrice = inventoryRetailByName[nameKey]!;
        }

        // 4th priority: fallback item price
        if (unitSellingPrice <= 0) {
          unitSellingPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        }

        final double lineRevenue = qty * unitSellingPrice;

        if (aggregated.containsKey(name)) {
          aggregated[name]!['quantity'] = (aggregated[name]!['quantity'] as int) + qty;
          aggregated[name]!['revenue'] = (aggregated[name]!['revenue'] as double) + lineRevenue;
          if (unitSellingPrice > 0) {
            aggregated[name]!['unitPrice'] = unitSellingPrice;
          }
        } else {
          aggregated[name] = {
            'name': name,
            'quantity': qty,
            'revenue': lineRevenue,
            'unitPrice': unitSellingPrice,
          };
        }
      }
    }

    final sorted = aggregated.values.toList()
      ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

    return sorted.take(5).toList().cast<Map<String, dynamic>>();
  }

  Map<String, double> _calculatePerformance(List<dynamic> sales, SalesPerformanceView view, DateTimeRange? range) {
    final Map<String, double> data = {};
    final now = DateTime.now();

    switch (view) {
      case SalesPerformanceView.weekly:
        // Last 7 days
        final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        for (var d in days) {
          data[d] = 0.0;
        }
        for (var sale in sales) {
          final dateStr = sale['createdAt'] ?? sale['date'];
          if (dateStr == null) continue;
          final date = DateTime.parse(dateStr.toString()).toLocal();
          final amountStr = sale['grandTotal'] ?? sale['totalAmount'] ?? '0';
          final amount = double.tryParse(amountStr.toString()) ?? 0.0;

          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          if (date.isAfter(startOfWeek.subtract(const Duration(minutes: 1)))) {
            final label = days[date.weekday - 1];
            data[label] = (data[label] ?? 0) + amount;
          }
        }
        break;

      case SalesPerformanceView.monthly:
        // Show 12 months starting from January (JAN to DEC)
        final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
        for (var label in months) {
          data[label] = 0.0;
        }
        for (var sale in sales) {
          final dateStr = sale['createdAt'] ?? sale['date'];
          if (dateStr == null) continue;
          final date = DateTime.parse(dateStr.toString()).toLocal();
          final amountStr = sale['grandTotal'] ?? sale['totalAmount'] ?? '0';
          final amount = double.tryParse(amountStr.toString()) ?? 0.0;

          final yearDiff = now.year - date.year;
          final monthDiff = (yearDiff * 12) + (now.month - date.month);
          if (monthDiff < 12 && monthDiff >= 0) {
            final label = months[date.month - 1];
            data[label] = (data[label] ?? 0) + amount;
          }
        }
        break;

      case SalesPerformanceView.custom:
        if (range != null) {
          final diffInDays = range.end.difference(range.start).inDays;
          
          if (diffInDays <= 62) {
            // Less than or equal to 2 months -> WEEKLY Breakdown (W1, W2, etc.)
            final numWeeks = (diffInDays / 7).ceil();
            for (int i = 1; i <= numWeeks; i++) {
              data['W$i'] = 0.0;
            }
            for (var sale in sales) {
              final dateStr = sale['createdAt'] ?? sale['date'];
              if (dateStr == null) continue;
              final date = DateTime.parse(dateStr.toString()).toLocal();
              final amountStr = sale['grandTotal'] ?? sale['totalAmount'] ?? '0';
              final amount = double.tryParse(amountStr.toString()) ?? 0.0;

              if (date.isAfter(range.start.subtract(const Duration(minutes: 1))) &&
                  date.isBefore(range.end.add(const Duration(days: 1)))) {
                final dayOffset = date.difference(range.start).inDays;
                final weekNum = (dayOffset / 7).floor() + 1;
                final label = 'W$weekNum';
                if (data.containsKey(label)) {
                  data[label] = (data[label] ?? 0) + amount;
                }
              }
            }
          } else {
            // More than 2 months -> MONTHLY Breakdown (JAN, FEB, etc.)
            final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
            // Initialize months in range
            DateTime temp = DateTime(range.start.year, range.start.month);
            while (temp.isBefore(range.end) || (temp.year == range.end.year && temp.month == range.end.month)) {
              final label = '${months[temp.month - 1]} ${temp.year.toString().substring(2)}';
              data[label] = 0.0;
              temp = DateTime(temp.year, temp.month + 1);
            }

            for (var sale in sales) {
              final dateStr = sale['createdAt'] ?? sale['date'];
              if (dateStr == null) continue;
              final date = DateTime.parse(dateStr.toString()).toLocal();
              final amountStr = sale['grandTotal'] ?? sale['totalAmount'] ?? '0';
              final amount = double.tryParse(amountStr.toString()) ?? 0.0;

              if (date.isAfter(range.start.subtract(const Duration(minutes: 1))) &&
                  date.isBefore(range.end.add(const Duration(days: 1)))) {
                final label = '${months[date.month - 1]} ${date.year.toString().substring(2)}';
                if (data.containsKey(label)) {
                  data[label] = (data[label] ?? 0) + amount;
                }
              }
            }
          }
        }
        break;
    }
    return data;
  }
}
