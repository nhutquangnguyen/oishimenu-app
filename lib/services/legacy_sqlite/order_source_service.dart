import 'package:sqflite/sqflite.dart';
import '../models/order_source.dart';
import 'database_helper.dart';

class OrderSourceService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Get all order sources
  Future<List<OrderSource>> getOrderSources({bool? isActive}) async {
    final db = await _databaseHelper.database;

    String whereClause = '1 = 1';
    List<dynamic> whereArgs = [];

    if (isActive != null) {
      whereClause += ' AND is_active = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'order_sources',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => OrderSource.fromMap(map)).toList();
  }

  // Get order source by ID
  Future<OrderSource?> getOrderSourceById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'order_sources',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return OrderSource.fromMap(maps.first);
    }
    return null;
  }

  // Create order source
  Future<String> createOrderSource(OrderSource orderSource) async {
    final db = await _databaseHelper.database;
    final id = await db.insert(
      'order_sources',
      orderSource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id.toString();
  }

  // Update order source
  Future<void> updateOrderSource(OrderSource orderSource) async {
    final db = await _databaseHelper.database;
    await db.update(
      'order_sources',
      orderSource.toMap(),
      where: 'id = ?',
      whereArgs: [int.tryParse(orderSource.id)],
    );
  }

  // Delete order source
  Future<void> deleteOrderSource(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'order_sources',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
    );
  }

  // Initialize default order sources if table is empty
  Future<void> initializeDefaultOrderSources() async {
    final sources = await getOrderSources();
    if (sources.isEmpty) {
      final defaultSources = OrderSource.getDefaultSources();
      for (final source in defaultSources) {
        await createOrderSource(source);
      }
    }
  }
}
