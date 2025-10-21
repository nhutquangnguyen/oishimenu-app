import 'package:flutter/material.dart';

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
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final items = _getBestSellerItems();
    final displayItems = _showAll ? items : items.take(5).toList();

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
            if (items.length > 5) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Text(
                    _showAll ? 'Show Less' : 'Show All (${items.length} items)',
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                widget.sortByRevenue ? item.revenue : '${item.quantity} sold',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.sortByRevenue ? '${item.quantity} sold' : item.revenue,
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

  List<BestSellerItem> _getBestSellerItems() {
    final baseItems = [
      BestSellerItem(
        name: 'Phở Bò Tái',
        category: 'Noodles',
        revenue: '₫4,200,000',
        quantity: 168,
        revenueValue: 4200000,
      ),
      BestSellerItem(
        name: 'Bánh Mì Thịt Nướng',
        category: 'Sandwiches',
        revenue: '₫3,750,000',
        quantity: 125,
        revenueValue: 3750000,
      ),
      BestSellerItem(
        name: 'Bún Bò Huế',
        category: 'Noodles',
        revenue: '₫3,600,000',
        quantity: 144,
        revenueValue: 3600000,
      ),
      BestSellerItem(
        name: 'Cơm Tấm Sườn',
        category: 'Rice Dishes',
        revenue: '₫3,200,000',
        quantity: 128,
        revenueValue: 3200000,
      ),
      BestSellerItem(
        name: 'Gỏi Cuốn',
        category: 'Appetizers',
        revenue: '₫2,800,000',
        quantity: 140,
        revenueValue: 2800000,
      ),
      BestSellerItem(
        name: 'Chả Cá Lã Vọng',
        category: 'Fish',
        revenue: '₫2,700,000',
        quantity: 90,
        revenueValue: 2700000,
      ),
      BestSellerItem(
        name: 'Bún Chả',
        category: 'Noodles',
        revenue: '₫2,500,000',
        quantity: 100,
        revenueValue: 2500000,
      ),
      BestSellerItem(
        name: 'Bánh Xèo',
        category: 'Pancakes',
        revenue: '₫2,400,000',
        quantity: 96,
        revenueValue: 2400000,
      ),
      BestSellerItem(
        name: 'Cà Phê Sữa Đá',
        category: 'Beverages',
        revenue: '₫2,100,000',
        quantity: 210,
        revenueValue: 2100000,
      ),
      BestSellerItem(
        name: 'Nem Nướng',
        category: 'Grilled',
        revenue: '₫1,950,000',
        quantity: 78,
        revenueValue: 1950000,
      ),
      BestSellerItem(
        name: 'Bánh Cuốn',
        category: 'Rice Rolls',
        revenue: '₫1,800,000',
        quantity: 120,
        revenueValue: 1800000,
      ),
      BestSellerItem(
        name: 'Mì Quảng',
        category: 'Noodles',
        revenue: '₫1,650,000',
        quantity: 55,
        revenueValue: 1650000,
      ),
      BestSellerItem(
        name: 'Chè Ba Màu',
        category: 'Desserts',
        revenue: '₫1,400,000',
        quantity: 175,
        revenueValue: 1400000,
      ),
      BestSellerItem(
        name: 'Cao Lầu',
        category: 'Noodles',
        revenue: '₫1,200,000',
        quantity: 48,
        revenueValue: 1200000,
      ),
      BestSellerItem(
        name: 'Bánh Bao',
        category: 'Steamed Buns',
        revenue: '₫1,050,000',
        quantity: 105,
        revenueValue: 1050000,
      ),
    ];

    // Sort based on current selection
    if (widget.sortByRevenue) {
      baseItems.sort((a, b) => b.revenueValue.compareTo(a.revenueValue));
    } else {
      baseItems.sort((a, b) => b.quantity.compareTo(a.quantity));
    }

    return baseItems;
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