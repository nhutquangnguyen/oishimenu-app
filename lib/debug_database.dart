import 'dart:io';
import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'features/menu/services/menu_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔍 Debugging database contents...');

  try {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final menuService = MenuService();

    // Check database version
    final versionResult = await db.rawQuery('PRAGMA user_version');
    final version = versionResult.first['user_version'];
    print('📊 Database version: $version');

    // Check categories
    print('\n📂 Categories in database:');
    final categories = await db.query('menu_categories', orderBy: 'id');
    for (final category in categories) {
      print('  ID: ${category['id']}, Name: ${category['name']}, Active: ${category['is_active']}');
    }

    // Check menu items count
    final itemCount = await db.rawQuery('SELECT COUNT(*) as count FROM menu_items');
    print('\n🍽️  Total menu items in database: ${itemCount.first['count']}');

    // Check some specific Vietnamese items
    print('\n🇻🇳 Vietnamese menu items (first 10):');
    final vietnameseItems = await db.query(
      'menu_items',
      orderBy: 'id',
      limit: 10,
    );

    for (final item in vietnameseItems) {
      print('  ID: ${item['id']}, Name: ${item['name']}, Price: \$${item['price']}, Category ID: ${item['category_id']}');
    }

    // Check using MenuService
    print('\n🔧 Testing MenuService:');
    final serviceCategories = await menuService.getCategories();
    print('Categories from service: ${serviceCategories.length}');
    serviceCategories.forEach((id, name) {
      print('  - $name (ID: $id)');
    });

    final allMenuItems = await menuService.getAllMenuItems();
    print('\nMenu items from service: ${allMenuItems.length}');

    // Show first 5 items from service
    for (int i = 0; i < (allMenuItems.length > 5 ? 5 : allMenuItems.length); i++) {
      final item = allMenuItems[i];
      print('  - ${item.name} (\$${item.price}) [${item.categoryName}]');
    }

    // Check for specific Vietnamese items
    print('\n🔍 Looking for specific Vietnamese items:');
    final searchItems = ['Trà sữa', 'Matcha', 'Americano', 'Cà Phê'];
    for (final searchTerm in searchItems) {
      final found = await db.query(
        'menu_items',
        where: 'name LIKE ?',
        whereArgs: ['%$searchTerm%'],
      );
      print('  Items containing "$searchTerm": ${found.length}');
      for (final item in found.take(3)) {
        print('    - ${item['name']} (\$${item['price']})');
      }
    }

  } catch (e, stackTrace) {
    print('❌ Error during database debug: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}