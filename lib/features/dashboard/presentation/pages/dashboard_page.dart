import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/best_sellers.dart';
import '../widgets/sales_chart.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../services/supabase_service.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final SupabaseOrderService _orderService = SupabaseOrderService();
  String _selectedTimeFrame = 'Today';
  String _selectedBranch = 'All Branches';
  String _selectedGroupBy = 'Hour';
  bool _sortByRevenue = true;

  Map<String, dynamic>? _currentStats;
  Map<String, dynamic>? _previousStats;
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _salesChartData = [];
  bool _isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadSalesChartData();
  }

  Future<void> _loadStatistics() async {
    if (mounted) {
      setState(() {
        _isLoadingStats = true;
      });
    }

    final dateRanges = _getDateRangesForTimeFrame(_selectedTimeFrame);

    try {
      final currentStats = await _orderService.getOrderStatistics(
        startDate: dateRanges['currentStart'],
        endDate: dateRanges['currentEnd'],
      );

      final previousStats = await _orderService.getOrderStatistics(
        startDate: dateRanges['previousStart'],
        endDate: dateRanges['previousEnd'],
      );

      if (mounted) {
        setState(() {
          _currentStats = currentStats;
          _previousStats = previousStats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadSalesChartData() async {
    if (mounted) {
      setState(() {
        _isLoadingChart = true;
      });
    }

    final dateRanges = _getDateRangesForTimeFrame(_selectedTimeFrame);

    try {
      // Convert groupBy from UI format to service format
      String serviceGroupBy;
      switch (_selectedGroupBy) {
        case 'Hour':
          serviceGroupBy = 'hour';
          break;
        case 'Week day':
          serviceGroupBy = 'day'; // Group by day then we'll aggregate by weekday
          break;
        case 'Day':
        default:
          serviceGroupBy = 'day';
          break;
      }

      final chartData = await _orderService.getSalesChartData(
        startDate: dateRanges['currentStart'],
        endDate: dateRanges['currentEnd'],
        groupBy: serviceGroupBy,
      );

      if (mounted) {
        setState(() {
          _salesChartData = chartData;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      print('Error loading sales chart data: $e');
      if (mounted) {
        setState(() {
          _salesChartData = [];
          _isLoadingChart = false;
        });
      }
    }
  }

  Map<String, DateTime> _getDateRangesForTimeFrame(String timeFrame) {
    final now = DateTime.now();
    DateTime currentStart, currentEnd, previousStart, previousEnd;

    switch (timeFrame) {
      case 'Today':
        currentStart = DateTime(now.year, now.month, now.day);
        currentEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        previousStart = DateTime(now.year, now.month, now.day - 1);
        previousEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        currentStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
        currentEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentEnd.subtract(const Duration(days: 7));
        break;
      case 'This Month':
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'Last 30 Days':
        currentStart = now.subtract(const Duration(days: 30));
        currentEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        previousStart = currentStart.subtract(const Duration(days: 30));
        previousEnd = currentStart.subtract(const Duration(days: 1));
        break;
      default:
        currentStart = DateTime(now.year, now.month, now.day);
        currentEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        previousStart = DateTime(now.year, now.month, now.day - 1);
        previousEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
    }

    return {
      'currentStart': currentStart,
      'currentEnd': currentEnd,
      'previousStart': previousStart,
      'previousEnd': previousEnd,
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(userDisplayNameProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadStatistics(),
            _loadSalesChartData(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // Header section
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppLocalizations.getGreeting()}, $displayName!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.restaurantSummary,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter section
                        _buildFilterSection(context),
                        const SizedBox(height: 16),

                        // Metrics section
                        _buildMetricsSection(context),
                        const SizedBox(height: 24),

                        // Sales Chart
                        _buildSectionHeader(context, AppLocalizations.salesOverview, null),
                        const SizedBox(height: 12),

                        // Chart Grouping Options
                        Row(
                          children: [
                            Text(
                              'dashboard.group_by'.tr(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedGroupBy,
                                isDense: true,
                                underline: const SizedBox(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: 'Hour',
                                    child: Text('dashboard.hour'.tr()),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Day',
                                    child: Text('dashboard.day'.tr()),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Week day',
                                    child: Text('dashboard.week_day'.tr()),
                                  ),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedGroupBy = newValue;
                                    });
                                    _loadSalesChartData(); // Reload chart data for new grouping
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _isLoadingChart
                            ? Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  height: 232, // Match SalesChart height + padding
                                  padding: const EdgeInsets.all(16.0),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            : SalesChart(
                                timeFrame: _selectedTimeFrame,
                                groupBy: _selectedGroupBy,
                                salesData: _salesChartData,
                              ),
                        const SizedBox(height: 32),

                        // Best Sellers
                        _buildBestSellersHeader(context),
                        const SizedBox(height: 16),
                        BestSellers(
                          timeFrame: _selectedTimeFrame,
                          branch: _selectedBranch,
                          sortByRevenue: _sortByRevenue,
                        ),
                      ],
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

  Widget _buildMetricsSection(BuildContext context) {
    final metrics = _getMetricsForSelection();

    return Row(
      children: [
        Expanded(
          child: _CompactMetricCard(
            title: _getRevenueTitle(),
            value: metrics['revenue']!,
            change: metrics['revenueChange']!,
            isPositive: metrics['revenueChange']!.startsWith('+'),
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactMetricCard(
            title: AppLocalizations.orders,
            value: metrics['orders']!,
            change: metrics['ordersChange']!,
            isPositive: metrics['ordersChange']!.startsWith('+'),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  String _getTranslatedLabel(String englishLabel) {
    // Map English labels to translation keys
    switch (englishLabel) {
      // Time frame options
      case 'Today':
        return 'dashboard.today'.tr();
      case 'This Week':
        return 'dashboard.this_week'.tr();
      case 'This Month':
        return 'dashboard.this_month'.tr();
      case 'Last 30 Days':
        return 'dashboard.last_30_days'.tr();
      // Branch options
      case 'All Branches':
        return 'dashboard.all_branches'.tr();
      case 'Main Branch':
        return 'dashboard.main_branch'.tr();
      case 'Secondary Branch':
        return 'dashboard.secondary_branch'.tr();
      default:
        return englishLabel; // Fallback to original if no translation found
    }
  }

  String _getRevenueTitle() {
    switch (_selectedTimeFrame) {
      case 'Today':
        return AppLocalizations.todaysRevenue;
      case 'This Week':
        return '${'dashboard.revenue'.tr()} ${'dashboard.this_week'.tr().toLowerCase()}';
      case 'This Month':
        return '${'dashboard.revenue'.tr()} ${'dashboard.this_month'.tr().toLowerCase()}';
      case 'Last 30 Days':
        return '${'dashboard.revenue'.tr()} ${'dashboard.last_30_days'.tr().toLowerCase()}';
      default:
        return 'dashboard.revenue'.tr();
    }
  }

  Map<String, String> _getMetricsForSelection() {
    if (_isLoadingStats || _currentStats == null || _previousStats == null) {
      return {
        'revenue': '₫0',
        'revenueChange': '0%',
        'orders': '0',
        'ordersChange': '0%',
      };
    }

    // Get current period data
    final currentRevenue = (_currentStats!['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final currentOrders = (_currentStats!['total_orders'] as num?)?.toInt() ?? 0;

    // Get previous period data for comparison
    final previousRevenue = (_previousStats!['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final previousOrders = (_previousStats!['total_orders'] as num?)?.toInt() ?? 0;

    // Calculate percentage changes
    String revenueChange = '0%';
    if (previousRevenue > 0) {
      final change = ((currentRevenue - previousRevenue) / previousRevenue * 100);
      revenueChange = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
    } else if (currentRevenue > 0) {
      revenueChange = '+100%';
    }

    String ordersChange = '0%';
    if (previousOrders > 0) {
      final change = ((currentOrders - previousOrders) / previousOrders * 100);
      ordersChange = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
    } else if (currentOrders > 0) {
      ordersChange = '+100%';
    }

    // Format revenue with thousand separators
    final revenueStr = currentRevenue.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return {
      'revenue': '₫$revenueStr',
      'revenueChange': revenueChange,
      'orders': currentOrders.toString(),
      'ordersChange': ordersChange,
    };
  }

  Widget _buildBestSellersHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'dashboard.best_sellers'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton('dashboard.revenue'.tr(), _sortByRevenue, true),
              _buildToggleButton('dashboard.quantity'.tr(), !_sortByRevenue, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, bool isRevenue) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortByRevenue = isRevenue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String? subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time frame filter
          Expanded(
            child: _buildFilterDropdown(
              context,
              icon: Icons.calendar_today_outlined,
              label: _selectedTimeFrame,
              options: ['Today', 'This Week', 'This Month', 'Last 30 Days'],
              displayNames: null, // Will use translation keys in the method
              onChanged: (value) {
                setState(() {
                  _selectedTimeFrame = value!;
                });
                _loadStatistics();
                _loadSalesChartData(); // Reload chart data for new time frame
              },
            ),
          ),
          const SizedBox(width: 12),
          // Branch filter
          Expanded(
            child: _buildFilterDropdown(
              context,
              icon: Icons.store_outlined,
              label: _selectedBranch,
              options: ['All Branches', 'Main Branch', 'Secondary Branch'],
              displayNames: null, // Will use translation keys in the method
              onChanged: (value) {
                setState(() {
                  _selectedBranch = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> options,
    List<String>? displayNames,
    required Function(String?) onChanged,
  }) {
    // Get display name for current selection
    String currentDisplayName = _getTranslatedLabel(label);

    return GestureDetector(
      onTap: () {
        _showDropdownMenu(context, options, label, onChanged);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                currentDisplayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showDropdownMenu(
    BuildContext context,
    List<String> options,
    String currentValue,
    Function(String?) onChanged,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: options.map((String option) {
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              if (option == currentValue)
                Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(
                _getTranslatedLabel(option),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: option == currentValue ? FontWeight.w600 : FontWeight.w400,
                  color: option == currentValue
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ).then((String? selectedValue) {
      if (selectedValue != null) {
        onChanged(selectedValue);
      }
    });
  }

}

class _CompactMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _CompactMetricCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.9),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up : Icons.trending_down,
                          color: isPositive ? Colors.green[700] : Colors.red[700],
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          change,
                          style: TextStyle(
                            color: isPositive ? Colors.green[700] : Colors.red[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}