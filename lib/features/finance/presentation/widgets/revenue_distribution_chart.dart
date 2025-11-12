import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/transaction_service.dart';

/// Mobile-optimized donut chart showing revenue distribution by payment method
class RevenueDistributionChart extends ConsumerStatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const RevenueDistributionChart({
    super.key,
    this.startDate,
    this.endDate,
  });

  @override
  ConsumerState<RevenueDistributionChart> createState() => _RevenueDistributionChartState();
}

class _RevenueDistributionChartState extends ConsumerState<RevenueDistributionChart> {
  final TransactionService _transactionService = TransactionService();

  Map<String, double> _paymentMethodBreakdown = {};
  double _totalRevenue = 0.0;
  bool _isLoading = true;
  String? _selectedMethod;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(RevenueDistributionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load financial summary data (with date filtering)
      final summary = await _transactionService.getFinancialSummary(
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final breakdown = Map<String, double>.from(
        summary['payment_method_breakdown'] ?? {}
      );

      // Calculate total revenue from the breakdown
      final total = breakdown.values.fold(0.0, (sum, value) => sum + value);

      // If no data for the selected period, try loading all data as fallback
      if (total == 0) {
        final allDataSummary = await _transactionService.getFinancialSummary();
        final allDataBreakdown = Map<String, double>.from(
          allDataSummary['payment_method_breakdown'] ?? {}
        );
        final allDataTotal = allDataBreakdown.values.fold(0.0, (sum, value) => sum + value);

        setState(() {
          _paymentMethodBreakdown = allDataBreakdown;
          _totalRevenue = allDataTotal;
          _isLoading = false;
        });
      } else {
        setState(() {
          _paymentMethodBreakdown = breakdown;
          _totalRevenue = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading revenue data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_paymentMethodBreakdown.isEmpty || _totalRevenue == 0) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No revenue data available\nfor the selected period',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Revenue by Payment Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart and center total
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Donut chart
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 60, // Larger center for mobile
                        sections: _buildChartSections(),
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                _selectedMethod = null;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              _selectedMethod = _getPaymentMethods()[_touchedIndex];
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  // Center content
                  _buildCenterContent(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legend
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterContent() {
    if (_selectedMethod != null) {
      final amount = _paymentMethodBreakdown[_selectedMethod] ?? 0;
      final percentage = _totalRevenue > 0 ? (amount / _totalRevenue * 100) : 0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getPaymentMethodDisplayName(_selectedMethod!),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total Revenue',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(_totalRevenue),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  List<PieChartSectionData> _buildChartSections() {
    final methods = _getPaymentMethods();
    final colors = _getPaymentMethodColors();

    return methods.asMap().entries.map((entry) {
      final index = entry.key;
      final method = entry.value;
      final amount = _paymentMethodBreakdown[method] ?? 0;
      final percentage = _totalRevenue > 0 ? (amount / _totalRevenue * 100) : 0;
      final isSelected = index == _touchedIndex;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '', // Only show % if slice is large enough
        radius: isSelected ? 65 : 55, // Expand when selected
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isSelected ? _buildSelectedBadge(colors[index % colors.length]) : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildSelectedBadge(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.touch_app,
        size: 12,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegend() {
    final methods = _getPaymentMethods();
    final colors = _getPaymentMethodColors();

    return Column(
      children: methods.asMap().entries.map((entry) {
        final index = entry.key;
        final method = entry.value;
        final amount = _paymentMethodBreakdown[method] ?? 0;
        final percentage = _totalRevenue > 0 ? (amount / _totalRevenue * 100) : 0;
        final isSelected = _selectedMethod == method;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = _selectedMethod == method ? null : method;
              _touchedIndex = _selectedMethod == method ? index : -1;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? colors[index % colors.length].withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: colors[index % colors.length], width: 1) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPaymentMethodDisplayName(method),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatCurrency(amount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colors[index % colors.length] : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _getPaymentMethods() {
    // Sort payment methods by revenue value (highest to lowest)
    final methods = _paymentMethodBreakdown.keys.toList();
    methods.sort((a, b) =>
      (_paymentMethodBreakdown[b] ?? 0.0).compareTo(_paymentMethodBreakdown[a] ?? 0.0)
    );
    return methods;
  }

  List<Color> _getPaymentMethodColors() {
    return [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF84CC16), // Lime
      const Color(0xFFEC4899), // Pink
    ];
  }

  String _getPaymentMethodDisplayName(String method) {
    // The method parameter is already the displayName from TransactionService
    // So we can return it directly, but let's clean it up just in case
    return method;
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