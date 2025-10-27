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
    // Debug logging to see what we're getting from database
    print('🔍 MenuOption.fromMap received for "${stringFromDynamic(map['name'])}":');
    print('   is_available raw value: ${map['is_available']} (${map['is_available'].runtimeType})');

    // Handle both boolean and integer values from database
    bool isAvailableValue;
    final rawIsAvailable = map['is_available'];
    if (rawIsAvailable is bool) {
      isAvailableValue = rawIsAvailable;
      print('   is_available as bool: $isAvailableValue');
    } else if (rawIsAvailable is int) {
      isAvailableValue = rawIsAvailable == 1;
      print('   is_available as int->bool: $isAvailableValue (from $rawIsAvailable)');
    } else {
      isAvailableValue = true; // Default to available if unexpected type
      print('   is_available defaulted to true (unexpected type: ${rawIsAvailable.runtimeType})');
    }

    return MenuOption(
  id: map['id']?.toString() ?? '',
  name: stringFromDynamic(map['name']),
      price: (map['price'] ?? 0).toDouble(),
  description: stringFromDynamic(map['description']),
  category: stringFromDynamic(map['category']),
      isAvailable: isAvailableValue,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  /// Helper method to parse DateTime from various formats (SQLite integer or Supabase ISO string)
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }

    try {
      // If it's already a DateTime, return as-is
      if (dateValue is DateTime) {
        return dateValue;
      }

      // If it's a string (Supabase ISO format), try to parse it
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }

      // If it's a number (SQLite timestamp in milliseconds or seconds)
      if (dateValue is int) {
        // Check if it's in milliseconds (13 digits) or seconds (10 digits)
        if (dateValue.toString().length == 13) {
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        }
      }

      // Fallback to current time
      print('⚠️ Warning: Could not parse dateValue: $dateValue (${dateValue.runtimeType})');
      return DateTime.now();
    } catch (e) {
      print('❌ Error parsing dateValue: $dateValue, error: $e');
      return DateTime.now();
    }
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
    // Debug logging to see what we're getting from database
    print('🔍 OptionGroup.fromMap received:');
    print('   is_required raw value: ${map['is_required']} (${map['is_required'].runtimeType})');

    // Handle both boolean and integer values from database
    bool isRequiredValue;
    final rawIsRequired = map['is_required'];
    if (rawIsRequired is bool) {
      isRequiredValue = rawIsRequired;
      print('   is_required as bool: $isRequiredValue');
    } else if (rawIsRequired is int) {
      isRequiredValue = rawIsRequired == 1;
      print('   is_required as int->bool: $isRequiredValue (from $rawIsRequired)');
    } else {
      isRequiredValue = false;
      print('   is_required defaulted to false (unexpected type: ${rawIsRequired.runtimeType})');
    }

    return OptionGroup(
      id: map['id']?.toString() ?? '',
      name: stringFromDynamic(map['name']),
      description: stringFromDynamic(map['description']),
      minSelection: map['min_selection'] ?? 0,
      maxSelection: map['max_selection'] ?? 1,
      options: [], // Will be loaded separately
      isRequired: isRequiredValue,
      displayOrder: map['display_order'] ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: MenuOption._parseDateTime(map['created_at']),
      updatedAt: MenuOption._parseDateTime(map['updated_at']),
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
      createdAt: MenuOption._parseDateTime(map['created_at']),
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
      createdAt: MenuOption._parseDateTime(map['created_at']),
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