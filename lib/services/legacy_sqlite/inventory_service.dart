import 'dart:async';
import '../models/inventory_models.dart';
import '../services/database_helper.dart';

class InventoryService {
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Stream controllers for real-time updates
  final StreamController<List<Ingredient>> _ingredientsController =
      StreamController<List<Ingredient>>.broadcast();
  final StreamController<List<StocktakeSession>> _stocktakeSessionsController =
      StreamController<List<StocktakeSession>>.broadcast();

  Stream<List<Ingredient>> get ingredientsStream => _ingredientsController.stream;
  Stream<List<StocktakeSession>> get stocktakeSessionsStream => _stocktakeSessionsController.stream;

  // INGREDIENTS CRUD OPERATIONS

  Future<List<Ingredient>> getIngredients({InventoryFilter? filter}) async {
    try {
      final db = await _databaseHelper.database;

      String whereClause = 'WHERE is_active = 1';
      List<dynamic> whereArgs = [];

      if (filter != null) {
        if (filter.categories != null && filter.categories!.isNotEmpty) {
          whereClause += ' AND category IN (${filter.categories!.map((_) => '?').join(',')})';
          whereArgs.addAll(filter.categories!);
        }

        if (filter.lowStock == true) {
          whereClause += ' AND current_quantity <= minimum_threshold';
        }
      }

      String orderBy = 'name ASC';
      if (filter?.sortBy != null) {
        switch (filter!.sortBy) {
          case 'name':
            orderBy = 'name ${filter.sortOrder ?? 'ASC'}';
            break;
          case 'quantity':
            orderBy = 'current_quantity ${filter.sortOrder ?? 'ASC'}';
            break;
          case 'cost':
            orderBy = 'cost_per_unit ${filter.sortOrder ?? 'ASC'}';
            break;
        }
      }

      final String query = 'SELECT * FROM ingredients $whereClause ORDER BY $orderBy';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);

      final ingredients = maps.map((map) => Ingredient.fromMap(map)).toList();

      // Only emit to stream if this is not a filtered query to avoid unnecessary updates
      if (filter == null) {
        _ingredientsController.add(ingredients);
      }

      return ingredients;
    } catch (e) {
      // Log error for debugging if needed
      // print('Error in getIngredients: $e');
      rethrow;
    }
  }

  Future<Ingredient?> getIngredientById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ingredients',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Ingredient.fromMap(maps.first);
    }
    return null;
  }

  Future<int> createIngredient(Ingredient ingredient) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    final ingredientWithTimestamps = ingredient.copyWith(
      createdAt: now,
      updatedAt: now,
    );

    final id = await db.insert('ingredients', ingredientWithTimestamps.toMap());

    return id;
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    final db = await _databaseHelper.database;
    final updatedIngredient = ingredient.copyWith(updatedAt: DateTime.now());

    await db.update(
      'ingredients',
      updatedIngredient.toMap(),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );

  }

  Future<void> deleteIngredient(int id) async {
    final db = await _databaseHelper.database;

    // Soft delete by setting is_active to 0
    await db.update(
      'ingredients',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

  }

  Future<void> updateIngredientQuantity(int ingredientId, double newQuantity, {String? reason}) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    // Get current ingredient
    final ingredient = await getIngredientById(ingredientId);
    if (ingredient == null) return;

    // Update ingredient quantity
    await db.update(
      'ingredients',
      {
        'current_quantity': newQuantity,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [ingredientId],
    );

    // Record transaction
    await db.insert('inventory_transactions', {
      'ingredient_id': ingredientId,
      'transaction_type': 'ADJUSTMENT',
      'quantity': newQuantity - ingredient.currentQuantity,
      'unit': ingredient.unit,
      'reason': reason ?? 'Manual adjustment',
      'created_at': now.millisecondsSinceEpoch,
    });

  }

  // STOCKTAKE OPERATIONS

  Future<List<StocktakeSession>> getStocktakeSessions() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'stocktake_sessions',
      orderBy: 'created_at DESC',
    );

    final sessions = maps.map((map) => StocktakeSession.fromMap(map)).toList();

    // Emit to stream for real-time updates
    _stocktakeSessionsController.add(sessions);

    return sessions;
  }

  Future<StocktakeSession?> getStocktakeSessionById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stocktake_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return StocktakeSession.fromMap(maps.first);
    }
    return null;
  }

  Future<int> createStocktakeSession({
    required String name,
    String? description,
    required String type,
    String? location,
    List<String>? categoryFilter,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    // Get all ingredients to include in stocktake
    final filter = InventoryFilter(
      categories: categoryFilter,
      active: true,
    );
    final ingredients = await getIngredients(filter: filter);

    // Create stocktake session
    final session = StocktakeSession(
      name: name,
      description: description,
      type: type,
      status: 'draft',
      location: location,
      totalItems: ingredients.length,
      countedItems: 0,
      varianceCount: 0,
      totalVarianceValue: 0,
      createdAt: now,
    );

    final sessionId = await db.insert('stocktake_sessions', session.toMap());

    // Create stocktake items for each ingredient
    for (final ingredient in ingredients) {
      final stocktakeItem = StocktakeItem(
        sessionId: sessionId,
        ingredientId: ingredient.id!,
        ingredientName: ingredient.name,
        unit: ingredient.unit,
        expectedQuantity: ingredient.currentQuantity,
      );

      await db.insert('stocktake_items', stocktakeItem.toMap());
    }

    // Refresh sessions stream
    await getStocktakeSessions();

    return sessionId;
  }

  Future<void> startStocktakeSession(int sessionId) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    await db.update(
      'stocktake_sessions',
      {
        'status': 'in_progress',
        'started_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    // Refresh sessions stream
    await getStocktakeSessions();
  }

  Future<List<StocktakeItem>> getStocktakeItems(int sessionId) async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'stocktake_items',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'ingredient_name ASC',
    );

    return maps.map((map) => StocktakeItem.fromMap(map)).toList();
  }

  Future<void> updateStocktakeItemCount(
    int itemId,
    double countedQuantity, {
    String? notes,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    // Get the stocktake item
    final List<Map<String, dynamic>> itemMaps = await db.query(
      'stocktake_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (itemMaps.isEmpty) return;

    final item = StocktakeItem.fromMap(itemMaps.first);
    final variance = countedQuantity - item.expectedQuantity;
    final ingredient = await getIngredientById(item.ingredientId);
    final varianceValue = variance * (ingredient?.costPerUnit ?? 0);

    // Update stocktake item
    await db.update(
      'stocktake_items',
      {
        'counted_quantity': countedQuantity,
        'variance': variance,
        'variance_value': varianceValue,
        'notes': notes,
        'counted_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // Update session statistics
    await _updateSessionStatistics(item.sessionId);
  }

  Future<void> _updateSessionStatistics(int sessionId) async {
    final db = await _databaseHelper.database;

    // Get session statistics
    final List<Map<String, dynamic>> statsResult = await db.rawQuery('''
      SELECT
        COUNT(*) as total_items,
        COUNT(counted_quantity) as counted_items,
        COUNT(CASE WHEN ABS(variance) > 0.01 THEN 1 END) as variance_count,
        COALESCE(SUM(variance_value), 0) as total_variance_value
      FROM stocktake_items
      WHERE session_id = ?
    ''', [sessionId]);

    if (statsResult.isNotEmpty) {
      final stats = statsResult.first;
      await db.update(
        'stocktake_sessions',
        {
          'total_items': stats['total_items'],
          'counted_items': stats['counted_items'],
          'variance_count': stats['variance_count'],
          'total_variance_value': stats['total_variance_value'],
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    }

    // Refresh sessions stream
    await getStocktakeSessions();
  }

  Future<void> completeStocktakeSession(int sessionId, {bool applyChanges = false}) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    if (applyChanges) {
      // Apply all counted quantities to actual inventory
      final items = await getStocktakeItems(sessionId);

      for (final item in items) {
        if (item.countedQuantity != null) {
          await updateIngredientQuantity(
            item.ingredientId,
            item.countedQuantity!,
            reason: 'Stocktake adjustment - Session: $sessionId',
          );
        }
      }
    }

    // Mark session as completed
    await db.update(
      'stocktake_sessions',
      {
        'status': 'completed',
        'completed_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    // Refresh sessions stream
    await getStocktakeSessions();
  }

  Future<void> cancelStocktakeSession(int sessionId) async {
    final db = await _databaseHelper.database;

    await db.update(
      'stocktake_sessions',
      {'status': 'cancelled'},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    // Refresh sessions stream
    await getStocktakeSessions();
  }

  // INVENTORY STATISTICS

  Future<Map<String, dynamic>> getInventoryStatistics() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_ingredients,
        COALESCE(SUM(current_quantity * cost_per_unit), 0) as total_value,
        COUNT(CASE WHEN current_quantity <= minimum_threshold THEN 1 END) as low_stock_count,
        COUNT(CASE WHEN current_quantity <= minimum_threshold * 0.5 THEN 1 END) as critical_stock_count,
        COUNT(CASE WHEN current_quantity <= 0 THEN 1 END) as out_of_stock_count
      FROM ingredients
      WHERE is_active = 1
    ''');

    return result.first;
  }

  // Sample data for Vietnamese restaurant
  Future<void> createSampleInventoryData() async {
    final vietnameseIngredients = [
      // Proteins - Thịt & Hải sản
      Ingredient(
        name: 'Thịt bò nạm (Beef Brisket)',
        description: 'Premium beef brisket for phở bò',
        category: 'protein',
        unit: 'kg',
        currentQuantity: 15.5,
        minimumThreshold: 5.0,
        costPerUnit: 280000, // 280k VND per kg
        supplier: 'Chợ Bến Thành',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Thịt heo ba chỉ (Pork Belly)',
        description: 'Fresh pork belly for Vietnamese dishes',
        category: 'protein',
        unit: 'kg',
        currentQuantity: 8.2,
        minimumThreshold: 3.0,
        costPerUnit: 190000,
        supplier: 'Chợ Bến Thành',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Tôm sú (Tiger Prawns)',
        description: 'Fresh tiger prawns for seafood dishes',
        category: 'protein',
        unit: 'kg',
        currentQuantity: 2.8,
        minimumThreshold: 1.0,
        costPerUnit: 450000,
        supplier: 'Cảng cá Vũng Tàu',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Cá tra (Catfish)',
        description: 'Fresh catfish fillets',
        category: 'protein',
        unit: 'kg',
        currentQuantity: 4.2,
        minimumThreshold: 2.0,
        costPerUnit: 85000,
        supplier: 'Cảng cá Cần Thơ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Vegetables - Rau củ
      Ingredient(
        name: 'Rau húng quế (Thai Basil)',
        description: 'Fresh Thai basil for phở garnish',
        category: 'vegetables',
        unit: 'kg',
        currentQuantity: 2.1,
        minimumThreshold: 1.0,
        costPerUnit: 35000,
        supplier: 'Dalat Farm',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Giá đỗ (Bean Sprouts)',
        description: 'Fresh bean sprouts for phở',
        category: 'vegetables',
        unit: 'kg',
        currentQuantity: 5.0,
        minimumThreshold: 2.0,
        costPerUnit: 15000,
        supplier: 'Chợ đầu mối Thủ Đức',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Hành tây (Yellow Onions)',
        description: 'Yellow onions for cooking base',
        category: 'vegetables',
        unit: 'kg',
        currentQuantity: 6.5,
        minimumThreshold: 3.0,
        costPerUnit: 18000,
        supplier: 'Dalat Farm',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Cà rốt (Carrots)',
        description: 'Fresh carrots for broth and garnish',
        category: 'vegetables',
        unit: 'kg',
        currentQuantity: 3.8,
        minimumThreshold: 2.0,
        costPerUnit: 22000,
        supplier: 'Dalat Farm',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Gừng tươi (Fresh Ginger)',
        description: 'Fresh ginger for broth and marinades',
        category: 'vegetables',
        unit: 'kg',
        currentQuantity: 1.2,
        minimumThreshold: 0.5,
        costPerUnit: 45000,
        supplier: 'Chợ Bến Thành',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Grains & Noodles - Ngũ cốc & Bánh
      Ingredient(
        name: 'Bánh phở tươi (Fresh Rice Noodles)',
        description: 'Fresh rice noodles for phở',
        category: 'grains',
        unit: 'kg',
        currentQuantity: 25.0,
        minimumThreshold: 10.0,
        costPerUnit: 18000,
        supplier: 'Xưởng bánh phở Sài Gòn',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Bánh tráng (Rice Paper)',
        description: 'Rice paper for spring rolls',
        category: 'grains',
        unit: 'cái',
        currentQuantity: 500.0,
        minimumThreshold: 100.0,
        costPerUnit: 500,
        supplier: 'Cửa hàng bánh tráng Tây Ninh',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Bún tươi (Fresh Rice Vermicelli)',
        description: 'Fresh rice vermicelli for bún bò Huế',
        category: 'grains',
        unit: 'kg',
        currentQuantity: 12.0,
        minimumThreshold: 5.0,
        costPerUnit: 20000,
        supplier: 'Xưởng bún Huế',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Spices & Seasonings - Gia vị
      Ingredient(
        name: 'Nước mắm (Fish Sauce)',
        description: 'Premium Vietnamese fish sauce',
        category: 'spices',
        unit: 'lít',
        currentQuantity: 8.5,
        minimumThreshold: 3.0,
        costPerUnit: 65000,
        supplier: 'Phú Quốc Fish Sauce',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Đường phèn (Rock Sugar)',
        description: 'Rock sugar for caramel and sweetening',
        category: 'spices',
        unit: 'kg',
        currentQuantity: 5.2,
        minimumThreshold: 2.0,
        costPerUnit: 35000,
        supplier: 'Chợ Kim Biên',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Hạt nêm (Seasoning Powder)',
        description: 'Vietnamese seasoning powder',
        category: 'spices',
        unit: 'hộp',
        currentQuantity: 15.0,
        minimumThreshold: 5.0,
        costPerUnit: 12000,
        supplier: 'Knorr Vietnam',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Thịt nướng gia vị (BBQ Spice Mix)',
        description: 'Vietnamese BBQ spice blend',
        category: 'spices',
        unit: 'túi',
        currentQuantity: 8.0,
        minimumThreshold: 3.0,
        costPerUnit: 25000,
        supplier: 'Gia vị Sài Gòn',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Beverages - Đồ uống
      Ingredient(
        name: 'Cà phê robusta (Robusta Coffee)',
        description: 'Premium Vietnamese robusta coffee beans',
        category: 'beverages',
        unit: 'kg',
        currentQuantity: 4.8,
        minimumThreshold: 2.0,
        costPerUnit: 120000,
        supplier: 'Buôn Ma Thuột Coffee',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Trà đá (Ice Tea)',
        description: 'Traditional Vietnamese iced tea leaves',
        category: 'beverages',
        unit: 'kg',
        currentQuantity: 2.5,
        minimumThreshold: 1.0,
        costPerUnit: 150000,
        supplier: 'Trà Thái Nguyên',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Nước dừa (Coconut Water)',
        description: 'Fresh coconut water',
        category: 'beverages',
        unit: 'cái',
        currentQuantity: 50.0,
        minimumThreshold: 20.0,
        costPerUnit: 15000,
        supplier: 'Vườn dừa Bến Tre',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Dairy - Sữa & Phô mai
      Ingredient(
        name: 'Sữa đặc có đường (Condensed Milk)',
        description: 'Sweetened condensed milk for Vietnamese coffee',
        category: 'dairy',
        unit: 'hộp',
        currentQuantity: 24.0,
        minimumThreshold: 10.0,
        costPerUnit: 28000,
        supplier: 'Vinamilk',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Other - Khác
      Ingredient(
        name: 'Đá viên (Ice Cubes)',
        description: 'Ice cubes for drinks and food service',
        category: 'other',
        unit: 'kg',
        currentQuantity: 100.0,
        minimumThreshold: 30.0,
        costPerUnit: 3000,
        supplier: 'Nhà máy đá Sài Gòn',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        name: 'Tăm tre (Bamboo Toothpicks)',
        description: 'Bamboo toothpicks for food presentation',
        category: 'other',
        unit: 'hộp',
        currentQuantity: 50.0,
        minimumThreshold: 20.0,
        costPerUnit: 5000,
        supplier: 'Đồ gỗ Việt Nam',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final ingredient in vietnameseIngredients) {
      await createIngredient(ingredient);
    }
  }

  void dispose() {
    _ingredientsController.close();
    _stocktakeSessionsController.close();
  }
}