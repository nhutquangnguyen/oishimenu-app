/// Models for menu options and option groups
/// Implements the many-to-many relationship structure described in the requirements

import '../core/utils/parse_utils.dart';

class MenuOption {
  final String id;
  final String name;
  final double price;           // Additional cost for this option
  final String? description;
  final String? category;       // e.g., 'size', 'topping', 'sweetness'
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuOption({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.category,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuOption.fromMap(Map<String, dynamic> map) {
    return MenuOption(
  id: map['id']?.toString() ?? '',
  name: stringFromDynamic(map['name']),
      price: (map['price'] ?? 0).toDouble(),
  description: stringFromDynamic(map['description']),
  category: stringFromDynamic(map['category']),
      isAvailable: (map['is_available'] ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'is_available': isAvailable ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MenuOption copyWith({
    String? id,
    String? name,
    double? price,
    String? description,
    String? category,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuOption(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OptionGroup {
  final String id;
  final String name;             // e.g., "Size", "Sweetness", "Toppings"
  final String? description;
  final int minSelection;        // Must select at least this many
  final int maxSelection;        // Can select at most this many
  final List<MenuOption> options; // The actual choices
  final bool isRequired;         // Whether this group must be selected
  final int displayOrder;        // Order to display in UI
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  OptionGroup({
    required this.id,
    required this.name,
    this.description,
    this.minSelection = 0,
    this.maxSelection = 1,
    this.options = const [],
    this.isRequired = false,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OptionGroup.fromMap(Map<String, dynamic> map) {
    return OptionGroup(
      id: map['id']?.toString() ?? '',
      name: stringFromDynamic(map['name']),
      description: stringFromDynamic(map['description']),
      minSelection: map['min_selection'] ?? 0,
      maxSelection: map['max_selection'] ?? 1,
      options: [], // Will be loaded separately
      isRequired: (map['is_required'] ?? 0) == 1,
      displayOrder: map['display_order'] ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'min_selection': minSelection,
      'max_selection': maxSelection,
      'is_required': isRequired ? 1 : 0,
      'display_order': displayOrder,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };

    // Only include id for existing records (updates)
    if (id.isNotEmpty) {
      map['id'] = int.tryParse(id);
    }

    return map;
  }

  OptionGroup copyWith({
    String? id,
    String? name,
    String? description,
    int? minSelection,
    int? maxSelection,
    List<MenuOption>? options,
    bool? isRequired,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OptionGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      options: options ?? this.options.map((option) => option.copyWith()).toList(),
      isRequired: isRequired ?? this.isRequired,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Junction table for many-to-many relationship between MenuItem and OptionGroup
class MenuItemOptionGroup {
  final String id;
  final String menuItemId;
  final String optionGroupId;
  final bool isRequired;
  final int displayOrder;
  final DateTime createdAt;

  MenuItemOptionGroup({
    required this.id,
    required this.menuItemId,
    required this.optionGroupId,
    this.isRequired = false,
    this.displayOrder = 0,
    required this.createdAt,
  });

  factory MenuItemOptionGroup.fromMap(Map<String, dynamic> map) {
    return MenuItemOptionGroup(
      id: map['id']?.toString() ?? '',
      menuItemId: map['menu_item_id']?.toString() ?? '',
      optionGroupId: map['option_group_id']?.toString() ?? '',
      isRequired: (map['is_required'] ?? 0) == 1,
      displayOrder: map['display_order'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'menu_item_id': int.tryParse(menuItemId),
      'option_group_id': int.tryParse(optionGroupId),
      'is_required': isRequired ? 1 : 0,
      'display_order': displayOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// Junction table for many-to-many relationship between OptionGroup and MenuOption
class OptionGroupOption {
  final String id;
  final String optionGroupId;
  final String optionId;
  final int displayOrder;
  final DateTime createdAt;

  OptionGroupOption({
    required this.id,
    required this.optionGroupId,
    required this.optionId,
    this.displayOrder = 0,
    required this.createdAt,
  });

  factory OptionGroupOption.fromMap(Map<String, dynamic> map) {
    return OptionGroupOption(
      id: map['id']?.toString() ?? '',
      optionGroupId: map['option_group_id']?.toString() ?? '',
      optionId: map['option_id']?.toString() ?? '',
      displayOrder: map['display_order'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'option_group_id': int.tryParse(optionGroupId),
      'option_id': int.tryParse(optionId),
      'display_order': displayOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// Represents a selected option during order creation
class SelectedOption {
  final String optionId;
  final String optionGroupId;
  final String optionGroupName;
  final String optionName;
  final double optionPrice;

  SelectedOption({
    required this.optionId,
    required this.optionGroupId,
    required this.optionGroupName,
    required this.optionName,
    required this.optionPrice,
  });

  factory SelectedOption.fromMap(Map<String, dynamic> map) {
    return SelectedOption(
      optionId: map['option_id']?.toString() ?? '',
      optionGroupId: map['option_group_id']?.toString() ?? '',
      optionGroupName: stringFromDynamic(map['option_group_name']),
      optionName: stringFromDynamic(map['option_name']),
      optionPrice: (map['option_price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'option_id': optionId,
      'option_group_id': optionGroupId,
      'option_group_name': optionGroupName,
      'option_name': optionName,
      'option_price': optionPrice,
    };
  }
}