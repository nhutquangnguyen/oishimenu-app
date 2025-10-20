import 'package:sqflite/sqflite.dart';
import '../models/menu_item.dart';
import 'database_helper.dart';

class MenuService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Menu Categories
  Future<List<MenuCategory>> getCategories() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'menu_categories',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'display_order ASC',
    );

    return List.generate(maps.length, (i) {
      return MenuCategory.fromMap(maps[i]);
    });
  }

  Future<MenuCategory?> getCategoryById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'menu_categories',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MenuCategory.fromMap(maps.first);
    }
    return null;
  }

  Future<String> addCategory(MenuCategory category) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('menu_categories', category.toMap());
    return id.toString();
  }

  Future<void> updateCategory(MenuCategory category) async {
    final db = await _databaseHelper.database;
    await db.update(
      'menu_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [int.tryParse(category.id)],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'menu_categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
    );
  }

  // Menu Items
  Future<List<MenuItem>> getMenuItems({String? categoryId}) async {
    final db = await _databaseHelper.database;

    String whereClause = 'available_status = ?';
    List<dynamic> whereArgs = [1];

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(int.tryParse(categoryId));
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'menu_items',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    List<MenuItem> items = [];
    for (var map in maps) {
      // Get category name
      final categoryMap = await db.query(
        'menu_categories',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [map['category_id']],
        limit: 1,
      );

      map['category_name'] = categoryMap.isNotEmpty ? categoryMap.first['name'] : '';

      // Get sizes for this menu item
      final sizeMaps = await db.query(
        'menu_item_sizes',
        where: 'menu_item_id = ?',
        whereArgs: [map['id']],
        orderBy: 'is_default DESC, name ASC',
      );

      final sizes = sizeMaps.map((sizeMap) => MenuSize.fromMap(sizeMap)).toList();

      final item = MenuItem.fromMap(map);
      items.add(item.copyWith(sizes: sizes));
    }

    return items;
  }

  Future<MenuItem?> getMenuItemById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'menu_items',
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final map = maps.first;

      // Get category name
      final categoryMap = await db.query(
        'menu_categories',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [map['category_id']],
        limit: 1,
      );

      map['category_name'] = categoryMap.isNotEmpty ? categoryMap.first['name'] : '';

      // Get sizes for this menu item
      final sizeMaps = await db.query(
        'menu_item_sizes',
        where: 'menu_item_id = ?',
        whereArgs: [map['id']],
        orderBy: 'is_default DESC, name ASC',
      );

      final sizes = sizeMaps.map((sizeMap) => MenuSize.fromMap(sizeMap)).toList();

      final item = MenuItem.fromMap(map);
      return item.copyWith(sizes: sizes);
    }
    return null;
  }

  Future<String> addMenuItem(MenuItem item, String categoryId) async {
    final db = await _databaseHelper.database;

    final itemMap = item.toMap();
    itemMap['category_id'] = int.tryParse(categoryId);

    final id = await db.insert('menu_items', itemMap);

    // Add sizes if any
    for (final size in item.sizes) {
      final sizeMap = size.toMap();
      sizeMap['menu_item_id'] = id;
      await db.insert('menu_item_sizes', sizeMap);
    }

    return id.toString();
  }

  Future<void> updateMenuItem(MenuItem item, String categoryId) async {
    final db = await _databaseHelper.database;

    final itemMap = item.toMap();
    itemMap['category_id'] = int.tryParse(categoryId);

    await db.update(
      'menu_items',
      itemMap,
      where: 'id = ?',
      whereArgs: [int.tryParse(item.id)],
    );

    // Delete existing sizes
    await db.delete(
      'menu_item_sizes',
      where: 'menu_item_id = ?',
      whereArgs: [int.tryParse(item.id)],
    );

    // Add new sizes
    for (final size in item.sizes) {
      final sizeMap = size.toMap();
      sizeMap['menu_item_id'] = int.tryParse(item.id);
      await db.insert('menu_item_sizes', sizeMap);
    }
  }

  Future<void> deleteMenuItem(String id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'menu_items',
      {'available_status': 0},
      where: 'id = ?',
      whereArgs: [int.tryParse(id)],
    );
  }

  // Search menu items
  Future<List<MenuItem>> searchMenuItems(String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'menu_items',
      where: 'available_status = ? AND (name LIKE ? OR description LIKE ?)',
      whereArgs: [1, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    List<MenuItem> items = [];
    for (var map in maps) {
      // Get category name
      final categoryMap = await db.query(
        'menu_categories',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [map['category_id']],
        limit: 1,
      );

      map['category_name'] = categoryMap.isNotEmpty ? categoryMap.first['name'] : '';

      items.add(MenuItem.fromMap(map));
    }

    return items;
  }
}