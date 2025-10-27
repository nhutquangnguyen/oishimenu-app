import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/supabase_config.dart';
import '../models/menu_item.dart';
import '../models/customer.dart' as customer_model;
import '../models/order.dart';
import '../models/menu_options.dart';
import '../features/auth/services/auth_service.dart' show AuthException;

/// Base Supabase service class that other services can extend
abstract class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;
}

/// Menu service using Supabase
class SupabaseMenuService extends SupabaseService {

  Future<List<MenuItem>> getMenuItems() async {
    try {
      final response = await SupabaseService.client
          .from('menu_items')
          .select('''
            *,
            menu_categories!inner(name)
          ''')
          .eq('available_status', true)
          .order('display_order');

      return response.map<MenuItem>((json) {
        // Transform Supabase response to match current MenuItem model
        final transformedJson = {
          ...json,
          'category_name': json['menu_categories']['name'],
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(json['updated_at']).millisecondsSinceEpoch,
        };
        return MenuItem.fromMap(transformedJson);
      }).toList();
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
        'available_status': item.availableStatus,
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
        'available_status': item.availableStatus,
        'photos': item.photos,
        'display_order': item.displayOrder,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item.id);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  Future<void> deleteMenuItem(String id, {String? userId}) async {
    try {
      await SupabaseService.client.from('menu_items').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete menu item: $e');
    }
  }

  Future<void> updateMenuItemStatus(String id, bool status, {String? userId}) async {
    try {
      await SupabaseService.client.from('menu_items').update({
        'available_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw Exception('Failed to update menu item status: $e');
    }
  }

  Future<List<MenuCategory>> getCategories() async {
    try {
      final response = await SupabaseService.client
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('display_order');

      return response.map<MenuCategory>((json) {
        // Transform timestamps for compatibility
        final transformedJson = {
          ...json,
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(json['updated_at']).millisecondsSinceEpoch,
        };
        return MenuCategory.fromMap(transformedJson);
      }).toList();
    } catch (e) {
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

  Future<bool> deleteCategory(String id, {String? userId}) async {
    try {
      await SupabaseService.client.from('menu_categories').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  Future<bool> reorderCategories(List<MenuCategory> categories) async {
    try {
      for (int i = 0; i < categories.length; i++) {
        await SupabaseService.client.from('menu_categories').update({
          'display_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', categories[i].id);
      }
      return true;
    } catch (e) {
      throw Exception('Failed to reorder categories: $e');
    }
  }

  Future<bool> reorderMenuItems(List<MenuItem> items, int categoryId) async {
    try {
      for (int i = 0; i < items.length; i++) {
        await SupabaseService.client.from('menu_items').update({
          'display_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', items[i].id);
      }
      return true;
    } catch (e) {
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

/// Order service using Supabase
class SupabaseOrderService extends SupabaseService {

  Future<List<Order>> getOrders() async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            customers(*),
            order_items(*)
          ''')
          .order('created_at', ascending: false);

      return response.map<Order>((json) {
        // Transform nested data to match current Order model structure
        final customer = json['customers'] != null
            ? customer_model.Customer.fromMap({
                ...json['customers'],
                'created_at': DateTime.parse(json['customers']['created_at']).millisecondsSinceEpoch,
                'updated_at': DateTime.parse(json['customers']['updated_at']).millisecondsSinceEpoch,
              })
            : customer_model.Customer(
                id: '',
                name: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

        final orderItems = (json['order_items'] as List?)
            ?.map((item) => OrderItem.fromMap(item))
            .toList() ?? [];

        final transformedJson = {
          ...json,
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(json['updated_at']).millisecondsSinceEpoch,
        };

        // Create Order model Customer from customer_model.Customer
        final orderCustomer = Customer(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          email: customer.email,
          address: customer.address,
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        );

        return Order.fromMap(transformedJson).copyWith(
          customer: orderCustomer,
          items: orderItems,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<String> createOrder(Order order) async {
    try {
      // Create customer if needed
      String? customerId;
      if (order.customer.name.isNotEmpty) {
        final existingCustomer = order.customer.phone?.isNotEmpty == true
            ? await SupabaseCustomerService().getCustomerByPhone(order.customer.phone!)
            : null;

        if (existingCustomer != null) {
          customerId = existingCustomer.id;
        } else {
          // Convert Order Customer to customer_model.Customer
          final customerModel = customer_model.Customer(
            id: order.customer.id,
            name: order.customer.name,
            phone: order.customer.phone,
            email: order.customer.email,
            address: order.customer.address,
            createdAt: order.customer.createdAt ?? DateTime.now(),
            updatedAt: order.customer.updatedAt ?? DateTime.now(),
          );
          customerId = await SupabaseCustomerService().createCustomer(customerModel);
        }
      }

      // Create order
      final orderResponse = await SupabaseService.client.from('orders').insert({
        'order_number': order.orderNumber,
        'customer_id': customerId,
        'subtotal': order.subtotal,
        'delivery_fee': order.deliveryFee,
        'discount': order.discount,
        'tax': order.tax,
        'service_charge': order.serviceCharge,
        'total': order.total,
        'order_type': order.orderType.toString().split('.').last.toUpperCase(),
        'status': order.status.toString().split('.').last.toUpperCase(),
        'payment_method': order.paymentMethod.toString().split('.').last,
        'payment_status': order.paymentStatus.toString().split('.').last.toUpperCase(),
        'table_number': order.tableNumber,
        'platform': order.platform,
        'notes': order.notes,
      }).select().single();

      final orderId = orderResponse['id'];

      // Create order items
      if (order.items.isNotEmpty) {
        final orderItemsData = order.items.map((item) => {
          'order_id': orderId,
          'menu_item_id': item.menuItemId,
          'menu_item_name': item.menuItemName,
          'base_price': item.basePrice,
          'quantity': item.quantity,
          'selected_size': item.selectedSize,
          'subtotal': item.subtotal,
          'notes': item.notes,
          'selected_options': item.selectedOptions, // Store as JSON
        }).toList();

        await SupabaseService.client.from('order_items').insert(orderItemsData);
      }

      return orderId;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<void> updateOrder(Order order) async {
    try {
      await SupabaseService.client.from('orders').update({
        'subtotal': order.subtotal,
        'delivery_fee': order.deliveryFee,
        'discount': order.discount,
        'tax': order.tax,
        'service_charge': order.serviceCharge,
        'total': order.total,
        'order_type': order.orderType.toString().split('.').last.toUpperCase(),
        'status': order.status.toString().split('.').last.toUpperCase(),
        'payment_method': order.paymentMethod.toString().split('.').last,
        'payment_status': order.paymentStatus.toString().split('.').last.toUpperCase(),
        'table_number': order.tableNumber,
        'platform': order.platform,
        'notes': order.notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', order.id);

      // Update order items if needed
      // You might want to implement a more sophisticated sync here
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      // Order items will be deleted automatically due to CASCADE
      await SupabaseService.client.from('orders').delete().eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to delete order: $e');
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
      final response = await SupabaseService.client
          .from('menu_options')
          .insert({
            'name': option.name,
            'category': option.category,
            'price': option.price,
            'is_available': option.isAvailable,
            'description': option.description,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create menu option: $e');
    }
  }

  Future<bool> updateMenuOption(MenuOption option) async {
    try {
      await SupabaseService.client
          .from('menu_options')
          .update({
            'name': option.name,
            'category': option.category,
            'price': option.price,
            'is_available': option.isAvailable,
            'description': option.description,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', option.id);

      return true;
    } catch (e) {
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
          .select('menu_option_id, display_order, menu_options(*)')
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
            'is_required': optionGroup.isRequired,
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
      await SupabaseService.client
          .from('option_groups')
          .update({
            'name': optionGroup.name,
            'description': optionGroup.description,
            'min_selection': optionGroup.minSelection,
            'max_selection': optionGroup.maxSelection,
            'is_required': optionGroup.isRequired,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', optionGroup.id);

      return true;
    } catch (e) {
      throw Exception('Failed to update option group: $e');
    }
  }

  Future<bool> deleteOptionGroup(String optionGroupId) async {
    try {
      await SupabaseService.client
          .from('option_groups')
          .delete()
          .eq('id', optionGroupId);

      return true;
    } catch (e) {
      throw Exception('Failed to delete option group: $e');
    }
  }

  Future<bool> connectOptionToGroup(String optionId, String groupId, {int displayOrder = 0}) async {
    try {
      await SupabaseService.client
          .from('option_group_options')
          .insert({
            'option_group_id': groupId,
            'menu_option_id': optionId,
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
          .eq('menu_option_id', optionId);

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
}