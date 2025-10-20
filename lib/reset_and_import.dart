import 'dart:io';
import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/menu_import_service.dart';
import 'features/menu/services/menu_service.dart';
import 'services/menu_option_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🗑️  Resetting database and importing Vietnamese menu...');

  try {
    // Step 1: Delete the existing database
    print('\n1. 🗑️  Deleting existing database...');
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteDatabase();
    print('✅ Database deleted successfully');

    // Step 2: Re-initialize database with new schema
    print('\n2. 🔧 Re-initializing database with new schema...');
    final newDb = await dbHelper.database;
    print('✅ Database re-initialized with version 3 schema');

    // Step 3: Run the import
    print('\n3. 📥 Starting import from assets/menu-export.json...');
    final importService = MenuImportService();
    final importResult = await importService.importFromAsset('assets/menu-export.json');

    print('Import Result: ${importResult.success}');
    if (importResult.success) {
      print('✅ Import completed successfully!');
      print(importResult.toString());
    } else {
      print('❌ Import failed: ${importResult.error}');
      exit(1);
    }

    // Step 4: Validate the imported data
    print('\n4. 🔍 Validating imported data...');

    final menuService = MenuService();
    final menuOptionService = MenuOptionService();

    // Check categories
    final categories = await menuService.getCategories();
    print('Categories found: ${categories.length}');
    categories.forEach((id, name) {
      print('  - $name (ID: $id)');
    });

    // Check menu items
    final menuItems = await menuService.getAllMenuItems();
    print('\nMenu Items found: ${menuItems.length}');
    for (int i = 0; i < (menuItems.length > 10 ? 10 : menuItems.length); i++) {
      final item = menuItems[i];
      print('  - ${item.name} (\$${item.price}) [${item.categoryName}]');
    }
    if (menuItems.length > 10) {
      print('  ... and ${menuItems.length - 10} more items');
    }

    // Check option groups
    final optionGroups = await menuOptionService.getAllOptionGroups();
    print('\nOption Groups found: ${optionGroups.length}');
    for (final group in optionGroups) {
      print('  - ${group.name} (${group.options.length} options)');
      for (final option in group.options) {
        print('    * ${option.name} (+\$${option.price})');
      }
    }

    print('\n🎉 Database reset and import completed successfully!');
    print('\n📊 Final Summary:');
    print('✅ Categories: ${categories.length}');
    print('✅ Menu Items: ${menuItems.length}');
    print('✅ Option Groups: ${optionGroups.length}');
    print('\nThe Vietnamese menu data has been imported for test@gmail.com');
    print('You can now log into the main app and see the imported data!');

  } catch (e, stackTrace) {
    print('❌ Error during reset and import: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}