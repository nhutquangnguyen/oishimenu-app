import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/menu_options.dart';

/// Service for managing menu options and option groups
class MenuOptionService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // ============= Menu Options =============

  /// Get all menu options
  Future<List<MenuOption>> getAllMenuOptions() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_options',
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) {
        return MenuOption.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching menu options: $e');
      return [];
    }
  }

  /// Get menu options by category
  Future<List<MenuOption>> getMenuOptionsByCategory(String category) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_options',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) {
        return MenuOption.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching menu options by category: $e');
      return [];
    }
  }

  /// Create a new menu option
  Future<String?> createMenuOption(MenuOption option) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert('menu_options', option.toMap());
      return id.toString();
    } catch (e) {
      print('Error creating menu option: $e');
      return null;
    }
  }

  /// Update a menu option
  Future<bool> updateMenuOption(MenuOption option) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.update(
        'menu_options',
        option.toMap(),
        where: 'id = ?',
        whereArgs: [int.tryParse(option.id) ?? 0],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating menu option: $e');
      return false;
    }
  }

  /// Delete a menu option
  Future<bool> deleteMenuOption(String optionId) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.delete(
        'menu_options',
        where: 'id = ?',
        whereArgs: [int.tryParse(optionId) ?? 0],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting menu option: $e');
      return false;
    }
  }

  // ============= Option Groups =============

  /// Get all option groups
  Future<List<OptionGroup>> getAllOptionGroups() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'option_groups',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'display_order ASC, name ASC',
      );

      List<OptionGroup> groups = [];
      for (final map in maps) {
        final group = OptionGroup.fromMap(map);
        final options = await getOptionsForGroup(group.id);
        groups.add(group.copyWith(options: options));
      }

      return groups;
    } catch (e) {
      print('Error fetching option groups: $e');
      return [];
    }
  }

  /// Get option groups for a specific menu item
  Future<List<OptionGroup>> getOptionGroupsForMenuItem(String menuItemId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT og.* FROM option_groups og
        INNER JOIN menu_item_option_groups miog ON og.id = miog.option_group_id
        WHERE miog.menu_item_id = ? AND og.is_active = 1
        ORDER BY miog.display_order ASC, og.display_order ASC
      ''', [int.tryParse(menuItemId) ?? 0]);

      List<OptionGroup> groups = [];
      for (final map in maps) {
        final group = OptionGroup.fromMap(map);
        final options = await getOptionsForGroup(group.id);
        groups.add(group.copyWith(options: options));
      }

      return groups;
    } catch (e) {
      print('Error fetching option groups for menu item: $e');
      return [];
    }
  }

  /// Get options for a specific option group
  Future<List<MenuOption>> getOptionsForGroup(String optionGroupId) async {
    try {
      final db = await _databaseHelper.database;
      final groupIdInt = int.tryParse(optionGroupId) ?? 0;
      print('🔍 Querying options for group ID: $optionGroupId (parsed as $groupIdInt)');

      // First, let's check what junction records exist
      final junctionRecords = await db.query(
        'option_group_options',
        where: 'option_group_id = ?',
        whereArgs: [groupIdInt],
      );
      print('🔗 Found ${junctionRecords.length} junction records for group $groupIdInt:');
      for (final record in junctionRecords) {
        print('   - Junction: group=${record['option_group_id']}, option=${record['option_id']}');

        // Check if the menu option exists
        final optionCheck = await db.query(
          'menu_options',
          where: 'id = ?',
          whereArgs: [record['option_id']],
        );
        print('   - Menu option ${record['option_id']} exists: ${optionCheck.isNotEmpty}');
        if (optionCheck.isNotEmpty) {
          print('     - is_available: ${optionCheck.first['is_available']}');
          print('     - name: ${optionCheck.first['name']}');
        }
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT mo.* FROM menu_options mo
        INNER JOIN option_group_options ogo ON mo.id = ogo.option_id
        WHERE ogo.option_group_id = ? AND mo.is_available = 1
        ORDER BY ogo.display_order ASC, mo.name ASC
      ''', [groupIdInt]);

      print('📊 Found ${maps.length} options for group $optionGroupId');
      for (final map in maps) {
        print('   - Option: ${map['name']} (ID: ${map['id']}, price: ${map['price']})');
      }

      return List.generate(maps.length, (i) {
        return MenuOption.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching options for group: $e');
      return [];
    }
  }

  /// Create a new option group
  Future<String?> createOptionGroup(OptionGroup optionGroup) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert('option_groups', optionGroup.toMap());
      return id.toString();
    } catch (e) {
      print('Error creating option group: $e');
      return null;
    }
  }

  /// Update an option group
  Future<bool> updateOptionGroup(OptionGroup optionGroup) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.update(
        'option_groups',
        optionGroup.toMap(),
        where: 'id = ?',
        whereArgs: [int.tryParse(optionGroup.id) ?? 0],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating option group: $e');
      return false;
    }
  }

  /// Delete an option group (soft delete by setting is_active to false)
  Future<bool> deleteOptionGroup(String optionGroupId) async {
    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        // Soft delete the option group by setting is_active to false
        await txn.update(
          'option_groups',
          {'is_active': 0},
          where: 'id = ?',
          whereArgs: [int.tryParse(optionGroupId) ?? 0],
        );

        // Remove all relationships with menu items
        await txn.delete(
          'menu_item_option_groups',
          where: 'option_group_id = ?',
          whereArgs: [int.tryParse(optionGroupId) ?? 0],
        );

        // Remove all relationships with options
        await txn.delete(
          'option_group_options',
          where: 'option_group_id = ?',
          whereArgs: [int.tryParse(optionGroupId) ?? 0],
        );
      });

      return true;
    } catch (e) {
      print('Error deleting option group: $e');
      return false;
    }
  }

  // ============= Relationships =============

  /// Connect a menu item to an option group
  Future<bool> connectMenuItemToOptionGroup(
    String menuItemId,
    String optionGroupId, {
    bool isRequired = false,
    int displayOrder = 0,
  }) async {
    try {
      final db = await _databaseHelper.database;

      // Check if relationship already exists
      final existing = await db.query(
        'menu_item_option_groups',
        where: 'menu_item_id = ? AND option_group_id = ?',
        whereArgs: [int.tryParse(menuItemId), int.tryParse(optionGroupId)],
      );

      if (existing.isNotEmpty) {
        return true; // Relationship already exists - this is the desired outcome
      }

      final relationship = MenuItemOptionGroup(
        id: '', // Will be auto-generated
        menuItemId: menuItemId,
        optionGroupId: optionGroupId,
        isRequired: isRequired,
        displayOrder: displayOrder,
        createdAt: DateTime.now(),
      );

      await db.insert('menu_item_option_groups', relationship.toMap());
      return true;
    } catch (e) {
      print('Error connecting menu item to option group: $e');
      return false;
    }
  }

  /// Disconnect a menu item from an option group
  Future<bool> disconnectMenuItemFromOptionGroup(
    String menuItemId,
    String optionGroupId,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.delete(
        'menu_item_option_groups',
        where: 'menu_item_id = ? AND option_group_id = ?',
        whereArgs: [int.tryParse(menuItemId), int.tryParse(optionGroupId)],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error disconnecting menu item from option group: $e');
      return false;
    }
  }

  /// Connect an option to an option group
  Future<bool> connectOptionToGroup(
    String optionId,
    String optionGroupId, {
    int displayOrder = 0,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final optionIdInt = int.tryParse(optionId);
      final groupIdInt = int.tryParse(optionGroupId);

      print('🔗 Connecting option $optionId (parsed: $optionIdInt) to group $optionGroupId (parsed: $groupIdInt)');

      // Check if relationship already exists
      final existing = await db.query(
        'option_group_options',
        where: 'option_group_id = ? AND option_id = ?',
        whereArgs: [groupIdInt, optionIdInt],
      );

      print('🔍 Found ${existing.length} existing relationships');

      if (existing.isNotEmpty) {
        print('✅ Relationship already exists - returning true');
        return true; // Relationship already exists - this is the desired outcome
      }

      final relationship = OptionGroupOption(
        id: '', // Will be auto-generated
        optionGroupId: optionGroupId,
        optionId: optionId,
        displayOrder: displayOrder,
        createdAt: DateTime.now(),
      );

      final relationshipMap = relationship.toMap();
      print('💾 Inserting junction record: $relationshipMap');

      final insertId = await db.insert('option_group_options', relationshipMap);
      print('✅ Junction table insert successful with ID: $insertId');

      // Verify the insert worked
      final verification = await db.query(
        'option_group_options',
        where: 'option_group_id = ? AND option_id = ?',
        whereArgs: [groupIdInt, optionIdInt],
      );
      print('🔍 Verification query found ${verification.length} records');

      return true;
    } catch (e) {
      print('Error connecting option to group: $e');
      return false;
    }
  }

  /// Disconnect an option from an option group
  Future<bool> disconnectOptionFromGroup(
    String optionId,
    String optionGroupId,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.delete(
        'option_group_options',
        where: 'option_group_id = ? AND option_id = ?',
        whereArgs: [int.tryParse(optionGroupId), int.tryParse(optionId)],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error disconnecting option from group: $e');
      return false;
    }
  }

  /// Get menu items that use a specific option group
  Future<List<String>> getMenuItemsUsingOptionGroup(String optionGroupId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'menu_item_option_groups',
        columns: ['menu_item_id'],
        where: 'option_group_id = ?',
        whereArgs: [int.tryParse(optionGroupId) ?? 0],
      );

      return maps.map((map) => map['menu_item_id'].toString()).toList();
    } catch (e) {
      print('Error fetching menu items using option group: $e');
      return [];
    }
  }

  /// Bulk connect an option group to multiple menu items
  Future<bool> connectOptionGroupToMenuItems(
    String optionGroupId,
    List<String> menuItemIds,
  ) async {
    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        for (int i = 0; i < menuItemIds.length; i++) {
          final relationship = MenuItemOptionGroup(
            id: '',
            menuItemId: menuItemIds[i],
            optionGroupId: optionGroupId,
            displayOrder: i,
            createdAt: DateTime.now(),
          );

          await txn.insert('menu_item_option_groups', relationship.toMap());
        }
      });

      return true;
    } catch (e) {
      print('Error bulk connecting option group to menu items: $e');
      return false;
    }
  }

  /// Clean up orphaned junction records that point to non-existent menu options
  Future<int> cleanupOrphanedOptionGroupJunctions() async {
    try {
      final db = await _databaseHelper.database;

      // Find orphaned junction records where the option_id doesn't exist in menu_options table
      final orphanedRecords = await db.rawQuery('''
        SELECT ogo.* FROM option_group_options ogo
        LEFT JOIN menu_options mo ON ogo.option_id = mo.id
        WHERE mo.id IS NULL
      ''');

      if (orphanedRecords.isEmpty) {
        print('✅ No orphaned option group junction records found');
        return 0;
      }

      print('🧹 Found ${orphanedRecords.length} orphaned junction records to clean up');

      // Delete orphaned records
      final deletedCount = await db.rawDelete('''
        DELETE FROM option_group_options
        WHERE option_id NOT IN (SELECT id FROM menu_options)
      ''');

      print('✅ Cleaned up $deletedCount orphaned option group junction records');
      return deletedCount;
    } catch (e) {
      print('Error cleaning up orphaned option group junctions: $e');
      return 0;
    }
  }

  /// Clean up orphaned menu item option group junction records
  Future<int> cleanupOrphanedMenuItemOptionGroupJunctions() async {
    try {
      final db = await _databaseHelper.database;

      // Find orphaned junction records where the menu_item_id or option_group_id doesn't exist
      final deletedCount = await db.rawDelete('''
        DELETE FROM menu_item_option_groups
        WHERE menu_item_id NOT IN (SELECT id FROM menu_items)
           OR option_group_id NOT IN (SELECT id FROM option_groups)
      ''');

      if (deletedCount > 0) {
        print('✅ Cleaned up $deletedCount orphaned menu item option group junction records');
      }
      return deletedCount;
    } catch (e) {
      print('Error cleaning up orphaned menu item option group junctions: $e');
      return 0;
    }
  }

  /// Perform comprehensive database cleanup
  Future<Map<String, int>> performDatabaseCleanup() async {
    try {
      print('🧹 Starting comprehensive database cleanup...');

      final results = <String, int>{};
      results['optionGroupJunctions'] = await cleanupOrphanedOptionGroupJunctions();
      results['menuItemOptionGroupJunctions'] = await cleanupOrphanedMenuItemOptionGroupJunctions();

      final totalCleaned = results.values.fold(0, (sum, count) => sum + count);
      print('✅ Database cleanup completed. Total records cleaned: $totalCleaned');

      return results;
    } catch (e) {
      print('Error during database cleanup: $e');
      return {};
    }
  }
}