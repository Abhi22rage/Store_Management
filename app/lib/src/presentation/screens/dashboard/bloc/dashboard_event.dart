import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'dashboard_state.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class FetchDashboardData extends DashboardEvent {
  const FetchDashboardData();
}

class ChangeSalesView extends DashboardEvent {
  final SalesPerformanceView view;
  const ChangeSalesView(this.view);

  @override
  List<Object?> get props => [view];
}

class SetCustomRange extends DashboardEvent {
  final DateTimeRange range;
  const SetCustomRange(this.range);

  @override
  List<Object?> get props => [range];
}

class RefreshSalesData extends DashboardEvent {
  const RefreshSalesData();
}
