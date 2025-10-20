import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/menu_item.dart';
import '../models/menu_options.dart';
import '../features/menu/services/menu_service.dart';
import '../services/menu_option_service.dart';

/// Service for importing menu data from JSON exports
class MenuImportService {
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();

  /// Import menu data from asset file
  Future<MenuImportResult> importFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return await importFromJsonData(data);
    } catch (e) {
      return MenuImportResult(
        success: false,
        error: 'Failed to read asset: $e',
      );
    }
  }

  /// Import menu data from JSON file
  Future<MenuImportResult> importFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return await importFromJsonData(data);
    } catch (e) {
      return MenuImportResult(
        success: false,
        error: 'Failed to read file: $e',
      );
    }
  }

  /// Import menu data from JSON data map
  Future<MenuImportResult> importFromJsonData(Map<String, dynamic> data) async {
    int categoriesImported = 0;
    int menuItemsImported = 0;
    int optionGroupsImported = 0;
    int optionsImported = 0;
    int relationshipsImported = 0;

    try {
      // 1. Import categories first
      if (data.containsKey('categories')) {
        final categories = data['categories'] as List<dynamic>;
        for (final categoryData in categories) {
          final category = await _importCategory(categoryData);
          if (category != null) {
            categoriesImported++;
          }
        }
      }

      // 2. Import option groups and their options
      if (data.containsKey('optionGroups')) {
        final optionGroups = data['optionGroups'] as List<dynamic>;
        for (final groupData in optionGroups) {
          final result = await _importOptionGroup(groupData);
          if (result != null) {
            optionGroupsImported++;
            optionsImported += result.optionsCount;
          }
        }
      }

      // 3. Import menu items
      if (data.containsKey('menuItems')) {
        final menuItems = data['menuItems'] as List<dynamic>;
        for (final itemData in menuItems) {
          final item = await _importMenuItem(itemData);
          if (item != null) {
            menuItemsImported++;
          }
        }
      }

      // 4. Import menu item to option group relationships
      if (data.containsKey('menuItemOptionRelationships')) {
        final relationships = data['menuItemOptionRelationships'] as List<dynamic>;
        for (final relData in relationships) {
          final connected = await _importMenuItemOptionRelationship(relData);
          if (connected) {
            relationshipsImported++;
          }
        }
      }

      return MenuImportResult(
        success: true,
        categoriesImported: categoriesImported,
        menuItemsImported: menuItemsImported,
        optionGroupsImported: optionGroupsImported,
        optionsImported: optionsImported,
        relationshipsImported: relationshipsImported,
      );

    } catch (e) {
      debugPrint('Import error: $e');
      return MenuImportResult(
        success: false,
        error: 'Import failed: $e',
        categoriesImported: categoriesImported,
        menuItemsImported: menuItemsImported,
        optionGroupsImported: optionGroupsImported,
        optionsImported: optionsImported,
        relationshipsImported: relationshipsImported,
      );
    }
  }

  /// Import a single category
  Future<MenuCategory?> _importCategory(Map<String, dynamic> data) async {
    try {
      final category = MenuCategory(
        id: '', // Will be auto-generated
        name: data['name'] ?? '',
        displayOrder: data['displayOrder'] ?? 0,
        isActive: data['isActive'] ?? true,
        createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      );

      final categoryId = await _menuService.createCategory(category);
      return categoryId != null ? category.copyWith(id: categoryId) : null;
    } catch (e) {
      debugPrint('Failed to import category: $e');
      return null;
    }
  }

  /// Import a single menu item
  Future<MenuItem?> _importMenuItem(Map<String, dynamic> data) async {
    try {
      // Handle availability status
      bool availableStatus = true;
      if (data['availableStatus'] != null) {
        final status = data['availableStatus'].toString().toUpperCase();
        availableStatus = status == 'AVAILABLE';
      }

      // Parse photos
      List<String> photos = [];
      if (data['photos'] != null) {
        if (data['photos'] is List) {
          photos = (data['photos'] as List).map((e) => e.toString()).toList();
        }
      }

      final menuItem = MenuItem(
        id: '', // Will be auto-generated
        name: data['name'] ?? '',
        price: (data['price'] ?? 0).toDouble(),
        categoryName: data['categoryName'] ?? 'Uncategorized',
        description: data['description'] ?? '',
        photos: photos,
        availableStatus: availableStatus,
        createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      );

      final itemId = await _menuService.createMenuItem(menuItem);
      return itemId != null ? menuItem.copyWith(id: itemId) : null;
    } catch (e) {
      debugPrint('Failed to import menu item: $e');
      return null;
    }
  }

  /// Import option group with its options
  Future<OptionGroupImportResult?> _importOptionGroup(Map<String, dynamic> data) async {
    try {
      // Create the option group
      final optionGroup = OptionGroup(
        id: '', // Will be auto-generated
        name: data['name'] ?? '',
        description: data['description'],
        minSelection: data['minSelection'] ?? 0,
        maxSelection: data['maxSelection'] ?? 1,
        isRequired: data['isRequired'] ?? false,
        displayOrder: data['displayOrder'] ?? 0,
        isActive: data['active'] ?? true,
        createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      );

      final groupId = await _menuOptionService.createOptionGroup(optionGroup);
      if (groupId == null) return null;

      int optionsCount = 0;

      // Import options for this group
      if (data.containsKey('options') && data['options'] is List) {
        final options = data['options'] as List<dynamic>;
        for (final optionData in options) {
          final option = await _importMenuOption(optionData as Map<String, dynamic>);
          if (option != null) {
            // Connect the option to the group
            final connected = await _menuOptionService.connectOptionToGroup(
              option.id,
              groupId,
              displayOrder: optionsCount,
            );
            if (connected) optionsCount++;
          }
        }
      }

      return OptionGroupImportResult(
        optionGroup: optionGroup.copyWith(id: groupId),
        optionsCount: optionsCount,
      );
    } catch (e) {
      debugPrint('Failed to import option group: $e');
      return null;
    }
  }

  /// Import a single menu option
  Future<MenuOption?> _importMenuOption(Map<String, dynamic> data) async {
    try {
      final option = MenuOption(
        id: '', // Will be auto-generated
        name: data['name'] ?? '',
        price: (data['price'] ?? 0).toDouble(),
        description: data['description'],
        category: data['category'],
        isAvailable: data['isAvailable'] ?? true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final optionId = await _menuOptionService.createMenuOption(option);
      return optionId != null ? option.copyWith(id: optionId) : null;
    } catch (e) {
      debugPrint('Failed to import menu option: $e');
      return null;
    }
  }

  /// Import menu item to option group relationship
  Future<bool> _importMenuItemOptionRelationship(Map<String, dynamic> data) async {
    try {
      final menuItemId = data['menuItemId']?.toString();
      final optionGroupIds = data['optionGroupIds'] as List<dynamic>?;

      if (menuItemId == null || optionGroupIds == null || optionGroupIds.isEmpty) {
        return false;
      }

      // Get the actual menu item ID from our database by name
      // Since we imported items with new IDs, we need to match by name
      final menuItemName = data['menuItemName']?.toString();
      if (menuItemName == null) return false;

      // Find the menu item by name (this is a simplified approach)
      final allMenuItems = await _menuService.getAllMenuItems();
      final menuItem = allMenuItems.firstWhere(
        (item) => item.name == menuItemName,
        orElse: () => throw Exception('Menu item not found: $menuItemName'),
      );

      // Find option groups by name and connect them
      final allOptionGroups = await _menuOptionService.getAllOptionGroups();
      int connected = 0;

      for (int i = 0; i < optionGroupIds.length; i++) {
        final originalGroupId = optionGroupIds[i].toString();
        final optionGroupNames = data['optionGroupNames'] as List<dynamic>?;

        if (optionGroupNames != null && i < optionGroupNames.length) {
          final groupName = optionGroupNames[i].toString();
          final optionGroup = allOptionGroups.firstWhere(
            (group) => group.name == groupName,
            orElse: () => throw Exception('Option group not found: $groupName'),
          );

          final success = await _menuOptionService.connectMenuItemToOptionGroup(
            menuItem.id,
            optionGroup.id,
            displayOrder: i,
          );

          if (success) connected++;
        }
      }

      return connected > 0;
    } catch (e) {
      debugPrint('Failed to import menu item option relationship: $e');
      return false;
    }
  }

  /// Parse datetime from various formats in the JSON
  DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;

    try {
      if (dateTime is String) {
        return DateTime.parse(dateTime);
      } else if (dateTime is Map<String, dynamic>) {
        // Handle Firestore timestamp format
        final seconds = dateTime['seconds'] as int?;
        final nanoseconds = dateTime['nanoseconds'] as int?;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ?? 0) ~/ 1000000,
          );
        }
      } else if (dateTime is int) {
        // Handle millisecondsSinceEpoch
        return DateTime.fromMillisecondsSinceEpoch(dateTime);
      }
    } catch (e) {
      debugPrint('Failed to parse datetime: $e');
    }

    return null;
  }
}

/// Result of importing menu data
class MenuImportResult {
  final bool success;
  final String? error;
  final int categoriesImported;
  final int menuItemsImported;
  final int optionGroupsImported;
  final int optionsImported;
  final int relationshipsImported;

  MenuImportResult({
    required this.success,
    this.error,
    this.categoriesImported = 0,
    this.menuItemsImported = 0,
    this.optionGroupsImported = 0,
    this.optionsImported = 0,
    this.relationshipsImported = 0,
  });

  @override
  String toString() {
    if (!success) {
      return 'Import failed: $error';
    }

    return '''Import successful:
- Categories: $categoriesImported
- Menu Items: $menuItemsImported
- Option Groups: $optionGroupsImported
- Options: $optionsImported
- Relationships: $relationshipsImported''';
  }
}

/// Result of importing an option group
class OptionGroupImportResult {
  final OptionGroup optionGroup;
  final int optionsCount;

  OptionGroupImportResult({
    required this.optionGroup,
    required this.optionsCount,
  });
}