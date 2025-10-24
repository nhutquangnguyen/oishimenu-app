import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../services/database_helper.dart';

class BestSellers extends StatefulWidget {
  final String timeFrame;
  final String branch;
  final bool sortByRevenue;

  const BestSellers({
    super.key,
    required this.timeFrame,
    required this.branch,
    required this.sortByRevenue,
  });

  @override
  State<BestSellers> createState() => _BestSellersState();
}

class _BestSellersState extends State<BestSellers> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _showAll = false;
  List<BestSellerItem> _bestSellerItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBestSellers();
  }

  @override
  void didUpdateWidget(BestSellers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeFrame != widget.timeFrame ||
        oldWidget.sortByRevenue != widget.sortByRevenue) {
      _loadBestSellers();
    }
  }

  Future<void> _loadBestSellers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRanges = _getDateRangesForTimeFrame(widget.timeFrame);
      final db = await _databaseHelper.database;

      // Query to aggregate order items by menu item
      print('Best sellers query date range: ${dateRanges['start']} to ${dateRanges['end']}');
      print('Time frame: ${widget.timeFrame}');

      final results = await db.rawQuery('''
        SELECT
          oi.menu_item_name as name,
          COALESCE(mc.name, 'Other') as category,
          SUM(oi.quantity) as total_quantity,
          SUM(oi.total_price) as total_revenue
        FROM order_items oi
        INNER JOIN orders o ON CAST(oi.order_id AS TEXT) = CAST(o.id AS TEXT)
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id
        LEFT JOIN menu_categories mc ON mi.category_id = mc.id
        WHERE (o.payment_status = 'PAID' OR o.status = 'DELIVERED')
          AND o.created_at >= ?
          AND o.created_at <= ?
        GROUP BY oi.menu_item_id, oi.menu_item_name, mc.name
        ORDER BY ${widget.sortByRevenue ? 'total_revenue' : 'total_quantity'} DESC
        LIMIT 15
      ''', [
        dateRanges['start']!.millisecondsSinceEpoch,
        dateRanges['end']!.millisecondsSinceEpoch,
      ]);

      print('Best sellers query returned ${results.length} results');

      final items = results.map((row) {
        final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
        final quantity = (row['total_quantity'] as num?)?.toInt() ?? 0;

        final revenueStr = revenue.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

        return BestSellerItem(
          name: row['name'] as String? ?? 'Unknown',
          category: row['category'] as String? ?? 'Other',
          revenue: '₫$revenueStr',
          quantity: quantity,
          revenueValue: revenue,
        );
      }).toList();

      setState(() {
        _bestSellerItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading best sellers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, DateTime> _getDateRangesForTimeFrame(String timeFrame) {
    final now = DateTime.now();
    DateTime start, end;

    switch (timeFrame) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Last 30 Days':
        start = now.subtract(const Duration(days: 30));
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    return {'start': start, 'end': end};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_bestSellerItems.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'Không có dữ liệu',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final displayItems = _showAll ? _bestSellerItems : _bestSellerItems.take(5).toList();

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
            // Items list
            ...displayItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildSellerItem(context, item, index + 1);
            }),

            // Show All/Show Less button
            if (_bestSellerItems.length > 5) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Text(
                    _showAll
                        ? AppLocalizations.tr('dashboard.show_less')
                        : '${AppLocalizations.tr('dashboard.show_all')} (${_bestSellerItems.length} ${AppLocalizations.tr('dashboard.items')})',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSellerItem(BuildContext context, BestSellerItem item, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.sortByRevenue ? item.revenue : '${item.quantity} ${AppLocalizations.tr('dashboard.sold')}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.sortByRevenue ? '${item.quantity} ${AppLocalizations.tr('dashboard.sold')}' : item.revenue,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey[600]!;
    }
  }
}

class BestSellerItem {
  final String name;
  final String category;
  final String revenue;
  final int quantity;
  final double revenueValue;

  BestSellerItem({
    required this.name,
    required this.category,
    required this.revenue,
    required this.quantity,
    required this.revenueValue,
  });
}