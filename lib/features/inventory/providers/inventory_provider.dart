import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/inventory_models.dart';
import '../../../services/inventory_service.dart';

// Inventory Service Provider
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
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
final ingredientProvider = FutureProvider.family<Ingredient?, int>((ref, id) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getIngredientById(id);
});

// Stocktake Sessions Provider
final stocktakeSessionsProvider = StreamProvider<List<StocktakeSession>>((ref) {
  final service = ref.read(inventoryServiceProvider);

  // Initial load
  service.getStocktakeSessions();

  // Return the stream for real-time updates
  return service.stocktakeSessionsStream;
});

// Single Stocktake Session Provider
final stocktakeSessionProvider = FutureProvider.family<StocktakeSession?, int>((ref, id) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getStocktakeSessionById(id);
});

// Stocktake Items Provider
final stocktakeItemsProvider = FutureProvider.family<List<StocktakeItem>, int>((ref, sessionId) async {
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

  Future<void> deleteIngredient(int id) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.deleteIngredient(id);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> updateQuantity(int ingredientId, double newQuantity, {String? reason}) async {
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
      final service = ref.read(inventoryServiceProvider);
      await service.createSampleInventoryData();
      state = const AsyncData(null);
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

  Future<int> createStocktakeSession({
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

  Future<void> startSession(int sessionId) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.startStocktakeSession(sessionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> updateItemCount(int itemId, double countedQuantity, {String? notes}) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.updateStocktakeItemCount(itemId, countedQuantity, notes: notes);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> completeSession(int sessionId, {bool applyChanges = false}) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.completeStocktakeSession(sessionId, applyChanges: applyChanges);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> cancelSession(int sessionId) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(inventoryServiceProvider);
      await service.cancelStocktakeSession(sessionId);
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final stocktakeActionsProvider = AsyncNotifierProvider<StocktakeActionsNotifier, void>(() {
  return StocktakeActionsNotifier();
});