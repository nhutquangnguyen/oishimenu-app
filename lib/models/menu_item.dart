
import '../core/utils/parse_utils.dart';

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String categoryName;
  final String description;
  final List<String> photos;
  final bool availableStatus;
  final Map<String, dynamic>? availabilitySchedule;
  final List<MenuSize> sizes;
  final List<Recipe> recipes;
  final double? costPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryName,
    this.description = '',
    this.photos = const [],
    this.availableStatus = true,
    this.availabilitySchedule,
    this.sizes = const [],
    this.recipes = const [],
    this.costPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
  id: map['id']?.toString() ?? '',
  name: stringFromDynamic(map['name']),
      price: (map['price'] ?? 0).toDouble(),
  categoryName: stringFromDynamic(map['category_name']),
  description: stringFromDynamic(map['description']),
      photos: _parsePhotos(map['photos']),
      availableStatus: (map['available_status'] ?? 1) == 1,
      availabilitySchedule: map['availability_schedule'],
      sizes: [],  // Simplified for now
      recipes: [], // Simplified for now
      costPrice: map['cost_price']?.toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  static List<String> _parsePhotos(dynamic photos) {
    if (photos == null) return [];

    if (photos is String) {
      if (photos.isEmpty) return [];
      return photos.split(',').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
    }

    if (photos is List) {
      return photos.map((photo) => stringFromDynamic(photo)).where((s) => s.isNotEmpty).toList();
    }

    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'name': name,
      'price': price,
      'description': description,
      'category_name': categoryName, // Include category name for service conversion
      'photos': photos.isNotEmpty ? photos.join(',') : null,
      'available_status': availableStatus ? 1 : 0,
      'availability_schedule': availabilitySchedule?.toString(),
      'cost_price': costPrice,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? categoryName,
    String? description,
    List<String>? photos,
    bool? availableStatus,
    Map<String, dynamic>? availabilitySchedule,
    List<MenuSize>? sizes,
    List<Recipe>? recipes,
    double? costPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      availableStatus: availableStatus ?? this.availableStatus,
      availabilitySchedule: availabilitySchedule ?? this.availabilitySchedule,
      sizes: sizes ?? this.sizes,
      recipes: recipes ?? this.recipes,
      costPrice: costPrice ?? this.costPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MenuSize {
  final String name;
  final double price;
  final bool isDefault;

  MenuSize({
    required this.name,
    required this.price,
    this.isDefault = false,
  });

  factory MenuSize.fromMap(Map<String, dynamic> map) {
    return MenuSize(
      name: stringFromDynamic(map['name']),
      price: (map['price'] ?? 0).toDouble(),
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'isDefault': isDefault,
    };
  }
}

class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final String instructions;
  final int prepTime;
  final int servingSize;
  final double costPerServing;

  Recipe({
    required this.id,
    required this.name,
    this.ingredients = const [],
    this.instructions = '',
    this.prepTime = 0,
    this.servingSize = 1,
    this.costPerServing = 0.0,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] ?? '',
      name: stringFromDynamic(map['name']),
      ingredients: (map['ingredients'] as List<dynamic>?)
          ?.map((ingredient) => RecipeIngredient.fromMap(ingredient))
          .toList() ?? [],
      instructions: stringFromDynamic(map['instructions']),
      prepTime: map['prepTime'] ?? 0,
      servingSize: map['servingSize'] ?? 1,
      costPerServing: (map['costPerServing'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients.map((ingredient) => ingredient.toMap()).toList(),
      'instructions': instructions,
      'prepTime': prepTime,
      'servingSize': servingSize,
      'costPerServing': costPerServing,
    };
  }
}

class RecipeIngredient {
  final String ingredientId;
  final double quantity;
  final String unit;
  final String notes;

  RecipeIngredient({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.notes = '',
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      ingredientId: stringFromDynamic(map['ingredientId']),
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: stringFromDynamic(map['unit']),
      notes: stringFromDynamic(map['notes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ingredientId': ingredientId,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
    };
  }
}

class MenuCategory {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuCategory({
    required this.id,
    required this.name,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id']?.toString() ?? '',
      name: stringFromDynamic(map['name']),
      displayOrder: map['display_order'] ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'name': name,
      'display_order': displayOrder,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MenuCategory copyWith({
    String? id,
    String? name,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}