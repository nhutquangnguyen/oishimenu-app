import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsCharts extends StatelessWidget {
  final String timeFrame;
  final String branch;

  const AnalyticsCharts({
    super.key,
    required this.timeFrame,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Types Section
            _buildPaymentTypesSection(context),
            const SizedBox(height: 24),
            // Order Sources Section
            _buildOrderSourcesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Types',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Pie Chart
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 25,
                  sections: _getPaymentTypeSections(),
                  pieTouchData: PieTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: _buildPaymentLegend(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderSourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Sources',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Pie Chart
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 25,
                  sections: _getOrderSourceSections(),
                  pieTouchData: PieTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: _buildOrderSourceLegend(context),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _getPaymentTypeSections() {
    final paymentData = _getPaymentTypeData();

    return [
      PieChartSectionData(
        color: const Color(0xFF6366F1), // Indigo
        value: paymentData['cash']!,
        title: '${paymentData['cash']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFF10B981), // Emerald
        value: paymentData['card']!,
        title: '${paymentData['card']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFF59E0B), // Amber
        value: paymentData['digital']!,
        title: '${paymentData['digital']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFEF4444), // Red
        value: paymentData['other']!,
        title: '${paymentData['other']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<PieChartSectionData> _getOrderSourceSections() {
    final sourceData = _getOrderSourceData();

    return [
      PieChartSectionData(
        color: const Color(0xFF8B5CF6), // Purple
        value: sourceData['dineIn']!,
        title: '${sourceData['dineIn']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFF06B6D4), // Cyan
        value: sourceData['takeAway']!,
        title: '${sourceData['takeAway']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFF84CC16), // Lime
        value: sourceData['grab']!,
        title: '${sourceData['grab']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFEC4899), // Pink
        value: sourceData['shopee']!,
        title: '${sourceData['shopee']!.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildPaymentLegend(BuildContext context) {
    final paymentRevenue = _getPaymentRevenueData();
    return Column(
      children: [
        _buildLegendItem(context, const Color(0xFF6366F1), 'Cash', paymentRevenue['cashAmount']!, paymentRevenue['cashPercent']!),
        _buildLegendItem(context, const Color(0xFF10B981), 'Card', paymentRevenue['cardAmount']!, paymentRevenue['cardPercent']!),
        _buildLegendItem(context, const Color(0xFFF59E0B), 'Digital Wallet', paymentRevenue['digitalAmount']!, paymentRevenue['digitalPercent']!),
        _buildLegendItem(context, const Color(0xFFEF4444), 'Other', paymentRevenue['otherAmount']!, paymentRevenue['otherPercent']!),
      ],
    );
  }

  Widget _buildOrderSourceLegend(BuildContext context) {
    final sourceRevenue = _getOrderSourceRevenueData();
    return Column(
      children: [
        _buildLegendItem(context, const Color(0xFF8B5CF6), 'Dine In', sourceRevenue['dineInAmount']!, sourceRevenue['dineInPercent']!),
        _buildLegendItem(context, const Color(0xFF06B6D4), 'Take Away', sourceRevenue['takeAwayAmount']!, sourceRevenue['takeAwayPercent']!),
        _buildLegendItem(context, const Color(0xFF84CC16), 'Grab', sourceRevenue['grabAmount']!, sourceRevenue['grabPercent']!),
        _buildLegendItem(context, const Color(0xFFEC4899), 'Shopee', sourceRevenue['shopeeAmount']!, sourceRevenue['shopeePercent']!),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label, String amount, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            percentage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getPaymentTypeData() {
    // Sample data that changes based on timeFrame and branch
    switch (timeFrame) {
      case 'Today':
        return {'cash': 45, 'card': 32, 'digital': 18, 'other': 5};
      case 'This Week':
        return {'cash': 42, 'card': 35, 'digital': 20, 'other': 3};
      case 'This Month':
        return {'cash': 40, 'card': 38, 'digital': 19, 'other': 3};
      case 'Last 30 Days':
        return {'cash': 38, 'card': 40, 'digital': 20, 'other': 2};
      default:
        return {'cash': 45, 'card': 32, 'digital': 18, 'other': 5};
    }
  }

  Map<String, double> _getOrderSourceData() {
    // Sample data that changes based on timeFrame and branch
    switch (timeFrame) {
      case 'Today':
        return {'dineIn': 42, 'takeAway': 28, 'grab': 20, 'shopee': 10};
      case 'This Week':
        return {'dineIn': 45, 'takeAway': 25, 'grab': 22, 'shopee': 8};
      case 'This Month':
        return {'dineIn': 48, 'takeAway': 24, 'grab': 18, 'shopee': 10};
      case 'Last 30 Days':
        return {'dineIn': 50, 'takeAway': 22, 'grab': 19, 'shopee': 9};
      default:
        return {'dineIn': 42, 'takeAway': 28, 'grab': 20, 'shopee': 10};
    }
  }

  Map<String, String> _getPaymentRevenueData() {
    final totalRevenue = _getTotalRevenue();
    final paymentPercentages = _getPaymentTypeData();

    final cashRevenue = totalRevenue * (paymentPercentages['cash']! / 100);
    final cardRevenue = totalRevenue * (paymentPercentages['card']! / 100);
    final digitalRevenue = totalRevenue * (paymentPercentages['digital']! / 100);
    final otherRevenue = totalRevenue * (paymentPercentages['other']! / 100);

    return {
      'cashAmount': _formatCurrency(cashRevenue),
      'cashPercent': '${paymentPercentages['cash']!.toInt()}%',
      'cardAmount': _formatCurrency(cardRevenue),
      'cardPercent': '${paymentPercentages['card']!.toInt()}%',
      'digitalAmount': _formatCurrency(digitalRevenue),
      'digitalPercent': '${paymentPercentages['digital']!.toInt()}%',
      'otherAmount': _formatCurrency(otherRevenue),
      'otherPercent': '${paymentPercentages['other']!.toInt()}%',
    };
  }

  Map<String, String> _getOrderSourceRevenueData() {
    final totalRevenue = _getTotalRevenue();
    final sourcePercentages = _getOrderSourceData();

    final dineInRevenue = totalRevenue * (sourcePercentages['dineIn']! / 100);
    final takeAwayRevenue = totalRevenue * (sourcePercentages['takeAway']! / 100);
    final grabRevenue = totalRevenue * (sourcePercentages['grab']! / 100);
    final shopeeRevenue = totalRevenue * (sourcePercentages['shopee']! / 100);

    return {
      'dineInAmount': _formatCurrency(dineInRevenue),
      'dineInPercent': '${sourcePercentages['dineIn']!.toInt()}%',
      'takeAwayAmount': _formatCurrency(takeAwayRevenue),
      'takeAwayPercent': '${sourcePercentages['takeAway']!.toInt()}%',
      'grabAmount': _formatCurrency(grabRevenue),
      'grabPercent': '${sourcePercentages['grab']!.toInt()}%',
      'shopeeAmount': _formatCurrency(shopeeRevenue),
      'shopeePercent': '${sourcePercentages['shopee']!.toInt()}%',
    };
  }

  double _getTotalRevenue() {
    // Base revenue data matching the dashboard metrics
    Map<String, double> baseRevenue = {
      'Today': 2450000,
      'This Week': 14200000,
      'This Month': 58900000,
      'Last 30 Days': 61200000,
    };

    double revenue = baseRevenue[timeFrame] ?? baseRevenue['Today']!;

    // Adjust for branch selection
    if (branch != 'All Branches') {
      double divider = branch == 'Main Branch' ? 1.8 : 3.2;
      revenue = revenue / divider;
    }

    return revenue;
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₫${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₫${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return '₫${amount.toStringAsFixed(0)}';
    }
  }
}