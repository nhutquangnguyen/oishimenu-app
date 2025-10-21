// Inventory and Stocktake Models for Vietnamese Restaurant POS
import '../core/utils/parse_utils.dart';
// Following patterns from oishimenu-g components

class Ingredient {
  final int? id;
  final String name;
  final String? description;
  final String category;
  final String unit; // kg, lít, cái, hộp, etc.
  final double currentQuantity;
  final double minimumThreshold;
  final double costPerUnit; // Cost in VND
  final String? supplier;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ingredient({
    this.id,
    required this.name,
    this.description,
    required this.category,
    required this.unit,
    required this.currentQuantity,
    required this.minimumThreshold,
    required this.costPerUnit,
    this.supplier,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Vietnamese restaurant ingredient categories
  static const List<String> categories = [
    'dairy', 'protein', 'vegetables', 'fruits', 'grains',
    'spices', 'beverages', 'other'
  ];

  // Stock status based on current quantity vs minimum threshold
  String get stockStatus {
    if (currentQuantity <= 0) return 'out_of_stock';
    if (currentQuantity <= minimumThreshold * 0.5) return 'critical';
    if (currentQuantity <= minimumThreshold) return 'low_stock';
    return 'in_stock';
  }

  // Total value in VND
  double get totalValue => currentQuantity * costPerUnit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'unit': unit,
      'current_quantity': currentQuantity,
      'minimum_threshold': minimumThreshold,
      'cost_per_unit': costPerUnit,
      'supplier': supplier,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as int?,
      name: stringFromDynamic(map['name']),
      description: stringFromDynamic(map['description']),
      category: stringFromDynamic(map['category']),
      unit: stringFromDynamic(map['unit']),
      currentQuantity: map['current_quantity']?.toDouble() ?? 0.0,
      minimumThreshold: map['minimum_threshold']?.toDouble() ?? 0.0,
      costPerUnit: map['cost_per_unit']?.toDouble() ?? 0.0,
      supplier: stringFromDynamic(map['supplier']),
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Ingredient copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    String? unit,
    double? currentQuantity,
    double? minimumThreshold,
    double? costPerUnit,
    String? supplier,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minimumThreshold: minimumThreshold ?? this.minimumThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplier: supplier ?? this.supplier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StocktakeSession {
  final int? id;
  final String name;
  final String? description;
  final String type; // full, partial, cycle
  final String status; // draft, in_progress, completed, cancelled
  final String? location;
  final int totalItems;
  final int countedItems;
  final int varianceCount;
  final double totalVarianceValue; // in VND
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  StocktakeSession({
    this.id,
    required this.name,
    this.description,
    required this.type,
    required this.status,
    this.location,
    required this.totalItems,
    required this.countedItems,
    required this.varianceCount,
    required this.totalVarianceValue,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  double get progressPercentage {
    return totalItems > 0 ? (countedItems / totalItems) * 100 : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'status': status,
      'location': location,
      'total_items': totalItems,
      'counted_items': countedItems,
      'variance_count': varianceCount,
      'total_variance_value': totalVarianceValue,
      'created_at': createdAt.millisecondsSinceEpoch,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory StocktakeSession.fromMap(Map<String, dynamic> map) {
    return StocktakeSession(
      id: map['id'] as int?,
      name: stringFromDynamic(map['name']),
      description: stringFromDynamic(map['description']),
      type: stringFromDynamic(map['type']),
      status: stringFromDynamic(map['status']),
      location: stringFromDynamic(map['location']),
      totalItems: map['total_items'] ?? 0,
      countedItems: map['counted_items'] ?? 0,
      varianceCount: map['variance_count'] ?? 0,
      totalVarianceValue: map['total_variance_value']?.toDouble() ?? 0.0,
      createdAt: map['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] != null
          ? (map['started_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int)
              : DateTime.parse(map['started_at'] as String))
          : null,
      completedAt: map['completed_at'] != null
          ? (map['completed_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
              : DateTime.parse(map['completed_at'] as String))
          : null,
    );
  }
}

class StocktakeItem {
  final int? id;
  final int sessionId;
  final int ingredientId;
  final String ingredientName;
  final String unit;
  final double expectedQuantity;
  final double? countedQuantity;
  final double? variance;
  final double? varianceValue; // in VND
  final String? notes;
  final DateTime? countedAt;

  StocktakeItem({
    this.id,
    required this.sessionId,
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.expectedQuantity,
    this.countedQuantity,
    this.variance,
    this.varianceValue,
    this.notes,
    this.countedAt,
  });

  bool get isCounted => countedQuantity != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'unit': unit,
      'expected_quantity': expectedQuantity,
      'counted_quantity': countedQuantity,
      'variance': variance,
      'variance_value': varianceValue,
      'notes': notes,
      'counted_at': countedAt?.millisecondsSinceEpoch,
    };
  }

  factory StocktakeItem.fromMap(Map<String, dynamic> map) {
    return StocktakeItem(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      ingredientId: map['ingredient_id'] as int,
      ingredientName: stringFromDynamic(map['ingredient_name']),
      unit: stringFromDynamic(map['unit']),
      expectedQuantity: map['expected_quantity']?.toDouble() ?? 0.0,
      countedQuantity: map['counted_quantity']?.toDouble(),
      variance: map['variance']?.toDouble(),
      varianceValue: map['variance_value']?.toDouble(),
      notes: stringFromDynamic(map['notes']),
      countedAt: map['counted_at'] != null
          ? (map['counted_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['counted_at'] as int)
              : DateTime.parse(map['counted_at'] as String))
          : null,
    );
  }
}

// Inventory filter for searching and sorting
class InventoryFilter {
  final List<String>? categories;
  final bool? lowStock;
  final bool? active;
  final String? sortBy; // name, quantity, cost
  final String? sortOrder; // asc, desc

  InventoryFilter({
    this.categories,
    this.lowStock,
    this.active,
    this.sortBy,
    this.sortOrder,
  });
}

// Vietnamese currency formatting utility
class CurrencyUtils {
  static String formatVND(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}đ';
  }

  static String formatUnit(double quantity, String unit) {
    return '${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1)} $unit';
  }
}