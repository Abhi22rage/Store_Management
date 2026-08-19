import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:smart_store/src/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:smart_store/src/presentation/screens/dashboard/bloc/dashboard_state.dart';
import 'widgets/custom_range_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showMonthlyRevenue = true;
  bool _hasManuallyToggled = false;
  bool _isAdvancedAnalyticsExpanded = false;
  String? _selectedBarLabel;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardBloc, DashboardState>(
      listener: (context, state) {
        if (state is DashboardLoaded && !_hasManuallyToggled) {
          if (state.isLowStockAlertEnabled && state.lowStockCount > 0) {
            setState(() {
              _showMonthlyRevenue = false;
            });
          }
        }
      },
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, rawState) {
          if (rawState is DashboardError) {
            return Scaffold(body: Center(child: Text(rawState.message)));
          }

          final bool isLoading =
              rawState is DashboardInitial || rawState is DashboardLoading;
          final DashboardLoaded state = rawState is DashboardLoaded
              ? rawState
              : const DashboardLoaded(
                  currentView: SalesPerformanceView.weekly,
                  todaySales: 15000.0,
                  yesterdaySales: 12000.0,
                  monthlySales: 150000.0,
                  lastMonthSales: 120000.0,
                  lowStockCount: 0,
                  totalStockValue: 500000.0,
                  sales: [],
                  performanceData: {
                    'Mon': 1500,
                    'Tue': 2000,
                    'Wed': 1800,
                    'Thu': 2500,
                  },
                  topPerformers: [
                    {
                      'name': 'Sample Product 1',
                      'quantity': 15,
                      'revenue': 4500.0,
                    },
                    {
                      'name': 'Sample Product 2',
                      'quantity': 10,
                      'revenue': 3000.0,
                    },
                  ],
                  monthlyGrossProfit: 35000.0,
                  profitMargin: 25.0,
                  projectedRevenue: 180000.0,
                );

          return Skeletonizer(
            enabled: isLoading,
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
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://img.icons8.com/3d-fluency/94/user-male-circle.png',
                          width: 32,
                          height: 32,
                          placeholder: (context, url) => const Icon(
                            Icons.person,
                            color: AppTheme.accent,
                            size: 24,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: AppTheme.accent,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Popular Collection',
                          style: GoogleFonts.rubik(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.refresh,
                      size: 28,
                      color: AppTheme.primary,
                    ),
                    onPressed: () => context.read<DashboardBloc>().add(
                      const RefreshSalesData(),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.notifications_outlined,
                      size: 28,
                      color: AppTheme.primary,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 26,
                      color: AppTheme.primary,
                    ),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  context.read<DashboardBloc>().add(const RefreshSalesData());
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVERVIEW',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accent,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Executive Dashboard',
                            style: GoogleFonts.rubik(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Stats Section
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 900;
                          final isTablet = constraints.maxWidth > 650;

                          String getPct(
                            double curr,
                            double prev,
                            String suffix,
                          ) {
                            if (prev == 0) {
                              return curr > 0 ? '+100% $suffix' : '0% $suffix';
                            }
                            final d = curr - prev;
                            final p = (d / prev) * 100;
                            return '${p > 0 ? '+' : ''}${p.toStringAsFixed(1)}% $suffix';
                          }

                          final todayChange = getPct(
                            state.todaySales,
                            state.yesterdaySales,
                            'from yesterday',
                          );

                          if (isDesktop) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildValueCard(
                                    'TOTAL SALES TODAY',
                                    '₹${state.todaySales.toStringAsFixed(2)}',
                                    todayChange,
                                    Icons.payments_outlined,
                                    false,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildValueCard(
                                    'TOTAL STOCK VALUE',
                                    '₹${state.totalStockValue.toStringAsFixed(0)}',
                                    'Live Evaluation',
                                    Icons.inventory_2_outlined,
                                    false,
                                  ),
                                ),
                                if (state.isLowStockAlertEnabled) ...[
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMetricCard(context, state),
                                  ),
                                ],
                              ],
                            );
                          } else if (isTablet) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildValueCard(
                                        'TOTAL SALES TODAY',
                                        '₹${state.todaySales.toStringAsFixed(2)}',
                                        todayChange,
                                        Icons.payments_outlined,
                                        false,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildValueCard(
                                        'TOTAL STOCK VALUE',
                                        '₹${state.totalStockValue.toStringAsFixed(0)}',
                                        'Live Evaluation',
                                        Icons.inventory_2_outlined,
                                        false,
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.isLowStockAlertEnabled) ...[
                                  const SizedBox(height: 20),
                                  _buildMetricCard(context, state),
                                ],
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildValueCard(
                                  'TOTAL SALES TODAY',
                                  '₹${state.todaySales.toStringAsFixed(2)}',
                                  todayChange,
                                  Icons.payments_outlined,
                                  false,
                                ),
                                const SizedBox(height: 20),
                                _buildValueCard(
                                  'TOTAL STOCK VALUE',
                                  '₹${state.totalStockValue.toStringAsFixed(0)}',
                                  'Live Evaluation',
                                  Icons.inventory_2_outlined,
                                  false,
                                ),
                                if (state.isLowStockAlertEnabled) ...[
                                  const SizedBox(height: 20),
                                  _buildMetricCard(context, state),
                                ],
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildAdvancedAnalytics(context, state),
                      const SizedBox(height: 32),

                      // Chart Section
                      _buildSalesPerformance(context, state),
                      const SizedBox(height: 32),

                      // Top Performers
                      _buildTopPerformers(context, state),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ), // Closes Scaffold
          ); // Closes Skeletonizer
        },
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : AppTheme.outline,
        ),
      ),
    );
  }

  Widget _buildValueCard(
    String title,
    String value,
    String change,
    IconData icon,
    bool isError, {
    bool isMetric = false,
    String? iconUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F0) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isError
              ? AppTheme.error.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isError
                ? AppTheme.error.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: isError ? 40 : 10,
            offset: Offset(0, isError ? 20 : 4),
          ),
          if (!isError)
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.04),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.outline,
                  letterSpacing: 1.0,
                ),
              ),
              if (isMetric)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton(
                        icon: Icons.analytics_outlined,
                        isSelected: _showMonthlyRevenue,
                        onTap: () => setState(() {
                          _showMonthlyRevenue = true;
                          _hasManuallyToggled = true;
                        }),
                      ),
                      _buildToggleButton(
                        icon: Icons.warning_amber_rounded,
                        isSelected: !_showMonthlyRevenue,
                        onTap: () => setState(() {
                          _showMonthlyRevenue = false;
                          _hasManuallyToggled = true;
                        }),
                      ),
                    ],
                  ),
                )
              else
                Image.network(
                  iconUrl ??
                      (title.contains('SALES')
                          ? 'https://img.icons8.com/3d-fluency/94/money-bag.png'
                          : title.contains('STOCK')
                          ? 'https://img.icons8.com/3d-fluency/94/package.png'
                          : 'https://img.icons8.com/3d-fluency/94/calendar.png'),
                  width: 36,
                  height: 36,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, color: AppTheme.accent, size: 22),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: isError ? AppTheme.error : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                change.startsWith('-')
                    ? Icons.trending_down
                    : (change == 'Live Evaluation'
                          ? Icons.stacked_line_chart
                          : Icons.trending_up),
                size: 16,
                color: change.startsWith('-')
                    ? AppTheme.error
                    : const Color(0xFF059669),
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: change.startsWith('-')
                      ? AppTheme.error
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, DashboardLoaded state) {
    return GestureDetector(
      onTap: () => context.push('/inventory?low_stock=true'),
      child: _buildValueCard(
        'LOW STOCK ALERTS',
        '${state.lowStockCount} ITEMS',
        state.lowStockCount > 0 ? 'Action Required' : 'Inventory Healthy',
        Icons.warning_amber_rounded,
        state.lowStockCount > 0,
      ),
    );
  }

  Widget _buildAdvancedAnalytics(BuildContext context, DashboardLoaded state) {
    String getPct(double curr, double prev, String suffix) {
      if (prev == 0) return curr > 0 ? '+100% $suffix' : '0% $suffix';
      final d = curr - prev;
      final p = (d / prev) * 100;
      return '${p > 0 ? '+' : ''}${p.toStringAsFixed(1)}% $suffix';
    }

    final monthChange = getPct(
      state.monthlySales,
      state.lastMonthSales,
      'vs last month',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isAdvancedAnalyticsExpanded
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isAdvancedAnalyticsExpanded = !_isAdvancedAnalyticsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADVANCED ANALYTICS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isAdvancedAnalyticsExpanded
                                    ? 'Monthly Revenue, Profit & Forecast'
                                    : 'Tap to expand Revenue, Profit & Forecast',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _isAdvancedAnalyticsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cards = [
                    _buildValueCard(
                      'MONTHLY REVENUE',
                      '₹${state.monthlySales.toStringAsFixed(2)}',
                      monthChange,
                      Icons.calendar_today_outlined,
                      false,
                      iconUrl: 'https://img.icons8.com/3d-fluency/94/money-bag.png',
                    ),
                    _buildValueCard(
                      'MONTHLY PROFIT',
                      '₹${state.monthlyGrossProfit.toStringAsFixed(2)}',
                      '${state.profitMargin.toStringAsFixed(1)}% Margin',
                      Icons.trending_up,
                      false,
                      iconUrl: 'https://img.icons8.com/3d-fluency/94/coins.png',
                    ),
                    _buildValueCard(
                      'REVENUE FORECAST',
                      '₹${state.projectedRevenue.toStringAsFixed(0)}',
                      'End of Month Projection',
                      Icons.assessment_outlined,
                      false,
                      iconUrl: 'https://img.icons8.com/3d-fluency/94/graph.png',
                    ),
                  ];

                  if (isMobile) {
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 16),
                        cards[1],
                        const SizedBox(height: 16),
                        cards[2],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
            ),
            crossFadeState: _isAdvancedAnalyticsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  List<double> _calculateYAxisTicks(double maxVal) {
    double rawCeiling = maxVal <= 0 ? 8000.0 : maxVal * 1.15;
    double step;
    if (rawCeiling <= 8000) {
      step = 2000.0;
    } else if (rawCeiling <= 20000) {
      step = 4000.0;
    } else if (rawCeiling <= 50000) {
      step = 10000.0;
    } else if (rawCeiling <= 100000) {
      step = 20000.0;
    } else {
      step = 50000.0;
    }

    double ceiling = (rawCeiling / step).ceil() * step;
    if (ceiling <= 0) ceiling = 8000.0;

    List<double> ticks = [];
    for (double v = ceiling; v >= 0; v -= step) {
      ticks.add(v);
    }
    return ticks;
  }

  String _formatYLabel(double val) {
    if (val == 0) return '0';
    if (val >= 1000) {
      final kVal = val / 1000;
      return '${kVal % 1 == 0 ? kVal.toInt() : kVal.toStringAsFixed(1)}k';
    }
    return val.toInt().toString();
  }

  Widget _buildSalesPerformance(BuildContext context, DashboardLoaded state) {
    final entries = state.performanceData.entries.toList();
    final maxVal = state.performanceData.values.fold(
      0.0,
      (m, e) => e > m ? e : m,
    );
    final ticks = _calculateYAxisTicks(maxVal);
    final yCeiling = ticks.first;

    final now = DateTime.now();
    String? currentLabel;
    String? currentBadgeLabel;
    if (state.currentView == SalesPerformanceView.weekly) {
      final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      currentLabel = days[now.weekday - 1];
      currentBadgeLabel = 'Today';
    } else if (state.currentView == SalesPerformanceView.monthly) {
      final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      currentLabel = months[now.month - 1];
      currentBadgeLabel = 'This Month';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Sales\nPerformance',
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildViewSelector(context, state),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.currentView == SalesPerformanceView.custom &&
              state.customDateRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Range: ${DateFormat('dd MMM').format(state.customDateRange!.start)} - ${DateFormat('dd MMM').format(state.customDateRange!.end)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
            ),

          LayoutBuilder(
            builder: (context, constraints) {
              const yAxisWidth = 24.0;
              final availableChartWidth =
                  constraints.maxWidth - yAxisWidth - 4.0;
              final useExpanded = entries.length <= 8;

              Widget barsRow = Row(
                mainAxisAlignment: useExpanded
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: entries.map((entry) {
                  final factor = yCeiling == 0 ? 0.0 : entry.value / yCeiling;
                  final isSelected = _selectedBarLabel == entry.key;
                  final isPeak = entry.value == maxVal && maxVal > 0;
                  final isCurrent = currentLabel != null && currentLabel == entry.key;

                  Widget barItem = _buildBarColumn(
                    label: entry.key,
                    value: entry.value,
                    heightFactor: factor,
                    isPeak: isPeak,
                    isSelected: isSelected,
                    isCurrent: isCurrent,
                    currentBadgeLabel: currentBadgeLabel,
                    onTap: () {
                      setState(() {
                        if (_selectedBarLabel == entry.key) {
                          _selectedBarLabel = null;
                        } else {
                          _selectedBarLabel = entry.key;
                        }
                      });
                    },
                  );

                  return useExpanded ? Expanded(child: barItem) : barItem;
                }).toList(),
              );

              Widget scrollableBars = !useExpanded
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: barsRow,
                    )
                  : SizedBox(width: availableChartWidth, child: barsRow);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Y-Axis Column
                  SizedBox(
                    width: yAxisWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 30), // 24px badge + 6px gap
                        SizedBox(
                          height: 160, // Larger bar canvas height
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: ticks
                                .map(
                                  (t) => Text(
                                    _formatYLabel(t),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.outline,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24), // 8px gap + 16px label
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chart Canvas (Bars + Grid lines)
                  Expanded(
                    child: Stack(
                      children: [
                        // Background Horizontal Grid Lines
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 30,
                          height: 160,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ticks
                                .map(
                                  (_) => Container(
                                    height: 1,
                                    color: AppTheme.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        scrollableBars,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector(BuildContext context, DashboardLoaded state) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _viewOption(
              context,
              'Weekly',
              SalesPerformanceView.weekly,
              state.currentView == SalesPerformanceView.weekly,
            ),
            _viewOption(
              context,
              'Monthly',
              SalesPerformanceView.monthly,
              state.currentView == SalesPerformanceView.monthly,
            ),
            _viewOption(
              context,
              'Custom',
              SalesPerformanceView.custom,
              state.currentView == SalesPerformanceView.custom,
              onCustom: () async {
                final range = await showDialog<DateTimeRange>(
                  context: context,
                  builder: (context) => CustomRangePicker(
                    initialStart:
                        state.customDateRange?.start ??
                        DateTime.now().subtract(const Duration(days: 30)),
                    initialEnd: state.customDateRange?.end ?? DateTime.now(),
                  ),
                );
                if (range != null && context.mounted) {
                  context.read<DashboardBloc>().add(SetCustomRange(range));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewOption(
    BuildContext context,
    String label,
    SalesPerformanceView view,
    bool isSelected, {
    VoidCallback? onCustom,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBarLabel = null;
        });
        if (view == SalesPerformanceView.custom && onCustom != null) {
          onCustom();
        } else {
          context.read<DashboardBloc>().add(ChangeSalesView(view));
        }
      },
      // selector container
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF767683),
          ),
        ),
      ),
    );
  }

  Widget _buildBarColumn({
    required String label,
    required double value,
    required double heightFactor,
    required bool isPeak,
    required bool isSelected,
    required bool isCurrent,
    required String? currentBadgeLabel,
    required VoidCallback onTap,
  }) {
    final formattedVal = '₹${NumberFormat('#,##,##0').format(value)}';
    final calcHeight =
        160.0 *
        (heightFactor < 0.03 && heightFactor > 0
            ? 0.03
            : (heightFactor == 0 ? 0.02 : heightFactor));

    String? badgeText;
    if (isCurrent && isPeak) {
      badgeText = '$currentBadgeLabel • Peak';
    } else if (isCurrent) {
      badgeText = currentBadgeLabel;
    } else if (isPeak) {
      badgeText = 'Peak';
    }

    Color barColor;
    if (isSelected) {
      barColor = AppTheme.accent;
    } else if (isCurrent) {
      barColor = const Color(0xFF006A60); // Highlight current day/month in rich teal
    } else if (isPeak) {
      barColor = const Color(0xFF3F51B5); // Highlight Peak in deep indigo
    } else {
      barColor = const Color(0xFFC2C7FD);
    }

    Color badgeColor;
    if (isCurrent) {
      badgeColor = const Color(0xFF006A60);
    } else {
      badgeColor = const Color(0xFF000666);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge (Fixed Height 24)
            SizedBox(
              height: 24,
              child: Center(
                child: badgeText != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          softWrap: false,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),

            // Bar Canvas (Fixed Height 160, Bottom Aligned with floating Tooltip Popover)
            SizedBox(
              height: 160,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (isSelected || isCurrent) ? 38 : 34,
                    height: calcHeight,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppTheme.primary, width: 2.5)
                          : (isCurrent
                              ? Border.all(color: const Color(0xFF004D40), width: 1.5)
                              : null),
                      boxShadow: (isSelected || isCurrent || isPeak)
                          ? [
                              BoxShadow(
                                color: barColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                  ),

                  // Dynamic Pop-up Tooltip directly above the selected bar
                  if (isSelected)
                    Positioned(
                      bottom: calcHeight + 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  formattedVal,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomPaint(
                            size: const Size(8, 4),
                            painter: _TooltipTrianglePainter(
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // X-Axis Label (Fixed Height 16)
            SizedBox(
              height: 16,
              child: Center(
                child: Container(
                  padding: isCurrent
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                      : EdgeInsets.zero,
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: const Color(0xFF006A60).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: (isSelected || isCurrent)
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected
                          ? AppTheme.primary
                          : (isCurrent
                              ? const Color(0xFF006A60)
                              : AppTheme.outline),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformers(BuildContext context, DashboardLoaded state) {
    final performers = state.topPerformers;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Performers',
                style: GoogleFonts.rubik(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'By Units Sold',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (performers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: AppTheme.outline.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No sales recorded yet',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(performers.length, (i) {
              final item = performers[i];
              final isLast = i == performers.length - 1;
              return Column(
                children: [
                  _buildPerformerItem(
                    rank: i + 1,
                    name: item['name'] as String,
                    quantity: item['quantity'] as int,
                    revenue: item['revenue'] as double,
                    unitPrice: (item['unitPrice'] as double?) ?? (item['quantity'] > 0 ? (item['revenue'] as double) / (item['quantity'] as int) : 0.0),
                  ),
                  if (!isLast)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFF2F4F5), height: 1),
                    ),
                ],
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPerformerItem({
    required int rank,
    required String name,
    required int quantity,
    required double revenue,
    required double unitPrice,
  }) {
    // Gold / Silver / Bronze for top 3, neutral for rest
    final rankColors = [
      const Color(0xFFFFB800), // #1 gold
      const Color(0xFF8E9BAE), // #2 silver
      const Color(0xFFB07040), // #3 bronze
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : AppTheme.outline;

    return Row(
      children: [
        // Rank badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: rankColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Item icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.network(
            'https://img.icons8.com/3d-fluency/94/t-shirt.png',
            width: 28,
            height: 28,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.checkroom_outlined,
              color: Color(0xFF767683),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Name + quantity & unit price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$quantity units sold${unitPrice > 0 ? ' • ₹${unitPrice.toStringAsFixed(0)}/pc' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF767683),
                ),
              ),
            ],
          ),
        ),
        // Revenue
        Text(
          '₹${revenue.toStringAsFixed(0)}',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _TooltipTrianglePainter extends CustomPainter {
  final Color color;
  const _TooltipTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
