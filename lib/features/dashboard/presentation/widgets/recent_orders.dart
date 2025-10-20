import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecentOrders extends StatelessWidget {
  const RecentOrders({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for recent orders
    final orders = [
      OrderItem(
        id: '#ORD-001',
        customerName: 'Nguyen Van A',
        items: 'Pho Bo, Banh Mi x2',
        total: '₫285,000',
        time: '2 min ago',
        status: 'preparing',
      ),
      OrderItem(
        id: '#ORD-002',
        customerName: 'Tran Thi B',
        items: 'Com Tam, Che Ba Mau',
        total: '₫195,000',
        time: '5 min ago',
        status: 'ready',
      ),
      OrderItem(
        id: '#ORD-003',
        customerName: 'Le Van C',
        items: 'Bun Bo Hue, Nuoc Mia',
        total: '₫165,000',
        time: '8 min ago',
        status: 'delivered',
      ),
      OrderItem(
        id: '#ORD-004',
        customerName: 'Pham Thi D',
        items: 'Goi Cuon x4, Nuoc Cam',
        total: '₫120,000',
        time: '12 min ago',
        status: 'pending',
      ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                    size: 20,
                  ),
                ),
                title: Text(
                  order.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      order.items,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Flexible(
                          child: Text(
                            order.total,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            order.time,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(order.status),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                onTap: () {
                  // Navigate to order details
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.check_circle;
      case 'delivered':
        return Icons.delivery_dining;
      default:
        return Icons.receipt;
    }
  }
}

class OrderItem {
  final String id;
  final String customerName;
  final String items;
  final String total;
  final String time;
  final String status;

  OrderItem({
    required this.id,
    required this.customerName,
    required this.items,
    required this.total,
    required this.time,
    required this.status,
  });
}