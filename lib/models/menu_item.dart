
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
  // Recipes removed - no longer tracking inventory
  final double? costPrice;
  final int displayOrder;
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
    this.costPrice,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    // Debug the boolean conversion process
    final rawAvailableStatus = map['available_status'];
    final convertedBool = rawAvailableStatus is bool
        ? rawAvailableStatus
        : (rawAvailableStatus ?? 1) == 1;


    return MenuItem(
  id: map['id']?.toString() ?? '',
  name: stringFromDynamic(map['name']),
      price: (map['price'] ?? 0).toDouble(),
  categoryName: stringFromDynamic(map['category_name']),
  description: stringFromDynamic(map['description']),
      photos: _parsePhotos(map['photos']),
      availableStatus: convertedBool,
      availabilitySchedule: map['availability_schedule'],
      sizes: [],  // Simplified for now
      costPrice: map['cost_price']?.toDouble(),
      displayOrder: map['display_order'] ?? 0,
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
      'display_order': displayOrder,
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
    double? costPrice,
    int? displayOrder,
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