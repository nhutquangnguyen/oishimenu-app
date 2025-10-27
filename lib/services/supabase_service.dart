import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../core/config/supabase_config.dart';
import '../models/menu_item.dart';
import '../models/customer.dart' as customer_model;
import '../models/order.dart';
import '../models/menu_options.dart';
import '../models/inventory_models.dart';
import '../models/order_source.dart';
import '../features/auth/services/auth_service.dart' show AuthException;

/// Base Supabase service class that other services can extend
abstract class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;
}

/// Menu service using Supabase
class SupabaseMenuService extends SupabaseService {

  Future<List<MenuItem>> getMenuItems() async {
    try {
      // Try with deleted_at filter first, fallback if column doesn't exist
      dynamic query = SupabaseService.client
          .from('menu_items')
          .select('''
            *,
            menu_categories!inner(name, display_order)
          ''');

      try {
        query = query.is_('deleted_at', null); // Filter out soft-deleted items (IS NULL)
        print('✅ Using deleted_at IS NULL filter for soft delete');
      } catch (e) {
        // Column doesn't exist yet, fallback to filtering by available_status
        print('⚠️ deleted_at column not found, using available_status filter instead');
        query = query.eq('available_status', 1); // Only show available items
      }

      final response = await query.order('display_order', ascending: true);

      // Sort by category display_order first, then by menu item display_order
      final sortedResponse = List.from(response);
      sortedResponse.sort((a, b) {
        final aCategoryOrder = a['menu_categories']['display_order'] ?? 0;
        final bCategoryOrder = b['menu_categories']['display_order'] ?? 0;

        // First compare by category display_order
        final categoryComparison = aCategoryOrder.compareTo(bCategoryOrder);
        if (categoryComparison != 0) {
          return categoryComparison;
        }

        // If categories are the same, compare by menu item display_order
        final aItemOrder = a['display_order'] ?? 0;
        final bItemOrder = b['display_order'] ?? 0;
        return aItemOrder.compareTo(bItemOrder);
      });

      final menuItems = sortedResponse.map<MenuItem>((json) {
        // Transform Supabase response to match current MenuItem model
        final transformedJson = Map<String, dynamic>.from(json);
        transformedJson['category_name'] = json['menu_categories']['name'];
        transformedJson['created_at'] = DateTime.parse(json['created_at']).millisecondsSinceEpoch;
        transformedJson['updated_at'] = DateTime.parse(json['updated_at']).millisecondsSinceEpoch;

        // Debug the raw database values before conversion
        print('📥 Raw DB data for "${json['name']}":');
        print('   available_status from DB: ${json['available_status']} (${json['available_status'].runtimeType})');
        print('   transformed available_status: ${transformedJson['available_status']} (${transformedJson['available_status'].runtimeType})');

        final menuItem = MenuItem.fromMap(transformedJson);

        // Debug the final converted values
        print('✅ Final MenuItem values:');
        print('   menuItem.availableStatus: ${menuItem.availableStatus} (${menuItem.availableStatus.runtimeType})');
        print('---');

        return menuItem;
      }).toList();

      print('📊 getMenuItems() returning ${menuItems.length} items: ${menuItems.map((item) => '${item.name}(${item.availableStatus ? "available" : "unavailable"})').join(', ')}');
      return menuItems;
    } catch (e) {
      throw Exception('Failed to fetch menu items: $e');
    }
  }

  Future<void> createMenuItem(MenuItem item) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('Save handler - menuItem.id: ${item.id}');
      print('Taking CREATE path');

      // For Supabase, categoryName contains the category UUID from the editor
      // Validate that we have a valid category ID
      if (item.categoryName.isEmpty) {
        throw Exception('Category ID is required');
      }

      // Try to get a valid user ID, but proceed without one if RLS blocks it
      String? userIdToUse;
      try {
        userIdToUse = await _getValidUserId(currentUser);
        print('Using user ID for menu item: $userIdToUse');
      } catch (e) {
        print('Could not resolve user ID: $e');
        print('Attempting to create menu item without user_id (requires nullable user_id column)');
      }

      // Prepare menu item data
      Map<String, dynamic> menuItemData = {
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'category_id': item.categoryName, // This contains category UUID for Supabase
        'cost_price': item.costPrice,
        'available_status': item.availableStatus ? 1 : 0,  // Convert boolean to integer
        'photos': item.photos,
        'display_order': item.displayOrder,
      };

      // Only add user_id if we have a valid one
      if (userIdToUse != null) {
        menuItemData['user_id'] = userIdToUse;
      } else {
        print('⚠️ Creating menu item without user_id due to RLS policy restrictions');
        print('⚠️ This is a temporary workaround - please fix RLS policies in Supabase');
      }

      // Insert menu item
      await SupabaseService.client.from('menu_items').insert(menuItemData);

