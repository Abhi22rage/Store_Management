import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SalesPerformanceView { weekly, monthly, custom }

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final SalesPerformanceView currentView;
  final DateTimeRange? customDateRange;
  final double todaySales;
  final double yesterdaySales;
  final double monthlySales;
  final double lastMonthSales;
  final int lowStockCount;
  final bool isLowStockAlertEnabled;
  final double totalStockValue;
  final List<dynamic> sales;
  final Map<String, double> performanceData;
  final List<Map<String, dynamic>> topPerformers;
  final double monthlyGrossProfit;
  final double profitMargin;
  final double projectedRevenue;

  const DashboardLoaded({
    required this.currentView,
    this.customDateRange,
    required this.todaySales,
    required this.yesterdaySales,
    required this.monthlySales,
    required this.lastMonthSales,
    required this.lowStockCount,
    this.isLowStockAlertEnabled = true,
    required this.totalStockValue,
    required this.sales,
    required this.performanceData,
    this.topPerformers = const [],
    this.monthlyGrossProfit = 0.0,
    this.profitMargin = 0.0,
    this.projectedRevenue = 0.0,
  });

  @override
  List<Object?> get props => [
    currentView, 
    customDateRange, 
    todaySales, 
    yesterdaySales,
    monthlySales, 
    lastMonthSales,
    lowStockCount, 
    isLowStockAlertEnabled,
    totalStockValue,
    sales, 
    performanceData,
    topPerformers,
    monthlyGrossProfit,
    profitMargin,
    projectedRevenue,
  ];

  DashboardLoaded copyWith({
    SalesPerformanceView? currentView,
    DateTimeRange? customDateRange,
    double? todaySales,
    double? yesterdaySales,
    double? monthlySales,
    double? lastMonthSales,
    int? lowStockCount,
    bool? isLowStockAlertEnabled,
    double? totalStockValue,
    List<dynamic>? sales,
    Map<String, double>? performanceData,
    List<Map<String, dynamic>>? topPerformers,
    double? monthlyGrossProfit,
    double? profitMargin,
    double? projectedRevenue,
  }) {
    return DashboardLoaded(
      currentView: currentView ?? this.currentView,
      customDateRange: customDateRange ?? this.customDateRange,
      todaySales: todaySales ?? this.todaySales,
      yesterdaySales: yesterdaySales ?? this.yesterdaySales,
      monthlySales: monthlySales ?? this.monthlySales,
      lastMonthSales: lastMonthSales ?? this.lastMonthSales,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      isLowStockAlertEnabled: isLowStockAlertEnabled ?? this.isLowStockAlertEnabled,
      totalStockValue: totalStockValue ?? this.totalStockValue,
      sales: sales ?? this.sales,
      performanceData: performanceData ?? this.performanceData,
      topPerformers: topPerformers ?? this.topPerformers,
      monthlyGrossProfit: monthlyGrossProfit ?? this.monthlyGrossProfit,
      profitMargin: profitMargin ?? this.profitMargin,
      projectedRevenue: projectedRevenue ?? this.projectedRevenue,
    );
  }
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
