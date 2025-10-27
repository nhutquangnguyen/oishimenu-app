import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/inventory_models.dart';
import '../../../services/supabase_service.dart';

// Inventory Service Provider
final inventoryServiceProvider = Provider<SupabaseInventoryService>((ref) {
  return SupabaseInventoryService();
});

// Inventory Statistics Provider
final inventoryStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getInventoryStatistics();
});

// Ingredients List Provider with Filtering
final ingredientsProvider = FutureProvider.autoDispose.family<List<Ingredient>, InventoryFilter?>((ref, filter) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getIngredients(filter: filter);
});

// Single Ingredient Provider
final ingredientProvider = FutureProvider.family<Ingredient?, String>((ref, id) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getIngredientById(id);
});

// Stocktake Sessions Provider
final stocktakeSessionsProvider = FutureProvider<List<StocktakeSession>>((ref) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getStocktakeSessions();
});

// Single Stocktake Session Provider
final stocktakeSessionProvider = FutureProvider.family<StocktakeSession?, String>((ref, id) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getStocktakeSessionById(id);
});

// Stocktake Items Provider
final stocktakeItemsProvider = FutureProvider.family<List<StocktakeItem>, String>((ref, sessionId) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getStocktakeItems(sessionId);
});

// Search and Filter State Providers
final inventorySearchProvider = StateProvider<String>((ref) => '');

final inventoryCategoryFilterProvider = StateProvider<String>((ref) => 'all');

final inventoryLowStockFilterProvider = StateProvider<bool>((ref) => false);

final inventorySortProvider = StateProvider<String>((ref) => 'name');

// Combined Filter Provider
final currentInventoryFilterProvider = Provider<InventoryFilter?>((ref) {
  final category = ref.watch(inventoryCategoryFilterProvider);
  final lowStock = ref.watch(inventoryLowStockFilterProvider);
  final sort = ref.watch(inventorySortProvider);

  return InventoryFilter(
    categories: category == 'all' ? null : [category],
    lowStock: lowStock ? true : null,
    active: true,
    sortBy: sort,
    sortOrder: 'asc',
  );
});

// Inventory Category Labels (Vietnamese Restaurant)
final inventoryCategoriesProvider = Provider<Map<String, String>>((ref) {
  return {
    'all': 'Tất cả',
    'dairy': 'Sữa & Phô mai',
    'protein': 'Thịt & Hải sản',
    'vegetables': 'Rau củ',
    'fruits': 'Trái cây',
    'grains': 'Ngũ cốc & Bánh',
    'spices': 'Gia vị',
    'beverages': 'Đồ uống',
    'other': 'Khác'
  };
});

// Stocktake Status Labels (Vietnamese)
final stocktakeStatusLabelsProvider = Provider<Map<String, String>>((ref) {
  return {
    'draft': 'Nháp',
    'in_progress': 'Đang thực hiện',
    'completed': 'Hoàn thành',
    'cancelled': 'Đã hủy',
  };
});

// Inventory Actions - Async Notifiers for complex operations
class InventoryActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial state
  }

  Future<void> createIngredient(Ingredient ingredient) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.createIngredient(ingredient);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.updateIngredient(ingredient);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> deleteIngredient(String id) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.deleteIngredient(id);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> updateQuantity(String ingredientId, double newQuantity, {String? reason}) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.updateIngredientQuantity(ingredientId, newQuantity, reason: reason);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> createSampleData() async {
    state = const AsyncLoading();
    try {
      // TODO: Implement sample data creation for Supabase
      // For now, this method is disabled until sample data service is migrated
      throw UnimplementedError('Sample data creation not yet implemented for Supabase');
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final inventoryActionsProvider = AsyncNotifierProvider<InventoryActionsNotifier, void>(() {
  return InventoryActionsNotifier();
});

class StocktakeActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial state
  }

  Future<String> createStocktakeSession({
    required String name,
    String? description,
    required String type,
    String? location,
    List<String>? categoryFilter,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      final sessionId = await service.createStocktakeSession(
        name: name,
        description: description,
        type: type,
        location: location,
        categoryFilter: categoryFilter,
      );
      state = const AsyncData(null);
      return sessionId;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  Future<void> startSession(String sessionId) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.startStocktakeSession(sessionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> updateItemCount(String sessionId, String itemId, double countedQuantity, {String? notes}) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.updateStocktakeItemCount(sessionId, itemId, countedQuantity, notes: notes);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> completeSession(String sessionId, {bool applyChanges = false}) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.completeStocktakeSession(sessionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> cancelSession(String sessionId) async {
    state = const AsyncLoading();
    try {
      // TODO: Implement cancel stocktake session in SupabaseInventoryService
      throw UnimplementedError('Cancel stocktake session not yet implemented for Supabase');
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final stocktakeActionsProvider = AsyncNotifierProvider<StocktakeActionsNotifier, void>(() {
  return StocktakeActionsNotifier();
});