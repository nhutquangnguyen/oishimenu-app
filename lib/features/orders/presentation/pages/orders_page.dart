import 'package:flutter/material.dart';
import '../../../../models/order.dart';
import '../../../../services/order_service.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../../checkout/presentation/pages/checkout_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();

  List<Order> _orders = [];
  bool _isLoading = true;

  // Track completed items (orderId -> Set of item indices)
  final Map<String, Set<int>> _completedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _orderService.getOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Order> get _activeOrders {
    return _orders.where((order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Ascending by time - older first
  }

  List<Order> get _historyOrders {
    return _orders.where((order) =>
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled
    ).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[700],
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Đơn đang xử lý'),
                Tab(text: 'Lịch sử'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOrdersTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có đơn hàng nào',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeOrders.length,
        itemBuilder: (context, index) {
          final order = _activeOrders[index];
          return _buildActiveOrderCard(order, index);
        },
      ),
    );
  }

  Widget _buildActiveOrderCard(Order order, int index) {
    // Alternate colors for better distinction
    final bool isEven = index % 2 == 0;
    final Color cardColor = isEven ? Colors.blue[50]! : Colors.orange[50]!;
    final Color borderColor = isEven ? Colors.blue[200]! : Colors.orange[200]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clickable order number
                      InkWell(
                        onTap: () => _navigateToPosWithOrder(order),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[300]!, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Text(
                                order.orderNumber,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Cancel button
                IconButton(
                  onPressed: () => _showCancelOrderDialog(order),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                  tooltip: 'Hủy đơn hàng',
                ),
              ],
            ),
            const Divider(height: 24),

            // Customer info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(order.customer.name),
                if (order.tableNumber != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.table_restaurant, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(order.tableNumber!),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Order notes (if exists)
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_outlined, size: 16, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Order items
            ...order.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildActiveOrderItem(order, index, item);
            }),

            const SizedBox(height: 8),

            // Add Menu Item button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToPosWithOrder(order),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Thêm món',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 24),

            // Total and actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tổng: ${order.total.toStringAsFixed(0)}đ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _markOrderDone(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.payment),
                  label: const Text('Thanh toán'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderItem(Order order, int index, OrderItem item) {
    final isCompleted = _completedItems[order.id]?.contains(index) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[200]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.menuItemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Mark Done / Done button
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isCompleted) {
                            _completedItems[order.id]?.remove(index);
                          } else {
                            _completedItems.putIfAbsent(order.id, () => {}).add(index);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: isCompleted ? Colors.white : Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCompleted ? 'Đã xong' : 'Đánh dấu xong',
                              style: TextStyle(
                                fontSize: 13,
                                color: isCompleted ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _decreaseQuantity(order, index),
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _increaseQuantity(order, index),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          if (item.selectedOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.selectedOptions.map((option) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+ ${option.optionName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 14, color: Colors.amber[800]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              '${item.subtotal.toStringAsFixed(0)}đ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử đơn hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyOrders.length,
        itemBuilder: (context, index) {
          final order = _historyOrders[index];
          return _buildHistoryOrderCard(order);
        },
      ),
    );
  }

  Widget _buildHistoryOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: order.status == OrderStatus.delivered
              ? Colors.green[100]
              : Colors.red[100],
          child: Icon(
            order.status == OrderStatus.delivered
                ? Icons.check
                : Icons.close,
            color: order.status == OrderStatus.delivered
                ? Colors.green[700]
                : Colors.red[700],
          ),
        ),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${order.customer.name} • ${order.items.length} món'),
            Text(
              _formatDateTime(order.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${order.total.toStringAsFixed(0)}đ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusChip(order.status),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color bgColor;
    String label;

    switch (status) {
      case OrderStatus.pending:
        bgColor = Colors.orange[100]!;
        label = 'Chờ xử lý';
        break;
      case OrderStatus.confirmed:
        bgColor = Colors.blue[100]!;
        label = 'Đã xác nhận';
        break;
      case OrderStatus.preparing:
        bgColor = Colors.purple[100]!;
        label = 'Đang chuẩn bị';
        break;
      case OrderStatus.ready:
        bgColor = Colors.teal[100]!;
        label = 'Sẵn sàng';
        break;
      case OrderStatus.delivered:
        bgColor = Colors.green[100]!;
        label = 'Hoàn thành';
        break;
      case OrderStatus.cancelled:
        bgColor = Colors.red[100]!;
        label = 'Đã hủy';
        break;
      default:
        bgColor = Colors.grey[100]!;
        label = status.value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _increaseQuantity(Order order, int itemIndex) async {
    try {
      // Uncheck mark done status when increasing quantity
      setState(() {
        _completedItems[order.id]?.remove(itemIndex);
      });

      // Update the item quantity
      final updatedItems = List<OrderItem>.from(order.items);
      final item = updatedItems[itemIndex];
      final newQuantity = item.quantity + 1;
      final itemNewSubtotal = (item.basePrice + item.selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) * newQuantity;

      updatedItems[itemIndex] = OrderItem(
        id: item.id,
        menuItemId: item.menuItemId,
        menuItemName: item.menuItemName,
        basePrice: item.basePrice,
        quantity: newQuantity,
        selectedOptions: item.selectedOptions,
        subtotal: itemNewSubtotal,
      );

      // Calculate new order total
      final orderNewTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

      // Update the order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        subtotal: orderNewTotal,
        total: orderNewTotal,
        updatedAt: DateTime.now(),
      );

      await _orderService.updateOrder(updatedOrder);

      // Reload orders to reflect changes
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật số lượng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _decreaseQuantity(Order order, int itemIndex) async {
    try {
      final item = order.items[itemIndex];

      // If quantity is 1, remove the item
      if (item.quantity <= 1) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận'),
            content: Text('Xóa "${item.menuItemName}" khỏi đơn hàng?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // Remove the item
        final updatedItems = List<OrderItem>.from(order.items)..removeAt(itemIndex);

        // If no items left, delete or cancel the order
        if (updatedItems.isEmpty) {
          if (!mounted) return;

          final deleteOrder = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Đơn hàng trống'),
              content: const Text('Không còn món nào trong đơn hàng. Hủy đơn hàng?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Giữ lại'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Hủy đơn'),
                ),
              ],
            ),
          );

          if (deleteOrder == true) {
            final updatedOrder = order.copyWith(
              status: OrderStatus.cancelled,
              updatedAt: DateTime.now(),
            );
            await _orderService.updateOrder(updatedOrder);
          }
          await _loadOrders();
          return;
        }

        // Calculate new total
        final newSubtotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

        final updatedOrder = order.copyWith(
          items: updatedItems,
          subtotal: newSubtotal,
          total: newSubtotal,
          updatedAt: DateTime.now(),
        );

        await _orderService.updateOrder(updatedOrder);
      } else {
        // Decrease quantity
        final updatedItems = List<OrderItem>.from(order.items);
        final newQuantity = item.quantity - 1;
        final newSubtotal = (item.basePrice + item.selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) * newQuantity;

        updatedItems[itemIndex] = OrderItem(
          id: item.id,
          menuItemId: item.menuItemId,
          menuItemName: item.menuItemName,
          basePrice: item.basePrice,
          quantity: newQuantity,
          selectedOptions: item.selectedOptions,
          subtotal: newSubtotal,
        );

        // Calculate new order total
        final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

        final updatedOrder = order.copyWith(
          items: updatedItems,
          subtotal: newTotal,
          total: newTotal,
          updatedAt: DateTime.now(),
        );

        await _orderService.updateOrder(updatedOrder);
      }

      // Reload orders
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật số lượng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markOrderDone(Order order) async {
    // Navigate to checkout page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(order: order),
      ),
    );

    // Reload orders if checkout was successful
    if (result == true && mounted) {
      await _loadOrders();
    }
  }

  void _navigateToPosWithOrder(Order order) {
    // Navigate to POS page with the existing order
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PosPage(existingOrder: order),
      ),
    ).then((_) {
      // Reload orders when returning from POS
      _loadOrders();
    });
  }

  Future<void> _showCancelOrderDialog(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: Text(
          'Bạn có chắc chắn muốn hủy đơn hàng ${order.orderNumber}?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update order status to cancelled
        final updatedOrder = order.copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );

        await _orderService.updateOrder(updatedOrder);

        // Reload orders
        await _loadOrders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đơn hàng ${order.orderNumber} đã bị hủy'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi hủy đơn hàng: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
