import '../core/utils/parse_utils.dart';

class Restaurant {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? phone;
  final String? email;
  final String? website;
  final String country;
  final String cuisineType;
  final int priceRange;
  final String ownerUserId;
  final String? brand;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.phone,
    this.email,
    this.website,
    required this.country,
    required this.cuisineType,
    required this.priceRange,
    required this.ownerUserId,
    this.brand,
    required this.isActive,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id']?.toString() ?? '',
      name: stringFromDynamic(map['name']),
      slug: stringFromDynamic(map['slug']),
      description: stringFromDynamic(map['description']),
      logoUrl: map['logo_url']?.toString(),
      coverImageUrl: map['cover_image_url']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      country: stringFromDynamic(map['country']) == '' ? 'VN' : stringFromDynamic(map['country']),
      cuisineType: stringFromDynamic(map['cuisine_type']) == '' ? 'vietnamese' : stringFromDynamic(map['cuisine_type']),
      priceRange: (map['price_range'] as num?)?.toInt() ?? 2,
      ownerUserId: map['owner_user_id']?.toString() ?? '',
      brand: map['brand']?.toString(),
      isActive: (map['is_active'] ?? 1) == 1,
      isDefault: (map['is_default'] ?? 0) == 1,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isEmpty ? null : int.tryParse(id),
      'name': name,
      'slug': slug,
      'description': description,
      'logo_url': logoUrl,
      'cover_image_url': coverImageUrl,
      'phone': phone,
      'email': email,
      'website': website,
      'country': country,
      'cuisine_type': cuisineType,
      'price_range': priceRange,
      'owner_user_id': ownerUserId.isEmpty ? null : int.tryParse(ownerUserId),
      'brand': brand,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
    String? phone,
    String? email,
    String? website,
    String? country,
    String? cuisineType,
    int? priceRange,
    String? ownerUserId,
    String? brand,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      country: country ?? this.country,
      cuisineType: cuisineType ?? this.cuisineType,
      priceRange: priceRange ?? this.priceRange,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      brand: brand ?? this.brand,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Restaurant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Restaurant(id: $id, name: $name, slug: $slug, country: $country, cuisineType: $cuisineType, priceRange: $priceRange)';
  }

  // Helper getters
  String get priceRangeDisplay {
    switch (priceRange) {
      case 1:
        return '\$';
      case 2:
        return '\$\$';
      case 3:
        return '\$\$\$';
      case 4:
        return '\$\$\$\$';
      default:
        return '\$\$';
    }
  }

  String get displayName => name.isNotEmpty ? name : 'Restaurant';
  String get displayBrand => brand?.isNotEmpty == true ? brand! : displayName;

  /// Helper method to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }

    try {
      // If it's already a DateTime, return as-is
      if (dateValue is DateTime) {
        return dateValue;
      }

      // If it's a string (ISO format from Supabase), try to parse it
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }

      // If it's a number (timestamp in milliseconds or seconds)
      if (dateValue is int) {
        // Check if it's in milliseconds (13 digits) or seconds (10 digits)
        if (dateValue.toString().length >= 13) {
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        }
      }

      // If it's a double/num, convert to int first
      if (dateValue is num) {
        final intValue = dateValue.toInt();
        if (intValue.toString().length >= 13) {
          return DateTime.fromMillisecondsSinceEpoch(intValue);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
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
}