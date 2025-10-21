import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/metric_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_orders.dart';
import '../widgets/sales_chart.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(userDisplayNameProvider);
    final timeOfDay = _getTimeOfDay();

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
                          '$timeOfDay, $displayName!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here\'s your restaurant summary for today',
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
                        // Metrics section
                        _buildMetricsSection(context),
                        const SizedBox(height: 24),

                        // Quick Actions
                        _buildSectionHeader(context, 'Quick Actions', '12 actions'),
                        const SizedBox(height: 16),
                        const QuickActions(),
                        const SizedBox(height: 32),

                        // Sales Chart
                        _buildSectionHeader(context, 'Sales Overview', null),
                        const SizedBox(height: 16),
                        const SalesChart(),
                        const SizedBox(height: 32),

                        // Recent Orders
                        _buildSectionHeader(context, 'Recent Orders', '35 orders'),
                        const SizedBox(height: 16),
                        const RecentOrders(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow screens, use single column; on wider screens, use 2 columns
        final isNarrow = constraints.maxWidth < 400;

        if (isNarrow) {
          return Column(
            children: [
              const MetricCard(
                title: 'Today\'s Revenue',
                value: '₫2,450,000',
                change: '+12.5%',
                isPositive: true,
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              const MetricCard(
                title: 'Orders',
                value: '87',
                change: '+5.2%',
                isPositive: true,
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              const MetricCard(
                title: 'Customers',
                value: '156',
                change: '+8.1%',
                isPositive: true,
                icon: Icons.people,
                color: Colors.purple,
              ),
              const SizedBox(height: 8),
              const MetricCard(
                title: 'Avg Order',
                value: '₫285,000',
                change: '-2.3%',
                isPositive: false,
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
            ],
          );
        }

        return Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Today\'s Revenue',
                    value: '₫2,450,000',
                    change: '+12.5%',
                    isPositive: true,
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    title: 'Orders',
                    value: '87',
                    change: '+5.2%',
                    isPositive: true,
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Customers',
                    value: '156',
                    change: '+8.1%',
                    isPositive: true,
                    icon: Icons.people,
                    color: Colors.purple,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    title: 'Avg Order',
                    value: '₫285,000',
                    change: '-2.3%',
                    isPositive: false,
                    icon: Icons.shopping_cart,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
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

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning XX';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}