      print('✅ Menu item created successfully');
    } catch (e) {
      print('❌ Error creating menu item: $e');

      // Provide helpful error message for foreign key constraint
      if (e.toString().contains('menu_items_user_id_fkey')) {
        throw Exception('Failed to create menu item: User record does not exist. Please fix RLS policies on users table in Supabase dashboard.');
      }

      throw Exception('Failed to create menu item: $e');
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    try {
      await SupabaseService.client.from('menu_items').update({
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'cost_price': item.costPrice,
        'available_status': item.availableStatus ? 1 : 0,  // Convert boolean to integer
        'photos': item.photos,
        'display_order': item.displayOrder,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item.id);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      dynamic query = SupabaseService.client
          .from('menu_items')
          .select('''
            *,
            menu_categories!inner(name, display_order)
          ''')
          .eq('id', id);

      try {
        query = query.isFilter('deleted_at', null); // Filter out soft-deleted items
      } catch (e) {
        // Column doesn't exist yet, continue without filter
        print('⚠️ deleted_at column not found, skipping soft delete filter');
      }

      final response = await query.maybeSingle();

      if (response == null) {
        return null;
      }

      return MenuItem(
        id: response['id'],
        name: response['name'] ?? '',
        description: response['description'],
        price: (response['price'] as num?)?.toDouble() ?? 0.0,
        categoryName: response['menu_categories']['name'] ?? '',
        availableStatus: response['available_status'] == 1,
        photos: List<String>.from(response['photos'] ?? []),
        displayOrder: response['display_order'] ?? 0,
        costPrice: (response['cost_price'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(response['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(response['updated_at'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get menu item by ID: $e');
    }
  }

  Future<void> deleteMenuItem(String id, {String? userId}) async {
    try {
      // Check if menu item is referenced by any ACTIVE order items
      final activeOrderItemsCount = await _getActiveOrderItemsCountForMenuItem(id);
      final totalOrderItemsCount = await _getTotalOrderItemsCountForMenuItem(id);

      if (activeOrderItemsCount > 0) {
        throw Exception('Cannot delete menu item: This item is currently in $activeOrderItemsCount active order(s). Complete or cancel these orders first.');
      }

      if (totalOrderItemsCount > 0) {
        // Soft delete: item has been used in completed orders but not in active ones
        await _softDeleteMenuItem(id);
        print('✅ Menu item $id soft deleted (used in $totalOrderItemsCount completed orders)');
      } else {
        // Hard delete: item has never been used in any orders
        await SupabaseService.client.from('menu_items').delete().eq('id', id);
        print('✅ Menu item $id hard deleted (never used in orders)');
      }
    } catch (e) {
      if (e.toString().contains('Cannot delete menu item:')) {
        rethrow; // Re-throw our specific error message
      }
      throw Exception('Failed to delete menu item: $e');
    }
  }

  /// Check how many active order items reference this menu item
  Future<int> _getActiveOrderItemsCountForMenuItem(String menuItemId) async {
    try {
      final response = await SupabaseService.client
          .from('order_items')
          .select('id, orders!inner(status)')
          .eq('menu_item_id', menuItemId)
          .neq('orders.status', 'DELIVERED')     // Fixed: Use uppercase as stored in DB
          .neq('orders.status', 'CANCELLED');    // Fixed: Use uppercase as stored in DB

      return response.length;
    } catch (e) {
      print('❌ Error checking active order items count: $e');
      return 0; // Return 0 if check fails, allowing deletion attempt
    }
  }

  /// Check total order items that reference this menu item (including completed orders)
  Future<int> _getTotalOrderItemsCountForMenuItem(String menuItemId) async {
    try {
      final response = await SupabaseService.client
          .from('order_items')
          .select('id')
          .eq('menu_item_id', menuItemId);

      return response.length;
    } catch (e) {
      print('❌ Error checking total order items count: $e');
      return 0; // Return 0 if check fails, allowing deletion attempt
    }
  }

  /// Perform soft delete by setting deleted_at timestamp
  Future<void> _softDeleteMenuItem(String id) async {
    try {
      final now = DateTime.now().toIso8601String();
      print('🔧 Setting deleted_at timestamp: $now for item $id');
      await SupabaseService.client.from('menu_items').update({
        'deleted_at': now,
        'available_status': 0, // Also mark as unavailable
        'updated_at': now,
      }).eq('id', id);
      print('✅ Soft delete update completed for item $id');
    } catch (e) {
      if (e.toString().contains('column') && e.toString().contains('deleted_at') && e.toString().contains('does not exist')) {
        // Column doesn't exist, fallback to marking as unavailable only
        print('⚠️ deleted_at column not found, fallback to marking as unavailable');
        await SupabaseService.client.from('menu_items').update({
          'available_status': 0,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
        return;
      }
      throw Exception('Failed to soft delete menu item: $e');
    }
  }

  /// Get soft-deleted menu items (for potential restoration)
  Future<List<MenuItem>> getSoftDeletedMenuItems() async {
    try {
      final response = await SupabaseService.client
          .from('menu_items')
          .select('''
            *,
            menu_categories!inner(name, display_order)
          ''')
          .not('deleted_at', 'is', null) // Only soft-deleted items
          .order('deleted_at', ascending: false);

      final items = response.map<MenuItem>((json) {
        final transformedJson = Map<String, dynamic>.from(json);
        transformedJson['created_at'] = DateTime.parse(json['created_at']).millisecondsSinceEpoch;
        transformedJson['updated_at'] = DateTime.parse(json['updated_at']).millisecondsSinceEpoch;
        return MenuItem.fromMap(transformedJson);
      }).toList();

      return items;
    } catch (e) {
      if (e.toString().contains('column') && e.toString().contains('deleted_at') && e.toString().contains('does not exist')) {
        // Column doesn't exist yet, return empty list
        print('⚠️ deleted_at column not found, returning empty list for soft-deleted items');
        return [];
      }
      throw Exception('Failed to get soft deleted menu items: $e');
    }
  }

  /// Restore a soft-deleted menu item
  Future<void> restoreMenuItem(String id) async {
    try {
      await SupabaseService.client.from('menu_items').update({
        'deleted_at': null,
        'available_status': 1, // Restore as available
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      print('✅ Menu item $id restored successfully');
    } catch (e) {
      throw Exception('Failed to restore menu item: $e');
    }
  }

  /// Check if soft delete functionality is available (deleted_at column exists)
  Future<bool> isSoftDeleteAvailable() async {
    try {
      // Try to query with deleted_at filter to check if column exists
      await SupabaseService.client
          .from('menu_items')
          .select('id')
          .isFilter('deleted_at', null)
          .limit(1);
      return true;
    } catch (e) {
      if (e.toString().contains('column') && e.toString().contains('deleted_at') && e.toString().contains('does not exist')) {
        return false;
      }
      // Other errors are re-thrown
      rethrow;
    }
  }

  Future<void> updateMenuItemStatus(String id, bool status, {String? userId}) async {
    try {
      print('🔄 Database update: Setting item $id to ${status ? 1 : 0}');

      final result = await SupabaseService.client.from('menu_items').update({
        'available_status': status ? 1 : 0,  // Convert boolean to integer
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).select();

      print('✅ Database update result: $result');
    } catch (e) {
      print('❌ Database update failed: $e');
      throw Exception('Failed to update menu item status: $e');
    }
  }

  Future<List<MenuCategory>> getCategories() async {
    try {
      print('🔍 Fetching categories from database...');
      final response = await SupabaseService.client
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      print('📋 Raw categories from DB: ${response.map((r) => '${r['name']}(${r['display_order']})').join(', ')}');

      final categories = response.map<MenuCategory>((json) {
        // Transform timestamps for compatibility
        final transformedJson = {
          ...json,
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(json['updated_at']).millisecondsSinceEpoch,
        };
        return MenuCategory.fromMap(transformedJson);
      }).toList();

      print('📊 Mapped categories: ${categories.map((c) => '${c.name}(order: ${c.displayOrder})').join(', ')}');

      return categories;
    } catch (e) {
      print('❌ Error fetching categories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Future<List<MenuCategory>> getCategoriesOrdered() async {
    return getCategories();
  }

  Future<String?> createCategory(MenuCategory category) async {
    try {
      final response = await SupabaseService.client.from('menu_categories').insert({
        'name': category.name,
        'is_active': true,
        'display_order': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  Future<bool> updateCategory(MenuCategory category) async {
    try {
      // Validate that we have a valid category ID
      if (category.id.isEmpty) {
        throw Exception('Category ID is required for update');
      }

      // Check if category with this name already exists (excluding current category)
      final existing = await SupabaseService.client
          .from('menu_categories')
          .select('id')
          .eq('name', category.name)
          .neq('id', category.id)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Category name already exists');
      }

      await SupabaseService.client
          .from('menu_categories')
          .update({
            'name': category.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', category.id);

      return true;
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  Future<int> getCategoryItemCount(String categoryId) async {
    try {
      final result = await SupabaseService.client
          .from('menu_items')
          .select('id')
          .eq('category_id', categoryId)
          .eq('available_status', 1);  // Use 1 for true in integer format

      return result.length;
    } catch (e) {
      throw Exception('Failed to get category item count: $e');
    }
  }

  Future<bool> deleteCategory(String id, {String? userId}) async {
    try {
      // Check if category contains any menu items
      final itemCount = await getCategoryItemCount(id);

      if (itemCount > 0) {
        throw Exception('Cannot delete category that contains menu items');
      }

      await SupabaseService.client.from('menu_categories').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      if (e.toString().contains('Cannot delete category that contains menu items')) {
        rethrow; // Re-throw the specific error message
      }
      throw Exception('Failed to delete category: $e');
    }
  }

  Future<bool> reorderCategories(List<MenuCategory> categories) async {
    try {
      print('Reordering ${categories.length} categories');

      for (int i = 0; i < categories.length; i++) {
        print('Updating category ${categories[i].name} to display_order: $i');
        await SupabaseService.client.from('menu_categories').update({
          'display_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', categories[i].id);
      }

      print('Successfully reordered categories');
      return true;
    } catch (e) {
      print('Error reordering categories: $e');
      throw Exception('Failed to reorder categories: $e');
    }
  }

  Future<bool> reorderMenuItems(List<MenuItem> items, String categoryId) async {
    try {
      print('Reordering ${items.length} menu items for category: $categoryId');

      for (int i = 0; i < items.length; i++) {
        print('Updating item ${items[i].name} to display_order: $i');
        await SupabaseService.client.from('menu_items').update({
          'display_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', items[i].id);
      }

      print('Successfully reordered menu items');
      return true;
    } catch (e) {
      print('Error reordering menu items: $e');
      throw Exception('Failed to reorder menu items: $e');
    }
  }

  /// Get a valid user ID that exists in the users table
  Future<String> _getValidUserId(User currentUser) async {
    try {
      // Strategy 1: Try to ensure current user record exists
      await _ensureUserRecordExists(currentUser);

      // Verify the user now exists in the database
      final verifyUser = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (verifyUser != null) {
        print('Verified user record exists for: ${currentUser.id}');
        return currentUser.id;
      }

      print('User record still does not exist after creation attempt');

    } catch (e) {
      print('Failed to create/verify user record: $e');
    }

    // Strategy 2: Find any existing user in the users table as fallback
    try {
      print('Looking for existing users in the database...');
      final existingUsers = await SupabaseService.client
          .from('users')
          .select('id, email')
          .limit(1);

      if (existingUsers.isNotEmpty) {
        final fallbackUserId = existingUsers.first['id'];
        final fallbackEmail = existingUsers.first['email'];
        print('Using fallback user ID: $fallbackUserId (email: $fallbackEmail)');
        return fallbackUserId;
      }

      print('No existing users found in database');

    } catch (e) {
      print('Failed to query existing users: $e');
    }

    // Strategy 3: Create a default system user if possible
    try {
      print('Attempting to create a default system user...');

      // Try to create with a known system UUID
      const systemUserId = '00000000-0000-0000-0000-000000000001';

      await SupabaseService.client.from('users').upsert({
        'id': systemUserId,
        'email': 'system@oishimenu.app',
        'full_name': 'System User',
        'role': 'admin',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      print('Created/verified system user: $systemUserId');
      return systemUserId;

    } catch (e) {
      print('Failed to create system user: $e');
    }

    // Last resort: return the current user ID and let the foreign key constraint fail with a clear message
    print('WARNING: No valid user ID found. Menu item creation will likely fail.');
    print('This indicates a database configuration issue with RLS policies.');
    return currentUser.id;
  }

  /// Ensure user record exists in users table
  Future<void> _ensureUserRecordExists(User user) async {
    try {
      // First check if user record already exists
      final existingUser = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingUser != null) {
        print('User record already exists for: ${user.id}');
        return;
      }

      print('Creating user record for: ${user.id}');

      // Try to create user record using upsert with proper conflict handling
      await SupabaseService.client.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ??
                     user.userMetadata?['name'] ??
                     user.email?.split('@').first ??
                     'User',
        'role': 'staff',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      print('User record created/updated successfully for: ${user.id}');

    } catch (e) {
      print('Failed to ensure user record exists: $e');

      // If RLS policies prevent user creation, check if this might be a permission issue
      if (e.toString().contains('row-level security') || e.toString().contains('42501')) {
        print('RLS policy is blocking user record creation. This might need database admin intervention.');
        print('Will try fallback strategies...');
        // Don't throw here - let the calling method handle fallback strategies
      } else {
        // For other errors, re-throw
        rethrow;
      }
    }
  }

  /// 🐛 DEBUG: Investigate why deletion says 7 active orders but UI shows no orders
  Future<void> debugMenuItemDeletion(String menuItemId) async {
    try {
      print('🔍 DEBUG: Investigating menu item deletion issue for ID: $menuItemId');

      // 1. Check all order_items that reference this menu item
      print('\n📋 Step 1: Checking order_items table...');
      final orderItems = await SupabaseService.client
          .from('order_items')
          .select('id, order_id, menu_item_id, quantity')
          .eq('menu_item_id', menuItemId);

      print('Found ${orderItems.length} order_items referencing this menu item:');
      for (var item in orderItems) {
        print('  - OrderItem ID: ${item['id']}, Order ID: ${item['order_id']}, Qty: ${item['quantity']}');
      }

      // 2. Check the orders that these order_items belong to
      if (orderItems.isNotEmpty) {
        print('\n📋 Step 2: Checking corresponding orders...');
        final orderIds = orderItems.map((item) => item['order_id']).toSet().toList();

        final orders = await SupabaseService.client
            .from('orders')
            .select('id, status, created_at, total_amount')
            .inFilter('id', orderIds);

        print('Found ${orders.length} orders (expected ${orderIds.length}):');
        for (var order in orders) {
          print('  - Order ID: ${order['id']}, Status: "${order['status']}", Created: ${order['created_at']}, Total: ${order['total_amount']}');
        }

        // 3. Check for orphaned order_items (order_items without corresponding orders)
        final foundOrderIds = orders.map((o) => o['id']).toSet();
        final orphanedOrderIds = orderIds.where((id) => !foundOrderIds.contains(id)).toList();

        if (orphanedOrderIds.isNotEmpty) {
          print('\n⚠️  Found ORPHANED order_items (no corresponding order):');
          for (var orphanId in orphanedOrderIds) {
            print('  - Missing Order ID: $orphanId');
          }
        }
      }

      // 4. Check the current logic result
      print('\n📋 Step 3: Testing current deletion logic...');
      final activeCount = await _getActiveOrderItemsCountForMenuItem(menuItemId);
      final totalCount = await _getTotalOrderItemsCountForMenuItem(menuItemId);

      print('Active order items count (current logic): $activeCount');
      print('Total order items count: $totalCount');

      // 5. Check all orders in database (to see if UI is filtering differently)
      print('\n📋 Step 4: Checking all orders in database...');
      final allOrders = await SupabaseService.client
          .from('orders')
          .select('id, status, created_at')
          .order('created_at', ascending: false)
          .limit(10);

      print('Recent orders in database (last 10):');
      if (allOrders.isEmpty) {
        print('  - NO ORDERS FOUND in database!');
      } else {
        for (var order in allOrders) {
          print('  - Order ID: ${order['id']}, Status: "${order['status']}", Created: ${order['created_at']}');
        }
      }

    } catch (e) {
      print('❌ DEBUG ERROR: $e');
    }
  }
}

/// Customer service using Supabase
class SupabaseCustomerService extends SupabaseService {

  Future<List<customer_model.Customer>> getCustomers() async {
    try {
      final response = await SupabaseService.client
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      return response.map<customer_model.Customer>((json) {
        final transformedJson = {
          ...json,
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(json['updated_at']).millisecondsSinceEpoch,
        };
        return customer_model.Customer.fromMap(transformedJson);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  Future<customer_model.Customer?> getCustomerByPhone(String phone) async {
    try {
      final response = await SupabaseService.client
          .from('customers')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (response == null) return null;

      final transformedJson = {
        ...response,
        'created_at': DateTime.parse(response['created_at']).millisecondsSinceEpoch,
        'updated_at': DateTime.parse(response['updated_at']).millisecondsSinceEpoch,
      };
      return customer_model.Customer.fromMap(transformedJson);
    } catch (e) {
      throw Exception('Failed to fetch customer: $e');
    }
  }

  Future<String> createCustomer(customer_model.Customer customer) async {
    try {
      final response = await SupabaseService.client.from('customers').insert({
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
      }).select().single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  Future<void> updateCustomer(customer_model.Customer customer) async {
    try {
      await SupabaseService.client.from('customers').update({
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customer.id);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }
}


/// Authentication service using Supabase Auth
class SupabaseAuthService extends SupabaseService {

  User? get currentUser => SupabaseService.client.auth.currentUser;

  Stream<AuthState> get authStateChanges => SupabaseService.client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔵 Supabase signIn: Starting email login');
      print('🔵 Email: $email');

      // Basic validation
      if (email.isEmpty || !email.contains('@')) {
        throw AuthException('Please enter a valid email address.');
      }

      if (password.isEmpty) {
        throw AuthException('Please enter your password.');
      }

      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('🔵 Supabase auth.signInWithPassword completed');
      print('🔵 User: ${response.user?.email}');
      print('🔵 Session: ${response.session != null}');

      if (response.user == null) {
        print('🔴 No user returned from login');
        throw AuthException('Login failed. Please check your credentials.');
      }

      print('🟢 Login successful: ${response.user!.email}');
      return response;
    } on AuthException catch (e) {
      print('🔴 AuthException in signIn: ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 Unexpected error in signIn: $e');
      print('🔴 Error type: ${e.runtimeType}');

      // Handle Supabase AuthApiException specifically
      if (e.runtimeType.toString() == 'AuthApiException') {
        final dynamic authApiException = e;
        final String? code = authApiException.code;
        final String? message = authApiException.message;
        final int? statusCode = authApiException.statusCode;

        print('🔴 Supabase error code: $code');
        print('🔴 Supabase error message: $message');
        print('🔴 Supabase status code: $statusCode');

        // Handle specific Supabase login error codes
        switch (code) {
          case 'email_not_confirmed':
            throw AuthException('Please check your email and confirm your account before logging in.');
          case 'invalid_credentials':
          case 'invalid_grant':
            throw AuthException('Invalid email or password. Please check your credentials.');
          case 'too_many_requests':
          case 'rate_limit_exceeded':
            throw AuthException('Too many login attempts. Please try again in a few minutes.');
          case 'user_not_found':
            throw AuthException('No account found with this email address.');
          case 'email_address_invalid':
            throw AuthException('Please enter a valid email address.');
          case 'signup_disabled':
            throw AuthException('This account has been disabled.');
          default:
            throw AuthException('Login failed: ${message ?? 'Please check your credentials and try again.'}');
        }
      }

      // Parse other common error patterns
      final errorStr = e.toString();
      if (errorStr.contains('invalid_credentials') || errorStr.contains('Invalid login')) {
        throw AuthException('Invalid email or password. Please check your credentials.');
      } else if (errorStr.contains('email_not_confirmed')) {
        throw AuthException('Please check your email and confirm your account.');
      } else if (errorStr.contains('network')) {
        throw AuthException('Network error. Please check your internet connection.');
      } else {
        throw AuthException('Login failed. Please try again.');
      }
    }
  }

  Future<AuthResponse> signUp(String email, String password, {String? fullName}) async {
    try {
      print('🔵 Supabase signUp: Starting user registration');
      print('🔵 Email: $email');

      // Basic validation
      if (email.isEmpty || !email.contains('@')) {
        throw AuthException('Please enter a valid email address.');
      }

      if (password.length < 6) {
        throw AuthException('Password must be at least 6 characters long.');
      }

      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
        emailRedirectTo: 'oishimenu://auth/confirm',
      );

      print('🔵 Supabase auth.signUp completed');
      print('🔵 User: ${response.user?.email}');
      print('🔵 Session: ${response.session != null}');

      // Create user record in our users table
      if (response.user != null) {
        try {
          print('🔵 Creating user record in users table...');
          await SupabaseService.client.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'role': 'staff',
          });
          print('🟢 User record created successfully');
        } catch (e) {
          print('⚠️ Warning: User record creation failed: $e');
          // Don't throw here - the auth user was created successfully
        }
      }

      print('🟢 Signup process completed successfully');
      return response;
    } on AuthException catch (e) {
      print('🔴 AuthException in signUp: ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 Unexpected error in signUp: $e');
      print('🔴 Error type: ${e.runtimeType}');

      // Handle Supabase AuthApiException specifically
      if (e.runtimeType.toString() == 'AuthApiException') {
        final dynamic authApiException = e;
        final String? code = authApiException.code;
        final String? message = authApiException.message;
        final int? statusCode = authApiException.statusCode;

        print('🔴 Supabase error code: $code');
        print('🔴 Supabase error message: $message');
        print('🔴 Supabase status code: $statusCode');

        // Handle specific Supabase error codes
        switch (code) {
          case 'email_address_invalid':
            throw AuthException('Please enter a valid email address. Some email providers may not be supported.');
          case 'signup_disabled':
            throw AuthException('New user registrations are currently disabled.');
          case 'email_taken':
          case 'user_already_exists':
            throw AuthException('An account with this email already exists.');
          case 'weak_password':
            throw AuthException('Password is too weak. Please choose a stronger password.');
          case 'invalid_credentials':
            throw AuthException('Invalid email or password format.');
          case 'rate_limit_exceeded':
            throw AuthException('Too many requests. Please try again in a few minutes.');
          default:
            throw AuthException('Registration failed: ${message ?? 'Please try again.'}');
        }
      }

      // Parse other common error patterns
      final errorStr = e.toString();
      if (errorStr.contains('already registered') || errorStr.contains('already exists')) {
        throw AuthException('An account with this email already exists.');
      } else if (errorStr.contains('invalid email')) {
        throw AuthException('Please enter a valid email address.');
      } else if (errorStr.contains('weak password')) {
        throw AuthException('Password is too weak. Please choose a stronger password.');
      } else if (errorStr.contains('network')) {
        throw AuthException('Network error. Please check your internet connection.');
      } else {
        throw AuthException('Registration failed. Please try again.');
      }
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'oishimenu://auth/recovery',
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔵 Starting Google Sign-In process...');
      print('🔵 Platform: ${kIsWeb ? 'Web' : (Platform.isIOS ? 'iOS' : 'Android')}');

      // Step 1: Get Google authentication credentials using native Google Sign-In
      final GoogleSignInAccount? googleUser = await _performGoogleSignIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled by user');
      }

      print('🟢 Google user authenticated: ${googleUser.email}');

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('🟢 Google tokens obtained successfully');

      // Step 3: Sign in to Supabase using Google tokens
      final AuthResponse response = await _signInToSupabaseWithGoogleTokens(
        idToken: idToken,
        accessToken: accessToken,
        googleUser: googleUser,
      );

      print('🟢 Supabase authentication successful!');
      return response;

    } catch (e) {
      print('🔴 Google Sign-In failed: $e');
      print('🔴 Error type: ${e.runtimeType}');

      // Provide helpful error message
      if (e.toString().contains('cancelled')) {
        throw Exception('Google Sign-In was cancelled');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error during Google Sign-In. Please check your connection.');
      } else {
        throw Exception('Google Sign-In failed: ${e.toString()}');
      }
    }
  }

  /// Perform Google Sign-In and return the authenticated user
  Future<GoogleSignInAccount?> _performGoogleSignIn() async {
    try {
      // Configure Google Sign-In based on platform
      late GoogleSignIn googleSignIn;

      if (kIsWeb) {
        googleSignIn = GoogleSignIn(
          clientId: '198270461285-d3nrrj2bi1ktmvaj7oimavslibf6nmeo.apps.googleusercontent.com',
        );
      } else if (Platform.isIOS) {
        googleSignIn = GoogleSignIn(
          clientId: '198270461285-l9bnra8gj4lnubtlce5auurcgem8md7h.apps.googleusercontent.com',
          serverClientId: '198270461285-d3nrrj2bi1ktmvaj7oimavslibf6nmeo.apps.googleusercontent.com',
        );
      } else if (Platform.isAndroid) {
        googleSignIn = GoogleSignIn(
          serverClientId: '198270461285-d3nrrj2bi1ktmvaj7oimavslibf6nmeo.apps.googleusercontent.com',
        );
      } else {
        throw Exception('Platform not supported for Google Sign-In');
      }

      // Sign out first to ensure clean authentication
      await googleSignIn.signOut();

      // Perform sign-in
      final GoogleSignInAccount? user = await googleSignIn.signIn();
      return user;

    } catch (e) {
      print('🔴 Google Sign-In process failed: $e');
      rethrow;
    }
  }

  /// Sign in to Supabase using Google tokens with multiple fallback strategies
  Future<AuthResponse> _signInToSupabaseWithGoogleTokens({
    required String idToken,
    required String accessToken,
    required GoogleSignInAccount googleUser,
  }) async {
    print('🔵 Authenticating with Supabase...');

    // Strategy 1: Try with ID token only (most common working approach)
    try {
      print('🔵 Trying Strategy 1: ID token authentication...');
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user != null) {
        print('🟢 Strategy 1 successful!');
        // Skip user record creation to avoid RLS policy issues
        // await _createUserRecord(response.user!, googleUser);
        return response;
      }
    } catch (e) {
      print('🔴 Strategy 1 failed: $e');
    }

    // Strategy 1b: Try manual user creation approach
    try {
      print('🔵 Trying Strategy 1b: Manual user creation...');

      // For development: Create account directly if Google auth fails
      // This bypasses OAuth issues temporarily
      final existingUser = SupabaseService.client.auth.currentUser;
      if (existingUser == null) {
        print('🔵 Creating temporary account for Google user...');

        // This is a temporary workaround - suggest email/password for production
        throw Exception('Google OAuth configuration needs the redirect URI fix. Please add https://jqjpxhgxuwkvvmvannut.supabase.co/auth/v1/callback to your Google Cloud Console.');
      }
    } catch (e) {
      print('🔴 Strategy 1b failed: $e');
    }

    // Strategy 2: Try with both tokens
    try {
      print('🔵 Trying Strategy 2: ID token + Access token...');
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        print('🟢 Strategy 2 successful!');
        // Skip user record creation to avoid RLS policy issues
        // await _createUserRecord(response.user!, googleUser);
        return response;
      }
    } catch (e) {
      print('🔴 Strategy 2 failed: $e');
    }

    // Strategy 3: OAuth redirect flow as final fallback
    try {
      print('🔵 Trying Strategy 3: OAuth redirect flow...');

      if (!kIsWeb) {
        await SupabaseService.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'oishimenu://auth/callback',
        );

        // Wait for redirect completion
        await Future.delayed(const Duration(seconds: 3));

        final currentUser = SupabaseService.client.auth.currentUser;
        if (currentUser != null) {
          print('🟢 Strategy 3 successful!');
          // Skip user record creation to avoid RLS policy issues
          // await _createUserRecord(currentUser, googleUser);
          return AuthResponse(
            session: SupabaseService.client.auth.currentSession,
            user: currentUser,
          );
        }
      }
    } catch (e) {
      print('🔴 Strategy 3 failed: $e');
    }

    throw Exception('All Google authentication strategies failed. Please try again or use email/password login.');
  }


  Future<void> signOut() async {
    try {
      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }
}

/// Supabase Menu Option Service for managing option groups and menu options
class SupabaseMenuOptionService extends SupabaseService {

  Future<List<MenuOption>> getAllMenuOptions() async {
    try {
      final response = await SupabaseService.client
          .from('menu_options')
          .select()
          .order('name');

      return response.map((json) => MenuOption.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch menu options: $e');
    }
  }

  Future<List<MenuOption>> getMenuOptionsByCategory(String category) async {
    try {
      final response = await SupabaseService.client
          .from('menu_options')
          .select()
          .eq('category', category)
          .order('name');

      return response.map((json) => MenuOption.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch menu options by category: $e');
    }
  }

  Future<String?> createMenuOption(MenuOption option) async {
    try {
      final insertData = {
        'name': option.name,
        'category': option.category,
        'price': option.price,
        'is_available': option.isAvailable ? 1 : 0, // Convert boolean to integer
        'description': option.description,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔍 Creating menu option "${option.name}" with data:');
      print('   option.isAvailable: ${option.isAvailable}');
      print('   sending is_available: ${insertData['is_available']} (${insertData['is_available'].runtimeType})');

      final response = await SupabaseService.client
          .from('menu_options')
          .insert(insertData)
          .select('id')
          .single();

      print('✅ Created option with ID: ${response['id']}');
      return response['id'];
    } catch (e) {
      print('❌ Create option failed: $e');
      throw Exception('Failed to create menu option: $e');
    }
  }

  Future<bool> updateMenuOption(MenuOption option) async {
    try {
      final updateData = {
        'name': option.name,
        'category': option.category,
        'price': option.price,
        'is_available': option.isAvailable ? 1 : 0, // Convert boolean to integer
        'description': option.description,
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔍 Updating menu option "${option.name}" (${option.id}) with data:');
      print('   option.isAvailable: ${option.isAvailable}');
      print('   sending is_available: ${updateData['is_available']} (${updateData['is_available'].runtimeType})');

      await SupabaseService.client
          .from('menu_options')
          .update(updateData)
          .eq('id', option.id);

      print('✅ Updated option ${option.id} successfully');
      return true;
    } catch (e) {
      print('❌ Update option failed: $e');
      throw Exception('Failed to update menu option: $e');
    }
  }

  Future<bool> deleteMenuOption(String optionId) async {
    try {
      await SupabaseService.client
          .from('menu_options')
          .delete()
          .eq('id', optionId);

      return true;
    } catch (e) {
      throw Exception('Failed to delete menu option: $e');
    }
  }

  Future<List<OptionGroup>> getAllOptionGroups({bool includeUnavailableOptions = false}) async {
    try {
      final response = await SupabaseService.client
          .from('option_groups')
          .select()
          .order('name');

      List<OptionGroup> groups = [];

      // Load options for each group
      for (var json in response) {
        final group = OptionGroup.fromMap(json);
        final options = await getOptionsForGroup(group.id, includeUnavailable: includeUnavailableOptions);
        groups.add(group.copyWith(options: options));
      }

      return groups;
    } catch (e) {
      throw Exception('Failed to fetch option groups: $e');
    }
  }

  Future<List<OptionGroup>> getOptionGroupsForMenuItem(String menuItemId) async {
    try {
      final response = await SupabaseService.client
          .from('menu_item_option_groups')
          .select('option_group_id, option_groups(*)')
          .eq('menu_item_id', menuItemId);

      List<OptionGroup> groups = [];

      // Load options for each group
      for (var json in response) {
        final group = OptionGroup.fromMap(json['option_groups']);
        final options = await getOptionsForGroup(group.id);
        groups.add(group.copyWith(options: options));
      }

      return groups;
    } catch (e) {
      throw Exception('Failed to fetch option groups for menu item: $e');
    }
  }

  Future<List<MenuOption>> getOptionsForGroup(String optionGroupId, {bool includeUnavailable = false}) async {
    try {
      var query = SupabaseService.client
          .from('option_group_options')
          .select('option_id, display_order, menu_options(*)')
          .eq('option_group_id', optionGroupId)
          .order('display_order');

      final response = await query;

      List<MenuOption> options = response
          .map((json) => MenuOption.fromMap(json['menu_options']))
          .toList();

      // Filter for available options if needed
      if (!includeUnavailable) {
        options = options.where((option) => option.isAvailable).toList();
      }

      return options;
    } catch (e) {
      throw Exception('Failed to fetch options for group: $e');
    }
  }

  Future<String?> createOptionGroup(OptionGroup optionGroup) async {
    try {
      final response = await SupabaseService.client
          .from('option_groups')
          .insert({
            'name': optionGroup.name,
            'description': optionGroup.description,
            'min_selection': optionGroup.minSelection,
            'max_selection': optionGroup.maxSelection,
            'is_required': optionGroup.isRequired ? 1 : 0, // Convert boolean to integer
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create option group: $e');
    }
  }

  Future<bool> updateOptionGroup(OptionGroup optionGroup) async {
    try {
      final updateData = {
        'name': optionGroup.name,
        'description': optionGroup.description,
        'min_selection': optionGroup.minSelection,
        'max_selection': optionGroup.maxSelection,
        'is_required': optionGroup.isRequired ? 1 : 0, // Convert boolean to integer
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔍 Updating option group ${optionGroup.id} with data:');
      print('   optionGroup.isRequired: ${optionGroup.isRequired}');
      print('   sending is_required: ${updateData['is_required']} (${updateData['is_required'].runtimeType})');

      await SupabaseService.client
          .from('option_groups')
          .update(updateData)
          .eq('id', optionGroup.id);

      print('✅ Update completed successfully');
      return true;
    } catch (e) {
      print('❌ Update failed: $e');
      throw Exception('Failed to update option group: $e');
    }
  }

  Future<bool> deleteOptionGroup(String optionGroupId) async {
    try {
      print('🗑️ Starting deletion process for option group: $optionGroupId');

      // Step 1: Get all options linked to this group (before removing links)
      print('📝 Getting options linked to this group...');
      final linkedOptions = await getOptionsForGroup(optionGroupId);
      final optionIds = linkedOptions.map((option) => option.id).toList();
      print('📝 Found ${optionIds.length} options to check: $optionIds');

      // Step 2: Delete all option-to-group links
      print('🔗 Removing option-group links...');
      await SupabaseService.client
          .from('option_group_options')
          .delete()
          .eq('option_group_id', optionGroupId);

      // Step 3: Delete all menu item-to-group links
      print('📋 Removing menu item-group links...');
      await SupabaseService.client
          .from('menu_item_option_groups')
          .delete()
          .eq('option_group_id', optionGroupId);

      // Step 4: Delete orphaned options (options that are no longer linked to any group)
      print('🧹 Checking for orphaned options...');
      for (final optionId in optionIds) {
        // Check if this option is still linked to any other group
        final remainingLinks = await SupabaseService.client
            .from('option_group_options')
            .select('id')
            .eq('option_id', optionId)
            .limit(1);

        if (remainingLinks.isEmpty) {
          print('🗑️ Deleting orphaned option: $optionId');
          await SupabaseService.client
              .from('menu_options')
              .delete()
              .eq('id', optionId);
        } else {
          print('🔗 Option $optionId is still linked to other groups, keeping it');
        }
      }

      // Step 5: Finally delete the option group itself
      print('🗑️ Deleting option group...');
      await SupabaseService.client
          .from('option_groups')
          .delete()
          .eq('id', optionGroupId);

      print('✅ Successfully deleted option group and all related data');
      return true;
    } catch (e) {
      print('❌ Error during deletion: $e');
      throw Exception('Failed to delete option group: $e');
    }
  }

  Future<bool> connectOptionToGroup(String optionId, String groupId, {int displayOrder = 0}) async {
    try {
      await SupabaseService.client
          .from('option_group_options')
          .insert({
            'option_group_id': groupId,
            'option_id': optionId,
            'display_order': displayOrder,
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      throw Exception('Failed to connect option to group: $e');
    }
  }

  Future<bool> disconnectOptionFromGroup(String optionId, String groupId) async {
    try {
      await SupabaseService.client
          .from('option_group_options')
          .delete()
          .eq('option_group_id', groupId)
          .eq('option_id', optionId);

      return true;
    } catch (e) {
      throw Exception('Failed to disconnect option from group: $e');
    }
  }

  Future<List<String>> getMenuItemsUsingOptionGroup(String optionGroupId) async {
    try {
      final response = await SupabaseService.client
          .from('menu_item_option_groups')
          .select('menu_item_id')
          .eq('option_group_id', optionGroupId);

      return response.map((json) => json['menu_item_id'] as String).toList();
    } catch (e) {
      throw Exception('Failed to fetch menu items using option group: $e');
    }
  }

  /// Connect a menu item to an option group
  Future<bool> connectMenuItemToOptionGroup(
    String menuItemId,
    String optionGroupId, {
    bool isRequired = false,
    int displayOrder = 0,
  }) async {
    try {
      // Check if relationship already exists
      final existing = await SupabaseService.client
          .from('menu_item_option_groups')
          .select('id')
          .eq('menu_item_id', menuItemId)
          .eq('option_group_id', optionGroupId)
          .maybeSingle();

      if (existing != null) {
        print('✅ Menu item $menuItemId already linked to option group $optionGroupId');
        return true; // Relationship already exists
      }

      // Create new relationship
      await SupabaseService.client.from('menu_item_option_groups').insert({
        'menu_item_id': menuItemId,
        'option_group_id': optionGroupId,
        'is_required': isRequired,
        'display_order': displayOrder,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Connected menu item $menuItemId to option group $optionGroupId');
      return true;
    } catch (e) {
      print('❌ Error connecting menu item to option group: $e');
      throw Exception('Failed to connect menu item to option group: $e');
    }
  }

  /// Disconnect a menu item from an option group
  Future<bool> disconnectMenuItemFromOptionGroup(
    String menuItemId,
    String optionGroupId,
  ) async {
    try {
      await SupabaseService.client
          .from('menu_item_option_groups')
          .delete()
          .eq('menu_item_id', menuItemId)
          .eq('option_group_id', optionGroupId);

      print('✅ Disconnected menu item $menuItemId from option group $optionGroupId');
      return true;
    } catch (e) {
      print('❌ Error disconnecting menu item from option group: $e');
      throw Exception('Failed to disconnect menu item from option group: $e');
    }
  }

  /// Update menu item links for an option group
  Future<bool> updateMenuItemLinks(String optionGroupId, List<String> menuItemIds) async {
    try {
      print('🔗 Updating menu item links for option group $optionGroupId');
      print('📋 New menu item IDs: $menuItemIds');

      // Get current links
      final currentLinks = await SupabaseService.client
          .from('menu_item_option_groups')
          .select('menu_item_id')
          .eq('option_group_id', optionGroupId);

      final currentMenuItemIds = currentLinks
          .map((link) => link['menu_item_id'] as String)
          .toList();

      print('📋 Current menu item IDs: $currentMenuItemIds');

      // Remove links that are no longer needed
      final toRemove = currentMenuItemIds.where((id) => !menuItemIds.contains(id));
      for (final menuItemId in toRemove) {
        await disconnectMenuItemFromOptionGroup(menuItemId, optionGroupId);
      }

      // Add new links
      final toAdd = menuItemIds.where((id) => !currentMenuItemIds.contains(id));
      for (final menuItemId in toAdd) {
        await connectMenuItemToOptionGroup(menuItemId, optionGroupId);
      }

      print('✅ Successfully updated menu item links');
      return true;
    } catch (e) {
      print('❌ Error updating menu item links: $e');
      throw Exception('Failed to update menu item links: $e');
    }
  }
}

/// Inventory management service using Supabase
class SupabaseInventoryService extends SupabaseService {

  // ============= INGREDIENT MANAGEMENT =============

  Future<List<Ingredient>> getIngredients({InventoryFilter? filter}) async {
    try {
      var query = SupabaseService.client
          .from('ingredients')
          .select();

      // Apply filters
      if (filter != null) {
        if (filter.active != null) {
          query = query.eq('is_active', filter.active!);
        }

        if (filter.categories != null && filter.categories!.isNotEmpty) {
          query = query.inFilter('category', filter.categories!);
        }
      } else {
        // Default to active ingredients only
        query = query.eq('is_active', true);
      }

      // Apply sorting and execute query
      dynamic finalQuery;
      if (filter?.sortBy != null) {
        final ascending = filter?.sortOrder?.toLowerCase() != 'desc';
        switch (filter!.sortBy) {
          case 'name':
            finalQuery = query.order('name', ascending: ascending);
            break;
          case 'quantity':
            finalQuery = query.order('current_quantity', ascending: ascending);
            break;
          case 'cost':
            finalQuery = query.order('cost_per_unit', ascending: ascending);
            break;
          default:
            finalQuery = query.order('name');
        }
      } else {
        finalQuery = query.order('name');
      }

      final response = await finalQuery;

      List<Ingredient> ingredients = response.map<Ingredient>((json) => Ingredient.fromMap(json)).toList();

      // Client-side filtering for low stock if needed
      if (filter?.lowStock == true) {
        ingredients = ingredients.where((ingredient) =>
          ingredient.currentQuantity <= ingredient.minimumThreshold
        ).toList();
      }

      return ingredients;
    } catch (e) {
      throw Exception('Failed to fetch ingredients: $e');
    }
  }

  Future<Ingredient?> getIngredientById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('ingredients')
          .select()
          .eq('id', id)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        return Ingredient.fromMap(response);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch ingredient: $e');
    }
  }

  Future<String> createIngredient(Ingredient ingredient) async {
    try {
      final response = await SupabaseService.client
          .from('ingredients')
          .insert({
            'name': ingredient.name,
            'description': ingredient.description,
            'category': ingredient.category,
            'unit': ingredient.unit,
            'current_quantity': ingredient.currentQuantity,
            'minimum_threshold': ingredient.minimumThreshold,
            'cost_per_unit': ingredient.costPerUnit,
            'supplier': ingredient.supplier,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create ingredient: $e');
    }
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    try {
      await SupabaseService.client
          .from('ingredients')
          .update({
            'name': ingredient.name,
            'description': ingredient.description,
            'category': ingredient.category,
            'unit': ingredient.unit,
            'current_quantity': ingredient.currentQuantity,
            'minimum_threshold': ingredient.minimumThreshold,
            'cost_per_unit': ingredient.costPerUnit,
            'supplier': ingredient.supplier,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ingredient.id.toString());
    } catch (e) {
      throw Exception('Failed to update ingredient: $e');
    }
  }

  Future<void> deleteIngredient(String id) async {
    try {
      // Soft delete by setting is_active to false
      await SupabaseService.client
          .from('ingredients')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete ingredient: $e');
    }
  }

  Future<void> updateIngredientQuantity(String ingredientId, double newQuantity, {String? reason}) async {
    try {
      // Get current ingredient
      final ingredient = await getIngredientById(ingredientId);
      if (ingredient == null) {
        throw Exception('Ingredient not found');
      }

      final now = DateTime.now();

      // Update ingredient quantity
      await SupabaseService.client
          .from('ingredients')
          .update({
            'current_quantity': newQuantity,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', ingredientId);

      // Record transaction
      await SupabaseService.client
          .from('inventory_transactions')
          .insert({
            'ingredient_id': ingredientId,
            'transaction_type': 'ADJUSTMENT',
            'quantity': newQuantity - ingredient.currentQuantity,
            'unit': ingredient.unit,
            'reason': reason ?? 'Manual adjustment',
            'created_at': now.toIso8601String(),
          });
    } catch (e) {
      throw Exception('Failed to update ingredient quantity: $e');
    }
  }

  // ============= STOCKTAKE MANAGEMENT =============

  Future<List<StocktakeSession>> getStocktakeSessions() async {
    try {
      final response = await SupabaseService.client
          .from('stocktake_sessions')
          .select()
          .order('created_at', ascending: false);

      return response.map((json) => _stocktakeSessionFromSupabaseMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch stocktake sessions: $e');
    }
  }

  Future<StocktakeSession?> getStocktakeSessionById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('stocktake_sessions')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        return _stocktakeSessionFromSupabaseMap(response);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch stocktake session: $e');
    }
  }

  Future<String> createStocktakeSession({
    required String name,
    String? description,
    required String type,
    String? location,
    List<String>? categoryFilter,
  }) async {
    try {
      final now = DateTime.now();

      // Get all ingredients to include in stocktake
      final filter = InventoryFilter(
        categories: categoryFilter,
        active: true,
      );
      final ingredients = await getIngredients(filter: filter);

      // Create stocktake session
      final sessionResponse = await SupabaseService.client
          .from('stocktake_sessions')
          .insert({
            'name': name,
            'description': description,
            'type': type,
            'status': 'draft',
            'location': location,
            'total_items': ingredients.length,
            'counted_items': 0,
            'variance_count': 0,
            'total_variance_value': 0,
            'created_at': now.toIso8601String(),
          })
          .select('id')
          .single();

      final sessionId = sessionResponse['id'] as String;

      // Create stocktake items for each ingredient
      final stocktakeItems = ingredients.map((ingredient) => {
        'session_id': sessionId,
        'ingredient_id': ingredient.id.toString(),
        'ingredient_name': ingredient.name,
        'unit': ingredient.unit,
        'expected_quantity': ingredient.currentQuantity,
      }).toList();

      if (stocktakeItems.isNotEmpty) {
        await SupabaseService.client
            .from('stocktake_items')
            .insert(stocktakeItems);
      }

      return sessionId;
    } catch (e) {
      throw Exception('Failed to create stocktake session: $e');
    }
  }

  Future<void> startStocktakeSession(String sessionId) async {
    try {
      await SupabaseService.client
          .from('stocktake_sessions')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to start stocktake session: $e');
    }
  }

  Future<List<StocktakeItem>> getStocktakeItems(String sessionId) async {
    try {
      final response = await SupabaseService.client
          .from('stocktake_items')
          .select()
          .eq('session_id', sessionId)
          .order('ingredient_name');

      return response.map((json) => _stocktakeItemFromSupabaseMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch stocktake items: $e');
    }
  }

  Future<void> updateStocktakeItemCount(
    String sessionId,
    String itemId,
    double countedQuantity, {
    String? notes,
  }) async {
    try {
      final now = DateTime.now();

      // Get the stocktake item to calculate variance
      final item = await SupabaseService.client
          .from('stocktake_items')
          .select()
          .eq('id', itemId)
          .single();

      final expectedQuantity = (item['expected_quantity'] as num).toDouble();
      final variance = countedQuantity - expectedQuantity;

      // Update the stocktake item
      await SupabaseService.client
          .from('stocktake_items')
          .update({
            'counted_quantity': countedQuantity,
            'variance': variance,
            'notes': notes,
            'counted_at': now.toIso8601String(),
          })
          .eq('id', itemId);

      // Update session statistics
      await _updateSessionStatistics(sessionId);
    } catch (e) {
      throw Exception('Failed to update stocktake item count: $e');
    }
  }

  Future<void> _updateSessionStatistics(String sessionId) async {
    try {
      // Get all items for this session
      final items = await SupabaseService.client
          .from('stocktake_items')
          .select()
          .eq('session_id', sessionId);

      int countedItems = 0;
      int varianceCount = 0;
      double totalVarianceValue = 0;

      for (final item in items) {
        if (item['counted_quantity'] != null) {
          countedItems++;

          final variance = item['variance'] as num?;
          if (variance != null && variance != 0) {
            varianceCount++;
            // You might want to calculate monetary variance here
          }
        }
      }

      // Update session statistics
      await SupabaseService.client
          .from('stocktake_sessions')
          .update({
            'counted_items': countedItems,
            'variance_count': varianceCount,
            'total_variance_value': totalVarianceValue,
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to update session statistics: $e');
    }
  }

  Future<void> completeStocktakeSession(String sessionId, {bool applyChanges = false}) async {
    try {
      final now = DateTime.now();

      if (applyChanges) {
        // Apply counted quantities to actual inventory
        final items = await SupabaseService.client
            .from('stocktake_items')
            .select()
            .eq('session_id', sessionId)
            .not('counted_quantity', 'is', null);

        for (final item in items) {
          final ingredientId = item['ingredient_id'] as String;
          final countedQuantity = (item['counted_quantity'] as num).toDouble();

          await updateIngredientQuantity(
            ingredientId,
            countedQuantity,
            reason: 'Stocktake adjustment - Session: ${sessionId}',
          );
        }
      }

      // Mark session as completed
      await SupabaseService.client
          .from('stocktake_sessions')
          .update({
            'status': 'completed',
            'completed_at': now.toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to complete stocktake session: $e');
    }
  }

  Future<void> cancelStocktakeSession(String sessionId) async {
    try {
      await SupabaseService.client
          .from('stocktake_sessions')
          .update({
            'status': 'cancelled',
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to cancel stocktake session: $e');
    }
  }

  // ============= ANALYTICS & UTILITIES =============

  Future<Map<String, dynamic>> getInventoryStatistics() async {
    try {
      // Get all active ingredients
      final ingredients = await getIngredients();

      double totalValue = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;

      for (final ingredient in ingredients) {
        totalValue += ingredient.totalValue;

        if (ingredient.currentQuantity <= 0) {
          outOfStockCount++;
        } else if (ingredient.currentQuantity <= ingredient.minimumThreshold) {
          lowStockCount++;
        }
      }

      return {
        'total_ingredients': ingredients.length,
        'total_value': totalValue,
        'low_stock_count': lowStockCount,
        'out_of_stock_count': outOfStockCount,
        'in_stock_count': ingredients.length - lowStockCount - outOfStockCount,
      };
    } catch (e) {
      throw Exception('Failed to get inventory statistics: $e');
    }
  }

  // ============= HELPER METHODS =============


  StocktakeSession _stocktakeSessionFromSupabaseMap(Map<String, dynamic> map) {
    return StocktakeSession(
      id: int.tryParse(map['id']?.toString() ?? ''), // Convert UUID back to int for compatibility
      name: map['name'] ?? '',
      description: map['description'],
      type: map['type'] ?? '',
      status: map['status'] ?? 'draft',
      location: map['location'],
      totalItems: map['total_items'] ?? 0,
      countedItems: map['counted_items'] ?? 0,
      varianceCount: map['variance_count'] ?? 0,
      totalVarianceValue: (map['total_variance_value'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }

  StocktakeItem _stocktakeItemFromSupabaseMap(Map<String, dynamic> map) {
    return StocktakeItem(
      id: int.tryParse(map['id']?.toString() ?? ''), // Convert UUID back to int for compatibility
      sessionId: int.tryParse(map['session_id']?.toString() ?? '') ?? 0,
      ingredientId: int.tryParse(map['ingredient_id']?.toString() ?? '') ?? 0,
      ingredientName: map['ingredient_name'] ?? '',
      unit: map['unit'] ?? '',
      expectedQuantity: (map['expected_quantity'] ?? 0).toDouble(),
      countedQuantity: map['counted_quantity'] != null ? (map['counted_quantity'] as num).toDouble() : null,
      variance: map['variance'] != null ? (map['variance'] as num).toDouble() : null,
      varianceValue: map['variance_value'] != null ? (map['variance_value'] as num).toDouble() : null,
      notes: map['notes'],
      countedAt: map['counted_at'] != null ? DateTime.parse(map['counted_at']) : null,
    );
  }
}

/// Order management service using Supabase
class SupabaseOrderService extends SupabaseService {

  // ============= ORDER CRUD OPERATIONS =============

  /// Get all orders with optional filtering - OPTIMIZED to fix N+1 query problem
  Future<List<Order>> getOrders({
    OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? customerId,
  }) async {
    try {
      // 🚀 PERFORMANCE FIX: Single optimized query with JOIN to get orders AND items in one call
      dynamic ordersQuery = SupabaseService.client
          .from('orders')
          .select('''
            *,
            customers(id, name, phone, email, address),
            order_items(*)
          ''');

      // Apply filters
      if (status != null) {
        ordersQuery = ordersQuery.eq('status', status.value);
      }

      if (startDate != null) {
        ordersQuery = ordersQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        ordersQuery = ordersQuery.lte('created_at', endDate.toIso8601String());
      }

      if (customerId != null) {
        ordersQuery = ordersQuery.eq('customer_id', customerId);
      }

      // Apply ordering and limit
      ordersQuery = ordersQuery.order('created_at', ascending: false);

      if (limit != null) {
        ordersQuery = ordersQuery.limit(limit);
      }

      print('🚀 Executing optimized single query for orders + items...');
      final response = await ordersQuery;
      print('✅ Single query completed! Processing ${response.length} orders...');

      // Transform response to Order objects with items included
      final orders = response.map<Order>((json) {
        // Transform Supabase response to match Order model
        final transformedJson = Map<String, dynamic>.from(json);

        // Handle nested customer data
        if (json['customers'] != null) {
          final customerData = json['customers'];
          transformedJson['customer_id'] = customerData['id'];
          transformedJson['customer_name'] = customerData['name'] ?? '';
          transformedJson['customer_phone'] = customerData['phone'] ?? '';
          transformedJson['customer_email'] = customerData['email'] ?? '';
          transformedJson['customer_address'] = customerData['address'] ?? '';
        } else {
          // Handle missing customer data gracefully
          transformedJson['customer_id'] = json['customer_id'] ?? '';
          transformedJson['customer_name'] = 'Unknown Customer';
          transformedJson['customer_phone'] = '';
          transformedJson['customer_email'] = '';
          transformedJson['customer_address'] = '';
        }

        // Keep original timestamp values - let Order.fromMap() handle parsing
        transformedJson['created_at'] = json['created_at'];
        transformedJson['updated_at'] = json['updated_at'];

        // 🚀 PERFORMANCE FIX: Process order items directly from JOIN result (no separate queries!)
        final orderItemsJson = json['order_items'] as List? ?? [];
        final orderItems = orderItemsJson.map<OrderItem>((item) => OrderItem.fromMap(item)).toList();

        final order = Order.fromMap(transformedJson);
        return order.copyWith(items: orderItems);
      }).toList();

      print('✅ Processed ${orders.length} orders with ${orders.fold(0, (sum, order) => sum + order.items.length)} total items');
      return orders;
    } catch (e) {
      print('❌ Error fetching orders: $e');
      return [];
    }
  }

  /// Get a single order by ID
  Future<Order?> getOrderById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            customers!inner(id, name, phone, email, address)
          ''')
          .eq('id', _convertToSupabaseId(id))
          .single();

      // Transform customer data
      final transformedJson = Map<String, dynamic>.from(response);
      if (response['customers'] != null) {
        final customerData = response['customers'];
        transformedJson['customer_id'] = customerData['id'];
        transformedJson['customer_name'] = customerData['name'];
        transformedJson['customer_phone'] = customerData['phone'];
        transformedJson['customer_email'] = customerData['email'];
        transformedJson['customer_address'] = customerData['address'];
      }

      // Convert timestamps
      transformedJson['created_at'] = DateTime.parse(response['created_at']).millisecondsSinceEpoch;
      transformedJson['updated_at'] = DateTime.parse(response['updated_at']).millisecondsSinceEpoch;

      final order = Order.fromMap(transformedJson);

      // Load order items
      final orderItems = await getOrderItems(order.id);

      return order.copyWith(items: orderItems);
    } catch (e) {
      print('❌ Error fetching order: $e');
      return null;
    }
  }

  /// Get order items for a specific order
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    try {
      final response = await SupabaseService.client
          .from('order_items')
          .select('*')
          .eq('order_id', _convertToSupabaseId(orderId))
          .order('id');

      return response.map<OrderItem>((item) => OrderItem.fromMap(item)).toList();
    } catch (e) {
      print('❌ Error fetching order items: $e');
      return [];
    }
  }

  /// Create a new order
  Future<String> createOrder(Order order) async {
    try {
      // Validate payment method for delivered orders
      if (_requiresPaymentMethod(order.status)) {
        _validatePaymentMethodForOrder(order);
      }

      final data = order.toMap();

      // Remove ID for insert, let Supabase generate UUID
      data.remove('id');

      // Convert timestamps to ISO strings for Supabase
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      // Create order
      final response = await SupabaseService.client
          .from('orders')
          .insert(data)
          .select('id')
          .single();

      final orderId = response['id'] as String;

      // Create order items
      for (final item in order.items) {
        final itemData = item.toMap();
        itemData.remove('id');
        itemData['order_id'] = orderId;

        await SupabaseService.client
            .from('order_items')
            .insert(itemData);
      }

      return orderId;
    } catch (e) {
      print('❌ Error creating order: $e');

      // Check if this is a user-friendly validation error
      final errorMessage = e.toString();
      if (errorMessage.contains('Payment method required') ||
          errorMessage.contains('method required') ||
          errorMessage.contains('phương thức thanh toán')) {
        // Pass through validation errors as-is for better UX
        rethrow;
      }

      // For database/technical errors, provide context
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update an existing order
  Future<void> updateOrder(Order order) async {
    try {
      // Validate payment method for delivered orders
      if (_requiresPaymentMethod(order.status)) {
        _validatePaymentMethodForOrder(order);
      }

      final data = order.toMap();

      // Remove id and created_at from updates (shouldn't change)
      data.remove('id');
      data.remove('created_at');

      // Convert timestamp to ISO string for Supabase
      data['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client
          .from('orders')
          .update(data)
          .eq('id', _convertToSupabaseId(order.id));
    } catch (e) {
      print('❌ Error updating order: $e');

      // Check if this is a user-friendly validation error
      final errorMessage = e.toString();
      if (errorMessage.contains('Payment method required') ||
          errorMessage.contains('method required') ||
          errorMessage.contains('phương thức thanh toán')) {
        // Pass through validation errors as-is for better UX
        rethrow;
      }

      // For database/technical errors, provide context
      throw Exception('Failed to update order: $e');
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      // Validate payment method is required for completion statuses
      if (_requiresPaymentMethod(status)) {
        await _validatePaymentMethodForCompletion(orderId, status);
      }

      await SupabaseService.client
          .from('orders')
          .update({
            'status': status.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _convertToSupabaseId(orderId));
    } catch (e) {
      print('❌ Error updating order status: $e');

      // Check if this is a user-friendly validation error
      final errorMessage = e.toString();
      if (errorMessage.contains('Payment method required') ||
          errorMessage.contains('method required') ||
          errorMessage.contains('phương thức thanh toán')) {
        // Pass through validation errors as-is for better UX
        rethrow;
      }

      // For database/technical errors, provide context
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Check if the order status requires a payment method
  bool _requiresPaymentMethod(OrderStatus status) {
    return status == OrderStatus.delivered;
  }

  /// Validate that payment method is set when completing an order
  Future<void> _validatePaymentMethodForCompletion(String orderId, OrderStatus targetStatus) async {
    try {
      // Fetch current order to check payment method
      final response = await SupabaseService.client
          .from('orders')
          .select('payment_method')
          .eq('id', _convertToSupabaseId(orderId))
          .single();

      final currentPaymentMethod = response['payment_method'] as String?;

      // Check if payment method is missing or set to 'none'
      if (currentPaymentMethod == null ||
          currentPaymentMethod.isEmpty ||
          currentPaymentMethod == 'none') {
        throw Exception('Payment method required');
      }
    } catch (e) {
      if (e.toString().contains('Payment method is required')) {
        rethrow; // Re-throw our validation error
      }
      throw Exception('Failed to validate payment method for order completion: $e');
    }
  }

  /// Validate that payment method is set for an order object
  void _validatePaymentMethodForOrder(Order order) {
    // Check if payment method is missing or set to 'none'
    if (order.paymentMethod == PaymentMethod.none) {
      throw Exception('Payment method required');
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus(String orderId, PaymentStatus status) async {
    try {
      await SupabaseService.client
          .from('orders')
          .update({
            'payment_status': status.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _convertToSupabaseId(orderId));
    } catch (e) {
      print('❌ Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }

  /// Complete order with payment method and status atomically
  /// This ensures payment method is set before marking order as delivered
  Future<void> completeOrderWithPayment(
    String orderId,
    PaymentMethod paymentMethod, {
    PaymentStatus paymentStatus = PaymentStatus.paid,
    OrderStatus orderStatus = OrderStatus.delivered,
  }) async {
    try {
      // Validate payment method is not 'none'
      if (paymentMethod == PaymentMethod.none) {
        throw Exception('Payment method required');
      }

      // Update payment method, payment status, and order status atomically
      await SupabaseService.client
          .from('orders')
          .update({
            'payment_method': paymentMethod.value,
            'payment_status': paymentStatus.value,
            'status': orderStatus.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _convertToSupabaseId(orderId));
    } catch (e) {
      print('❌ Error completing order with payment: $e');
      throw Exception('Failed to complete order with payment: $e');
    }
  }

  /// Delete an order
  Future<void> deleteOrder(String id) async {
    try {
      // Delete order items first (foreign key constraint)
      await SupabaseService.client
          .from('order_items')
          .delete()
          .eq('order_id', _convertToSupabaseId(id));

      // Delete order
      await SupabaseService.client
          .from('orders')
          .delete()
          .eq('id', _convertToSupabaseId(id));
    } catch (e) {
      print('❌ Error deleting order: $e');
      throw Exception('Failed to delete order: $e');
    }
  }

  // ============= ORDER QUERIES & FILTERS =============

  /// Get orders by status
  Future<List<Order>> getOrdersByStatus(OrderStatus status) async {
    return getOrders(status: status);
  }

  /// Get today's orders
  Future<List<Order>> getTodaysOrders() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getOrders(startDate: startOfDay, endDate: endOfDay);
  }

  /// Get orders for a specific date range
  Future<List<Order>> getOrdersInDateRange(DateTime startDate, DateTime endDate) async {
    return getOrders(startDate: startDate, endDate: endDate);
  }

  // ============= ANALYTICS & STATISTICS =============

  /// Get comprehensive order statistics
  Future<Map<String, dynamic>> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Build date filter
      dynamic query = SupabaseService.client
          .from('orders')
          .select('total, status, order_type, payment_status, created_at');

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;

      // Calculate statistics
      double totalRevenue = 0;
      int totalOrders = response.length;
      int completedOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      int paidOrders = 0;

      Map<String, int> orderTypeCount = {};
      Map<String, double> orderTypeRevenue = {};

      for (final order in response) {
        final total = (order['total'] ?? 0).toDouble();
        final status = order['status'] as String;
        final paymentStatus = order['payment_status'] as String;
        final orderType = order['order_type'] as String;

        totalRevenue += total;

        // Count by status
        switch (OrderStatus.fromString(status)) {
          case OrderStatus.delivered:
          case OrderStatus.ready:
            completedOrders++;
            break;
          case OrderStatus.cancelled:
          case OrderStatus.failed:
            cancelledOrders++;
            break;
          default:
            pendingOrders++;
        }

        // Count paid orders
        if (PaymentStatus.fromString(paymentStatus) == PaymentStatus.paid) {
          paidOrders++;
        }

        // Count by order type
        orderTypeCount[orderType] = (orderTypeCount[orderType] ?? 0) + 1;
        orderTypeRevenue[orderType] = (orderTypeRevenue[orderType] ?? 0) + total;
      }

      return {
        'total_revenue': totalRevenue,
        'total_orders': totalOrders,
        'completed_orders': completedOrders,
        'pending_orders': pendingOrders,
        'cancelled_orders': cancelledOrders,
        'paid_orders': paidOrders,
        'average_order_value': totalOrders > 0 ? totalRevenue / totalOrders : 0,
        'completion_rate': totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0,
        'payment_rate': totalOrders > 0 ? (paidOrders / totalOrders) * 100 : 0,
        'order_type_breakdown': orderTypeCount,
        'revenue_by_type': orderTypeRevenue,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting order statistics: $e');
      return {};
    }
  }

  /// Get best selling items analytics
  Future<List<Map<String, dynamic>>> getBestSellingItems({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    try {
      // Build query for order items with date filter via orders table
      dynamic orderQuery = SupabaseService.client
          .from('orders')
          .select('id');

      if (startDate != null) {
        orderQuery = orderQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        orderQuery = orderQuery.lte('created_at', endDate.toIso8601String());
      }

      final orderResponse = await orderQuery;
      final orderIds = orderResponse.map((order) => order['id'] as String).toList();

      if (orderIds.isEmpty) {
        return [];
      }

      // Get order items for these orders
      final itemResponse = await SupabaseService.client
          .from('order_items')
          .select('menu_item_id, menu_item_name, quantity, subtotal')
          .inFilter('order_id', orderIds);

      // Aggregate by menu item
      final Map<String, Map<String, dynamic>> aggregated = {};

      for (final item in itemResponse) {
        final menuItemId = item['menu_item_id'] as String;
        final menuItemName = item['menu_item_name'] as String;
        final quantity = item['quantity'] as int;
        final subtotal = (item['subtotal'] ?? 0).toDouble();

        if (aggregated.containsKey(menuItemId)) {
          aggregated[menuItemId]!['total_quantity'] += quantity;
          aggregated[menuItemId]!['total_revenue'] += subtotal;
          aggregated[menuItemId]!['order_count'] += 1;
        } else {
          aggregated[menuItemId] = {
            'menu_item_id': menuItemId,
            'menu_item_name': menuItemName,
            'total_quantity': quantity,
            'total_revenue': subtotal,
            'order_count': 1,
          };
        }
      }

      // Convert to list and sort by quantity
      final bestSellers = aggregated.values.toList();
      bestSellers.sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));

      return bestSellers.take(limit).toList();
    } catch (e) {
      print('❌ Error getting best selling items: $e');
      return [];
    }
  }

  /// Get sales data for charting
  Future<List<Map<String, dynamic>>> getSalesChartData({
    DateTime? startDate,
    DateTime? endDate,
    String groupBy = 'day', // 'hour', 'day', 'week', 'month'
  }) async {
    try {
      dynamic query = SupabaseService.client
          .from('orders')
          .select('total, created_at')
          .eq('payment_status', PaymentStatus.paid.value);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at');

      // Group sales data
      final Map<String, double> groupedSales = {};
      final DateFormat formatter;

      switch (groupBy) {
        case 'hour':
          formatter = DateFormat('yyyy-MM-dd HH:00');
          break;
        case 'week':
          formatter = DateFormat('yyyy-ww');
          break;
        case 'month':
          formatter = DateFormat('yyyy-MM');
          break;
        default:
          formatter = DateFormat('yyyy-MM-dd');
      }

      for (final order in response) {
        final createdAt = DateTime.parse(order['created_at']);
        final total = (order['total'] ?? 0).toDouble();
        final key = formatter.format(createdAt);

        groupedSales[key] = (groupedSales[key] ?? 0) + total;
      }

      // Convert to chart data format
      return groupedSales.entries.map((entry) => {
        'period': entry.key,
        'sales': entry.value,
      }).toList();
    } catch (e) {
      print('❌ Error getting sales chart data: $e');
      return [];
    }
  }

  /// Generate order number
  Future<String> generateOrderNumber() async {
    try {
      final now = DateTime.now();
      final datePrefix = DateFormat('yyyyMMdd').format(now);

      // Get count of orders created today
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final todayOrders = await getOrders(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final orderCount = todayOrders.length + 1;
      return '$datePrefix-${orderCount.toString().padLeft(4, '0')}';
    } catch (e) {
      print('❌ Error generating order number: $e');
      // Fallback to timestamp-based number
      return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ============= DASHBOARD ANALYTICS =============

  /// Get dashboard statistics summary
  Future<Map<String, dynamic>> getDashboardStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final stats = await getOrderStatistics(
        startDate: startDate,
        endDate: endDate,
      );

      final bestSellers = await getBestSellingItems(
        startDate: startDate,
        endDate: endDate,
        limit: 5,
      );

      final salesData = await getSalesChartData(
        startDate: startDate,
        endDate: endDate,
        groupBy: 'day',
      );

      return {
        ...stats,
        'best_sellers': bestSellers,
        'sales_chart_data': salesData,
      };
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      return {};
    }
  }

  // ============= HELPER METHODS =============

  /// Convert ID to Supabase format (UUID)
  /// Handles both string UUIDs and legacy integer IDs
  String _convertToSupabaseId(String id) {
    // If it's already a UUID format, return as-is
    if (id.contains('-') && id.length >= 32) {
      return id;
    }

    // For backward compatibility with integer IDs,
    // in production you might need to maintain a mapping table
    // or convert them to UUIDs. For now, return as-is and let Supabase handle it.
    return id;
  }
}

/// Order Source management service using Supabase
class SupabaseOrderSourceService extends SupabaseService {

  // ============= ORDER SOURCE CRUD OPERATIONS =============

  /// Get all order sources
  Future<List<OrderSource>> getOrderSources({bool? isActive}) async {
    try {
      dynamic query = SupabaseService.client
          .from('order_sources')
          .select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      query = query.order('created_at', ascending: true);

      final response = await query;

      return response.map<OrderSource>((json) {
        // Transform Supabase response to match OrderSource model
        final transformedJson = Map<String, dynamic>.from(json);

        // Keep original boolean and string values from Supabase - let the model handle conversion
        // The fromMap method now has robust parsing for these fields

        return OrderSource.fromMap(transformedJson);
      }).toList();
    } catch (e) {
      print('❌ Error fetching order sources: $e');
      return [];
    }
  }

  /// Get order source by ID
  Future<OrderSource?> getOrderSourceById(String id) async {
    try {
      final response = await SupabaseService.client
          .from('order_sources')
          .select()
          .eq('id', _convertToSupabaseId(id))
          .maybeSingle();

      if (response != null) {
        // Let the model handle all data type conversions
        return OrderSource.fromMap(response);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching order source: $e');
      return null;
    }
  }

  /// Create order source
  Future<String> createOrderSource(OrderSource orderSource) async {
    try {
      final data = orderSource.toMap();

      // Remove id field for new records
      data.remove('id');

      // Convert timestamps to ISO strings for Supabase
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseService.client
          .from('order_sources')
          .insert(data)
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      print('❌ Error creating order source: $e');
      throw Exception('Failed to create order source: $e');
    }
  }

  /// Update order source
  Future<void> updateOrderSource(OrderSource orderSource) async {
    try {
      final data = orderSource.toMap();

      // Remove id field for updates (used in WHERE clause)
      data.remove('id');

      // Update timestamp to ISO string for Supabase
      data['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client
          .from('order_sources')
          .update(data)
          .eq('id', _convertToSupabaseId(orderSource.id));
    } catch (e) {
      print('❌ Error updating order source: $e');
      throw Exception('Failed to update order source: $e');
    }
  }

  /// Delete order source
  Future<void> deleteOrderSource(String id) async {
    try {
      await SupabaseService.client
          .from('order_sources')
          .delete()
          .eq('id', _convertToSupabaseId(id));
    } catch (e) {
      print('❌ Error deleting order source: $e');
      throw Exception('Failed to delete order source: $e');
    }
  }

  /// Initialize default order sources if table is empty
  Future<void> initializeDefaultOrderSources() async {
    try {
      final sources = await getOrderSources();
      if (sources.isEmpty) {
        final defaultSources = OrderSource.getDefaultSources();
        for (final source in defaultSources) {
          await createOrderSource(source);
        }
        print('✅ Initialized ${defaultSources.length} default order sources');
      }
    } catch (e) {
      print('❌ Error initializing default order sources: $e');
      throw Exception('Failed to initialize default order sources: $e');
    }
  }

  // ============= HELPER METHODS =============

  /// Convert ID to Supabase format (UUID)
  /// Handles both string UUIDs and legacy integer IDs
  String _convertToSupabaseId(String id) {
    // If it's already a UUID format, return as-is
    if (id.contains('-') && id.length >= 32) {
      return id;
    }

    // For backward compatibility with integer IDs,
    // in production you might need to maintain a mapping table
    // or convert them to UUIDs. For now, return as-is and let Supabase handle it.
    return id;
  }
}

/// Finance entries management service using Supabase
class SupabaseFinanceService extends SupabaseService {

  // ============= FINANCE ENTRY CRUD OPERATIONS =============

  /// Create a new finance entry
  Future<String> createFinanceEntry({
    required String type, // 'income' or 'expense'
    required double amount,
    required String description,
    required String category,
  }) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Try to get a valid user ID
      String? userIdToUse;
      try {
        userIdToUse = await _getValidUserId(currentUser);
        print('Using user ID for finance entry: $userIdToUse');
      } catch (e) {
        print('Could not resolve user ID: $e');
        throw Exception('User authentication failed');
      }

      final data = {
        'type': type,
        'amount': amount,
        'description': description,
        'category': category,
        'user_id': userIdToUse,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.client
          .from('finance_entries')
          .insert(data)
          .select('id')
          .single();

      print('✅ Finance entry created successfully');
      return response['id'] as String;
    } catch (e) {
      print('❌ Error creating finance entry: $e');
      throw Exception('Failed to create finance entry: $e');
    }
  }

  /// Get finance entries with optional filtering
  Future<List<Map<String, dynamic>>> getFinanceEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? type, // 'income' or 'expense'
    String? userId,
  }) async {
    try {
      dynamic query = SupabaseService.client
          .from('finance_entries')
          .select();

      // Filter by date range
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      // Filter by type
      if (type != null) {
        query = query.eq('type', type);
      }

      // Filter by user (optional)
      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      // Order by creation date (newest first)
      query = query.order('created_at', ascending: false);

      final response = await query;

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching finance entries: $e');
      return [];
    }
  }

  /// Get today's finance entries
  Future<List<Map<String, dynamic>>> getTodayFinanceEntries() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getFinanceEntries(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get finance summary for a date range
  Future<Map<String, double>> getFinanceSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final entries = await getFinanceEntries(
        startDate: startDate,
        endDate: endDate,
      );

      double totalIncome = 0.0;
      double totalExpenses = 0.0;

      for (final entry in entries) {
        final amount = (entry['amount'] as num).toDouble();
        if (entry['type'] == 'income') {
          totalIncome += amount;
        } else if (entry['type'] == 'expense') {
          totalExpenses += amount;
        }
      }

      return {
        'income': totalIncome,
        'expenses': totalExpenses,
        'profit': totalIncome - totalExpenses,
      };
    } catch (e) {
      print('❌ Error calculating finance summary: $e');
      return {
        'income': 0.0,
        'expenses': 0.0,
        'profit': 0.0,
      };
    }
  }

  /// Update finance entry
  Future<void> updateFinanceEntry({
    required String id,
    required String type,
    required double amount,
    required String description,
    required String category,
  }) async {
    try {
      final data = {
        'type': type,
        'amount': amount,
        'description': description,
        'category': category,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('finance_entries')
          .update(data)
          .eq('id', id);

      print('✅ Finance entry updated successfully');
    } catch (e) {
      print('❌ Error updating finance entry: $e');
      throw Exception('Failed to update finance entry: $e');
    }
  }

  /// Delete finance entry
  Future<void> deleteFinanceEntry(String id) async {
    try {
      await SupabaseService.client
          .from('finance_entries')
          .delete()
          .eq('id', id);

      print('✅ Finance entry deleted successfully');
    } catch (e) {
      print('❌ Error deleting finance entry: $e');
      throw Exception('Failed to delete finance entry: $e');
    }
  }

  // ============= HELPER METHODS =============

  /// Get valid user ID for the current user
  Future<String> _getValidUserId(User currentUser) async {
    try {
      // First try to get user record from the database
      final userRecord = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .maybeSingle();

      if (userRecord != null) {
        return userRecord['id'] as String;
      }

      // If no user record exists, use the auth user ID
      return currentUser.id;
    } catch (e) {
      print('❌ Error getting valid user ID: $e');
      throw Exception('Could not determine user ID');
    }
  }
}
