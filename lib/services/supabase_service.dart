import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/supabase_config.dart';
import '../models/menu_item.dart';
import '../models/customer.dart' as customer_model;
import '../models/order.dart';
import '../models/menu_options.dart';

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
      await SupabaseService.client.from('menu_items').insert({
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'category_id': item.categoryName, // You'll need to resolve category name to ID
        'cost_price': item.costPrice,
        'available_status': item.availableStatus,
        'photos': item.photos,
        'display_order': item.displayOrder,
        'user_id': SupabaseService.client.auth.currentUser?.id,
      });
    } catch (e) {
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
      return await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  Future<AuthResponse> signUp(String email, String password, {String? fullName}) async {
    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      // Create user record in our users table
      if (response.user != null) {
        await SupabaseService.client.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'role': 'staff',
        });
      }

      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Configure Google Sign-In for all platforms
      // OAuth 2.0 Client IDs from Google Cloud Console
      const webClientId = '198270461285-d3nrrj2bi1ktmvaj7oimavslibf6nmeo.apps.googleusercontent.com';
      const iosClientId = '198270461285-l9bnra8gj4lnubtlce5auurcgem8md7h.apps.googleusercontent.com';

      // Platform-specific configuration
      late GoogleSignIn googleSignIn;

      if (kIsWeb) {
        // Web configuration
        googleSignIn = GoogleSignIn(
          clientId: webClientId,
        );
      } else if (!kIsWeb && Platform.isIOS) {
        // iOS configuration
        googleSignIn = GoogleSignIn(
          clientId: iosClientId,
          serverClientId: webClientId,
        );
      } else if (!kIsWeb && Platform.isAndroid) {
        // Android configuration - uses google-services.json
        googleSignIn = GoogleSignIn(
          serverClientId: webClientId,
        );
      } else {
        throw Exception('Platform not supported for Google Sign-In');
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No access token found.');
      }
      if (idToken == null) {
        throw Exception('No ID token found.');
      }

      // Sign in to Supabase with Google tokens
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Create user record in our users table if it doesn't exist
      if (response.user != null) {
        try {
          await SupabaseService.client.from('users').upsert({
            'id': response.user!.id,
            'email': response.user!.email,
            'full_name': response.user!.userMetadata?['full_name'] ??
                         response.user!.userMetadata?['name'],
            'role': 'staff',
            'avatar_url': response.user!.userMetadata?['avatar_url'],
            'provider': 'google',
          });
        } catch (e) {
          // User record might already exist, which is fine
          print('User record creation/update failed: $e');
        }
      }

      return response;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
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