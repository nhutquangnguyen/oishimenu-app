import 'dart:io';
import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/menu_option_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔍 Debugging option groups specifically...');

  try {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final menuOptionService = MenuOptionService();

    // Direct database check for option groups
    print('\n📊 Direct database query for option_groups:');
    final optionGroupsDB = await db.query('option_groups', orderBy: 'id');
    print('Found ${optionGroupsDB.length} option groups in database:');
    for (final group in optionGroupsDB) {
      print('  ID: ${group['id']}, Name: ${group['name']}, Active: ${group['is_active']}');
    }

    // Direct database check for menu options
    print('\n🎯 Direct database query for menu_options:');
    final optionsDB = await db.query('menu_options', orderBy: 'id');
    print('Found ${optionsDB.length} menu options in database:');
    for (final option in optionsDB) {
      print('  ID: ${option['id']}, Name: ${option['name']}, Price: \$${option['price']}');
    }

    // Check junction table
    print('\n🔗 Direct database query for option_group_options:');
    final junctionDB = await db.query('option_group_options', orderBy: 'id');
    print('Found ${junctionDB.length} option group-option relationships:');
    for (final junction in junctionDB) {
      print('  ID: ${junction['id']}, Group ID: ${junction['option_group_id']}, Option ID: ${junction['option_id']}');
    }

    // Test MenuOptionService
    print('\n🔧 Testing MenuOptionService:');
    final serviceOptionGroups = await menuOptionService.getAllOptionGroups();
    print('MenuOptionService returned ${serviceOptionGroups.length} option groups:');
    for (final group in serviceOptionGroups) {
      print('  - ${group.name} (${group.options.length} options):');
      for (final option in group.options) {
        print('    * ${option.name} (+\$${option.price})');
      }
    }

    if (serviceOptionGroups.isEmpty) {
      print('\n❌ MenuOptionService is returning empty list!');
      print('This explains why the UI shows "No option groups yet"');

      // Check if the service method has an issue
      print('\n🔍 Let\'s check what\'s wrong with the service...');

      // Try to get just one option group directly
      final firstGroup = await db.query('option_groups', limit: 1);
      if (firstGroup.isNotEmpty) {
        final groupId = firstGroup.first['id'];
        print('Found group with ID: $groupId');

        final optionsForGroup = await menuOptionService.getOptionsForGroup(groupId.toString());
        print('Options for this group: ${optionsForGroup.length}');
      }
    }

  } catch (e, stackTrace) {
    print('❌ Error during option groups debug: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}