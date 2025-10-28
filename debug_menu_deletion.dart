#!/usr/bin/env dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/supabase_service.dart';

/// 🐛 Standalone debugging script to investigate menu item deletion issue
///
/// This script will help us understand why the deletion logic thinks there are
/// active orders when the UI shows none.
///
/// Run with: dart debug_menu_deletion.dart

Future<void> main() async {
  print('🔍 OishiMenu Debug: Menu Item Deletion Investigation');
  print('═══════════════════════════════════════════════════════');

  try {
    // Initialize Supabase (you'll need to provide your credentials)
    print('⚠️  NOTE: This script needs Supabase credentials to run.');
    print('   Please add your Supabase URL and anon key below, or run this through your main app.');
    print('');

    // TODO: Replace with your actual Supabase credentials
    const supabaseUrl = 'YOUR_SUPABASE_URL';
    const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

    if (supabaseUrl == 'YOUR_SUPABASE_URL') {
      print('❌ Please update the Supabase credentials in this script.');
      print('   Alternatively, run the debugging through your main app using the TestResultsPage.');
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    print('✅ Supabase initialized successfully');

    // Create service instance
    final service = SupabaseMenuService();

    // Get all menu items
    print('\n📋 Step 1: Getting all menu items...');
    final menuItems = await service.getMenuItems();
    print('Found ${menuItems.length} menu items');

    if (menuItems.isEmpty) {
      print('❌ No menu items found to debug with');
      return;
    }

    // Debug the first menu item (or you can specify a particular one)
    final testMenuItem = menuItems.first;
    print('\n🔍 Debugging menu item: "${testMenuItem.name}" (ID: ${testMenuItem.id})');
    print('═══════════════════════════════════════════════════════');

    // Call our debugging method
    await service.debugMenuItemDeletion(testMenuItem.id);

    print('\n✅ Debug investigation completed!');
    print('Check the output above for detailed information about the database state.');

  } catch (e) {
    print('❌ Debug script failed: $e');
    print('\nTroubleshooting:');
    print('1. Make sure your Supabase credentials are correct');
    print('2. Ensure your database is accessible');
    print('3. Check that the SupabaseService is properly configured');
  }
}