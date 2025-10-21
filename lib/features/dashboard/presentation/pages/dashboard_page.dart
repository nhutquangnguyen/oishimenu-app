import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/quick_actions.dart';
import '../widgets/best_sellers.dart';
import '../widgets/sales_chart.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedTimeFrame = 'Today';
  String _selectedBranch = 'All Branches';
  String _selectedGroupBy = 'Hour';
  bool _sortByRevenue = true;

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(userDisplayNameProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh dashboard data
          await Future.delayed(const Duration(seconds: 1));
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

                        // Quick Actions
                        _buildSectionHeader(context, AppLocalizations.quickActions, '12 actions'),
                        const SizedBox(height: 16),
                        const QuickActions(),
                        const SizedBox(height: 32),

                        // Sales Chart
                        _buildSectionHeader(context, AppLocalizations.salesOverview, null),
                        const SizedBox(height: 12),

                        // Chart Grouping Options
                        Row(
                          children: [
                            Text(
                              'Group by:',
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
                                items: ['Hour', 'Day', 'Week day'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedGroupBy = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        SalesChart(
                          timeFrame: _selectedTimeFrame,
                          groupBy: _selectedGroupBy,
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

  String _getRevenueTitle() {
    switch (_selectedTimeFrame) {
      case 'Today':
        return AppLocalizations.todaysRevenue;
      case 'This Week':
        return 'This Week\'s Revenue';
      case 'This Month':
        return 'This Month\'s Revenue';
      case 'Last 30 Days':
        return 'Last 30 Days Revenue';
      default:
        return 'Revenue';
    }
  }

  Map<String, String> _getMetricsForSelection() {
    // Sample data based on time frame and branch selection
    Map<String, Map<String, String>> timeFrameData = {
      'Today': {'revenue': '₫2,450,000', 'revenueChange': '+12.5%', 'orders': '87', 'ordersChange': '+5.2%'},
      'This Week': {'revenue': '₫14,200,000', 'revenueChange': '+8.3%', 'orders': '542', 'ordersChange': '+12.1%'},
      'This Month': {'revenue': '₫58,900,000', 'revenueChange': '+15.7%', 'orders': '2,103', 'ordersChange': '+9.8%'},
      'Last 30 Days': {'revenue': '₫61,200,000', 'revenueChange': '+11.4%', 'orders': '2,287', 'ordersChange': '+6.3%'},
      'Custom': {'revenue': '₫0', 'revenueChange': '0%', 'orders': '0', 'ordersChange': '0%'},
    };

    Map<String, String> baseMetrics = timeFrameData[_selectedTimeFrame] ?? timeFrameData['Today']!;

    // Adjust for branch selection
    if (_selectedBranch != 'All Branches') {
      // Simulate branch-specific data (roughly 1/3 for individual branches)
      double revenueDivider = _selectedBranch == 'Main Branch' ? 1.8 : 3.2;
      double ordersDivider = _selectedBranch == 'Main Branch' ? 1.9 : 3.1;

      String revenueStr = baseMetrics['revenue']!;
      String ordersStr = baseMetrics['orders']!;

      // Extract numbers and adjust
      String revenueNum = revenueStr.replaceAll('₫', '').replaceAll(',', '');
      double revenue = double.tryParse(revenueNum) ?? 0;
      revenue = revenue / revenueDivider;

      String ordersNum = ordersStr.replaceAll(',', '');
      double orders = double.tryParse(ordersNum) ?? 0;
      orders = orders / ordersDivider;

      baseMetrics['revenue'] = '₫${revenue.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
      baseMetrics['orders'] = orders.toInt().toString();
    }

    return baseMetrics;
  }

  Widget _buildBestSellersHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Best Sellers',
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
              _buildToggleButton('Revenue', _sortByRevenue, true),
              _buildToggleButton('Quantity', !_sortByRevenue, false),
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
              options: ['Today', 'This Week', 'This Month', 'Last 30 Days', 'Custom'],
              onChanged: (value) {
                setState(() {
                  _selectedTimeFrame = value!;
                });
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
              options: ['All Branches', 'Main Branch', 'Branch 2', 'Branch 3'],
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
    required Function(String?) onChanged,
  }) {
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
                label,
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
                option,
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