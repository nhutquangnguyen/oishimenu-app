import 'package:sqflite/sqflite.dart';
import '../models/order.dart';
import 'database_helper.dart';

class OrderService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Get all orders
  Future<List<Order>> getOrders({
    OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;

    String whereClause = '1 = 1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status.value);
    }

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    List<Order> orders = [];
    for (var map in maps) {
      // Get customer details
      Customer? customer;
      if (map['customer_id'] != null) {
        final customerMaps = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [map['customer_id']],
          limit: 1,
        );
        if (customerMaps.isNotEmpty) {
          customer = Customer.fromMap(customerMaps.first);
        }
      }

      // Create a simplified customer from order data if no customer record exists
      customer ??= Customer(
        id: '',
        name: 'Walk-in Customer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Get order items
      final orderItems = await getOrderItems(map['id'].toString());

      final order = Order.fromMap(map);
      orders.add(order.copyWith(
        customer: customer,
        items: orderItems,
      ));
    }

    return orders;
  }

  // Get order by ID
  Future<Order?> getOrderById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final map = maps.first;

      // Get customer details
      Customer? customer;
      if (map['customer_id'] != null) {
        final customerMaps = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [map['customer_id']],
          limit: 1,
        );
        if (customerMaps.isNotEmpty) {
          customer = Customer.fromMap(customerMaps.first);
        }
      }

      customer ??= Customer(
        id: '',
        name: 'Walk-in Customer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Get order items
      final orderItems = await getOrderItems(id);

      final order = Order.fromMap(map);
      return order.copyWith(
        customer: customer,
        items: orderItems,
      );
    }
    return null;
  }

  // Get order items for a specific order
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [int.tryParse(orderId)],
      orderBy: 'id ASC',
    );

    return maps.map((map) => OrderItem.fromMap(map)).toList();
  }

  // Create new order
  Future<String> createOrder(Order order) async {
    final db = await _databaseHelper.database;

    // Start transaction
    return await db.transaction((txn) async {
      // Insert customer if needed
      int? customerId;
      if (order.customer.name.isNotEmpty && order.customer.name != 'Walk-in Customer') {
        customerId = await txn.insert('customers', order.customer.toMap());
      }

      // Insert order
      final orderMap = order.toMap();
      orderMap['customer_id'] = customerId;
      final orderId = await txn.insert('orders', orderMap);

      // Insert order items
      for (final item in order.items) {
        final itemMap = item.toMap();
        itemMap['order_id'] = orderId;
        await txn.insert('order_items', itemMap);
      }

      return orderId.toString();
    });
  }

  // Update order
  Future<void> updateOrder(Order order) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // Update order
      await txn.update(
        'orders',
        order.toMap(),
        where: 'id = ?',
        whereArgs: [int.tryParse(order.id)],
      );

      // Update customer if exists
      if (order.customer.id.isNotEmpty) {
        await txn.update(
          'customers',
          order.customer.toMap(),
          where: 'id = ?',
          whereArgs: [int.tryParse(order.customer.id)],
        );
      }

      // Delete existing order items
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [int.tryParse(order.id)],
      );

      // Insert updated order items
      final orderIdInt = int.tryParse(order.id);
      if (orderIdInt != null) {
        for (final item in order.items) {
          final itemMap = item.toMap();
          itemMap['order_id'] = orderIdInt;
          await txn.insert('order_items', itemMap);
        }
      }
    });
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final db = await _databaseHelper.database;
    await db.update(
      'orders',
      {
        'status': status.value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [int.tryParse(orderId)],
    );
  }

  // Update payment status
  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    final db = await _databaseHelper.database;
    await db.update(
      'orders',
      {
        'payment_status': status.value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [int.tryParse(orderId)],
    );
  }

  // Get orders by status
  Future<List<Order>> getOrdersByStatus(OrderStatus status) async {
    return getOrders(status: status);
  }

  // Get today's orders
  Future<List<Order>> getTodaysOrders() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getOrders(startDate: startOfDay, endDate: endOfDay);
  }

  // Get order statistics
  Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseHelper.database;

    String whereClause = '1 = 1';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_orders,
        SUM(CASE WHEN payment_status = 'PAID' THEN total ELSE 0 END) as total_revenue,
        AVG(CASE WHEN payment_status = 'PAID' THEN total ELSE NULL END) as average_order_value,
        COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) as completed_orders,
        COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) as cancelled_orders
      FROM orders
      WHERE $whereClause
    ''', whereArgs);

    return result.first;
  }

  // Delete order (soft delete by setting status to cancelled)
  Future<void> deleteOrder(String id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'orders',
      {
        'status': OrderStatus.cancelled.value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
    );
  }

  // Generate order number
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM orders
      WHERE order_number LIKE '$dateStr%'
    ''');

    final count = result.first['count'] as int;
    final orderNumber = '$dateStr${(count + 1).toString().padLeft(3, '0')}';

    return orderNumber;
  }
}