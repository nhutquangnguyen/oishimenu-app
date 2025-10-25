import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../../../models/menu_item.dart';
import '../../../core/utils/parse_utils.dart';

class MenuService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<MenuItem>> getAllMenuItems({required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT
          menu_items.*,
          menu_categories.name as category_name
        FROM menu_items
        LEFT JOIN menu_categories ON menu_items.category_id = menu_categories.id
        WHERE menu_items.user_id = ?
        ORDER BY menu_categories.display_order ASC, menu_items.display_order ASC, menu_items.created_at ASC
      ''', [int.tryParse(userId) ?? 0]);

      return List.generate(maps.length, (i) {
        return MenuItem.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching menu items: $e');
      return [];
    }
  }

  Future<List<MenuItem>> getMenuItemsByCategory(int categoryId, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT
          menu_items.*,
          menu_categories.name as category_name
        FROM menu_items
        LEFT JOIN menu_categories ON menu_items.category_id = menu_categories.id
        WHERE menu_items.category_id = ? AND menu_items.user_id = ?
        ORDER BY menu_items.display_order ASC, menu_items.created_at ASC
      ''', [categoryId, int.tryParse(userId) ?? 0]);

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

  Future<void> updateMenuItemStatus(String itemId, bool isAvailable, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'menu_items',
        {
          'available_status': isAvailable ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [int.tryParse(itemId) ?? 0, int.tryParse(userId) ?? 0],
      );
    } catch (e) {
      print('Error updating menu item status: $e');
    }
  }

  Future<void> deleteMenuItem(String itemId, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        'menu_items',
        where: 'id = ? AND user_id = ?',
        whereArgs: [int.tryParse(itemId) ?? 0, int.tryParse(userId) ?? 0],
      );
    } catch (e) {
      print('Error deleting menu item: $e');
    }
  }

  Future<bool> deleteCategory(String categoryId, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;

      // Check if category has any menu items for this user
      final itemsInCategory = await db.query(
        'menu_items',
        where: 'category_id = ? AND user_id = ?',
        whereArgs: [int.tryParse(categoryId) ?? 0, int.tryParse(userId) ?? 0],
      );

      if (itemsInCategory.isNotEmpty) {
        // Category has items, cannot delete
        throw Exception('Cannot delete category that contains menu items');
      }

      // Delete the category
      final rowsAffected = await db.delete(
        'menu_categories',
        where: 'id = ?',
        whereArgs: [int.tryParse(categoryId) ?? 0],
      );

      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting category: $e');
      rethrow; // Re-throw so UI can handle the error message
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

  Future<String?> createMenuItem(MenuItem menuItem, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      print('Creating menu item: ${menuItem.name} in category: ${menuItem.categoryName}');

      // Find or create category ID
      final categories = await getCategories();
      String? categoryId;

      for (final entry in categories.entries) {
        if (entry.value == menuItem.categoryName) {
          categoryId = entry.key;
          break;
        }
      }

      print('Found category ID: $categoryId for category: ${menuItem.categoryName}');

      // If category doesn't exist, create it
      if (categoryId == null) {
        print('Category not found, creating new category: ${menuItem.categoryName}');
        final newCategory = MenuCategory(
          id: '',
          name: menuItem.categoryName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        categoryId = await createCategory(newCategory);
        print('Created new category with ID: $categoryId');
      }

      if (categoryId == null) {
        throw Exception('Failed to create or find category');
      }

      // Create menu item with category_id and user_id
      final itemData = menuItem.toMap();
      itemData['category_id'] = int.tryParse(categoryId);
      itemData['user_id'] = int.tryParse(userId) ?? 0;
      itemData.remove('category_name'); // Remove the name field, use ID instead

      print('Inserting menu item data: $itemData');
      final id = await db.insert('menu_items', itemData);
      print('Successfully created menu item with ID: $id');
      return id.toString();
    } catch (e) {
      print('Error creating menu item: $e');
      return null;
    }
  }

  Future<bool> updateMenuItem(MenuItem menuItem, {required String userId}) async {
    try {
      final db = await _databaseHelper.database;
      print('Updating menu item: ${menuItem.name} (ID: ${menuItem.id}) in category: ${menuItem.categoryName}');

      // Find or create category ID
      final categories = await getCategories();
      String? categoryId;

      for (final entry in categories.entries) {
        if (entry.value == menuItem.categoryName) {
          categoryId = entry.key;
          break;
        }
      }

      print('Found category ID: $categoryId for category: ${menuItem.categoryName}');

      // If category doesn't exist, create it
      if (categoryId == null) {
        print('Category not found, creating new category: ${menuItem.categoryName}');
        final newCategory = MenuCategory(
          id: '',
          name: menuItem.categoryName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        categoryId = await createCategory(newCategory);
        print('Created new category with ID: $categoryId');
      }

      if (categoryId == null) {
        throw Exception('Failed to create or find category');
      }

      // Update menu item with category_id
      final itemData = menuItem.toMap();
      itemData['category_id'] = int.tryParse(categoryId);
      itemData['user_id'] = int.tryParse(userId) ?? 0;
      itemData.remove('category_name'); // Remove the name field, use ID instead

      print('Updating menu item data: $itemData');
      print('WHERE id = ${menuItem.id} AND user_id = $userId');

      final result = await db.update(
        'menu_items',
        itemData,
        where: 'id = ? AND user_id = ?',
        whereArgs: [int.tryParse(menuItem.id) ?? 0, int.tryParse(userId) ?? 0],
      );

      print('Update result: $result rows affected');
      return result > 0;
    } catch (e) {
      print('Error updating menu item: $e');
      return false;
    }
  }

  // Get all categories ordered by display_order
  Future<List<MenuCategory>> getCategoriesOrdered() async {
    try {
      final maps = await _databaseHelper.getCategoriesOrdered();
      return List.generate(maps.length, (i) {
        return MenuCategory.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching ordered categories: $e');
      return [];
    }
  }

  // Reorder categories
  Future<bool> reorderCategories(List<MenuCategory> categories) async {
    try {
      final categoriesMap = categories.map((category) => {
        'id': int.tryParse(category.id) ?? 0,
        'name': category.name,
      }).toList();

      await _databaseHelper.reorderCategories(categoriesMap);
      return true;
    } catch (e) {
      print('Error reordering categories: $e');
      return false;
    }
  }

  // Reorder menu items within a category
  Future<bool> reorderMenuItems(List<MenuItem> menuItems, int categoryId) async {
    try {
      final menuItemsMap = menuItems.map((item) => {
        'id': int.tryParse(item.id) ?? 0,
        'name': item.name,
      }).toList();

      await _databaseHelper.reorderMenuItems(menuItemsMap, categoryId);
      return true;
    } catch (e) {
      print('Error reordering menu items: $e');
      return false;
    }
  }

  // Get the next display order for a new menu item in a category
  Future<int> getNextMenuItemDisplayOrder(int categoryId) async {
    try {
      final items = await _databaseHelper.getMenuItemsOrdered(categoryId);
      return items.length; // Next order is the current count
    } catch (e) {
      print('Error getting next display order: $e');
      return 0;
    }
  }

  // Get the next display order for a new category
  Future<int> getNextCategoryDisplayOrder() async {
    try {
      final categories = await _databaseHelper.getCategoriesOrdered();
      return categories.length; // Next order is the current count
    } catch (e) {
      print('Error getting next category display order: $e');
      return 0;
    }
  }
}