import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../../../models/menu_item.dart';
import '../../../core/utils/parse_utils.dart';

class MenuService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<MenuItem>> getAllMenuItems() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_items',
        orderBy: 'category_id ASC, name ASC',
      );

      return List.generate(maps.length, (i) {
        return MenuItem.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching menu items: $e');
      return [];
    }
  }

  Future<List<MenuItem>> getMenuItemsByCategory(int categoryId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_items',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) {
        return MenuItem.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching menu items by category: $e');
      return [];
    }
  }

  Future<Map<String, String>> getCategories() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_categories',
        orderBy: 'display_order ASC',
      );

      final categories = <String, String>{};
      for (final map in maps) {
        categories[map['id'].toString()] = stringFromDynamic(map['name']);
      }
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return {};
    }
  }

  Future<String> getCategoryName(int categoryId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return stringFromDynamic(maps.first['name']);
      }
      return 'Unknown Category';
    } catch (e) {
      print('Error fetching category name: $e');
      return 'Unknown Category';
    }
  }

  Future<void> updateMenuItemStatus(String itemId, bool isAvailable) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'menu_items',
        {
          'available_status': isAvailable ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [int.tryParse(itemId) ?? 0],
      );
    } catch (e) {
      print('Error updating menu item status: $e');
    }
  }

  Future<void> deleteMenuItem(String itemId) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        'menu_items',
        where: 'id = ?',
        whereArgs: [int.tryParse(itemId) ?? 0],
      );
    } catch (e) {
      print('Error deleting menu item: $e');
    }
  }

  Future<String?> createCategory(MenuCategory category) async {
    try {
      final db = await _databaseHelper.database;

      // Check if category with this name already exists
      final existing = await db.query(
        'menu_categories',
        where: 'name = ?',
        whereArgs: [category.name],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Return existing ID
        return existing.first['id'].toString();
      }

      final id = await db.insert('menu_categories', category.toMap());
      return id.toString();
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  Future<String?> createMenuItem(MenuItem menuItem) async {
    try {
      final db = await _databaseHelper.database;

      // Find or create category ID
      final categories = await getCategories();
      String? categoryId;

      for (final entry in categories.entries) {
        if (entry.value == menuItem.categoryName) {
          categoryId = entry.key;
          break;
        }
      }

      // If category doesn't exist, create it
      if (categoryId == null) {
        final newCategory = MenuCategory(
          id: '',
          name: menuItem.categoryName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        categoryId = await createCategory(newCategory);
      }

      if (categoryId == null) {
        throw Exception('Failed to create or find category');
      }

      // Create menu item with category_id
      final itemData = menuItem.toMap();
      itemData['category_id'] = int.tryParse(categoryId);
      itemData.remove('categoryName'); // Remove the name field, use ID instead

      final id = await db.insert('menu_items', itemData);
      return id.toString();
    } catch (e) {
      print('Error creating menu item: $e');
      return null;
    }
  }

  Future<bool> updateMenuItem(MenuItem menuItem) async {
    try {
      final db = await _databaseHelper.database;

      // Find or create category ID
      final categories = await getCategories();
      String? categoryId;

      for (final entry in categories.entries) {
        if (entry.value == menuItem.categoryName) {
          categoryId = entry.key;
          break;
        }
      }

      // If category doesn't exist, create it
      if (categoryId == null) {
        final newCategory = MenuCategory(
          id: '',
          name: menuItem.categoryName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        categoryId = await createCategory(newCategory);
      }

      if (categoryId == null) {
        throw Exception('Failed to create or find category');
      }

      // Update menu item with category_id
      final itemData = menuItem.toMap();
      itemData['category_id'] = int.tryParse(categoryId);
      itemData.remove('categoryName'); // Remove the name field, use ID instead

      final result = await db.update(
        'menu_items',
        itemData,
        where: 'id = ?',
        whereArgs: [int.tryParse(menuItem.id) ?? 0],
      );

      return result > 0;
    } catch (e) {
      print('Error updating menu item: $e');
      return false;
    }
  }
}