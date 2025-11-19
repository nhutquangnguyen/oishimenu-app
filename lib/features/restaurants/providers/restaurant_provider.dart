import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/restaurant.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Provider for managing current restaurant selection
final currentRestaurantProvider = StateProvider<Restaurant?>((ref) => null);

/// Provider for fetching all restaurants owned by current user
final userRestaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    print('👤 No user in userRestaurantsProvider');
    return [];
  }

  print('👤 Getting restaurants for user: ${user.email}');
  final restaurantService = SupabaseRestaurantService();
  var restaurants = await restaurantService.getRestaurantsByOwner(user.id);
  print('🏪 userRestaurantsProvider found ${restaurants.length} restaurants');
  for (final restaurant in restaurants) {
    print('🏪 Restaurant: ${restaurant.name} (ID: ${restaurant.id}, isDefault: ${restaurant.isDefault})');
  }

  // If no restaurants exist, create a default one
  if (restaurants.isEmpty) {
    print('🏪 No restaurants found, creating default restaurant');
    try {
      final createdRestaurant = await restaurantService.createRestaurant(
        name: 'My Restaurant',
        description: 'Default restaurant',
        phone: '',
        email: user.email ?? '',
        website: '',
        country: 'Vietnam',
        ownerUserId: user.id,
      );

      restaurants = [createdRestaurant];
      print('🏪 Created default restaurant: ${createdRestaurant.name} (ID: ${createdRestaurant.id})');
    } catch (e) {
      print('❌ Failed to create default restaurant: $e');
      return [];
    }
  }

  // If there are restaurants and none is selected, trigger auto-selection of default
  if (restaurants.isNotEmpty) {
    final currentSelection = ref.read(currentRestaurantProvider);
    if (currentSelection == null) {
      print('🏪 Triggering auto-selection from userRestaurantsProvider');

      // Prioritize the default restaurant from database
      final defaultRestaurant = restaurants.where((r) => r.isDefault).firstOrNull;
      final restaurantToSelect = defaultRestaurant ?? restaurants.first;

      print('🏪 Auto-selecting restaurant: ${restaurantToSelect.name} (isDefault: ${restaurantToSelect.isDefault})');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(restaurantSelectionProvider.notifier).selectRestaurant(restaurantToSelect);
      });
    }
  }

  return restaurants;
});

/// Provider for restaurant selection state
final restaurantSelectionProvider = StateNotifierProvider<RestaurantSelectionNotifier, AsyncValue<Restaurant?>>((ref) {
  return RestaurantSelectionNotifier(ref);
});

class RestaurantSelectionNotifier extends StateNotifier<AsyncValue<Restaurant?>> {
  final Ref _ref;
  final SupabaseRestaurantService _restaurantService = SupabaseRestaurantService();

  RestaurantSelectionNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Ensure we always get fresh data from database
    _ref.invalidate(userRestaurantsProvider);
    _loadCurrentRestaurant();
  }

  Future<void> _loadCurrentRestaurant() async {
    try {
      state = const AsyncValue.loading();

      // Get the current user's restaurants
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        print('🔐 No user found, cannot load restaurants');
        state = const AsyncValue.data(null);
        _ref.read(currentRestaurantProvider.notifier).state = null;
        return;
      }

      // Get all restaurants for this user
      final restaurants = await _restaurantService.getRestaurantsByOwner(user.id);
      print('🏪 Found ${restaurants.length} restaurants for user');

      Restaurant? selectedRestaurant;

      if (restaurants.isEmpty) {
        print('🏪 No restaurants found for user');
        selectedRestaurant = null;
      } else if (restaurants.length == 1) {
        // Auto-select the single restaurant
        selectedRestaurant = restaurants.first;
        print('🏪 Auto-selecting single restaurant: ${selectedRestaurant.name} (ID: ${selectedRestaurant.id})');
      } else {
        // Multiple restaurants - prioritize the default one from database
        final defaultRestaurant = restaurants.where((r) => r.isDefault).firstOrNull;
        if (defaultRestaurant != null) {
          selectedRestaurant = defaultRestaurant;
          print('🏪 Found default restaurant from database: ${selectedRestaurant.name} (ID: ${selectedRestaurant.id})');
        } else {
          // No default in database - check if one is already selected in memory
          final currentSelection = _ref.read(currentRestaurantProvider);
          if (currentSelection != null && restaurants.any((r) => r.id == currentSelection.id)) {
            selectedRestaurant = currentSelection;
            print('🏪 Keeping current selection: ${selectedRestaurant.name}');
          } else {
            // No restaurant selected - auto-select the first one
            selectedRestaurant = restaurants.first;
            print('🏪 Multiple restaurants found, auto-selecting first: ${selectedRestaurant.name} (ID: ${selectedRestaurant.id})');
          }
        }
      }

      state = AsyncValue.data(selectedRestaurant);
      _ref.read(currentRestaurantProvider.notifier).state = selectedRestaurant;
      print('🏪 Current restaurant provider set to: ${selectedRestaurant?.id ?? 'null'}');

    } catch (error, stackTrace) {
      print('❌ Error loading current restaurant: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Select a restaurant as the current active restaurant
  Future<void> selectRestaurant(Restaurant restaurant) async {
    try {
      state = AsyncValue.data(restaurant);
      _ref.read(currentRestaurantProvider.notifier).state = restaurant;

      // Invalidate all restaurant-specific data to trigger refresh
      _ref.invalidate(userRestaurantsProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Clear restaurant selection
  void clearSelection() {
    state = const AsyncValue.data(null);
    _ref.read(currentRestaurantProvider.notifier).state = null;
  }

  /// Refresh current restaurant data
  Future<void> refresh() async {
    await _loadCurrentRestaurant();
  }
}