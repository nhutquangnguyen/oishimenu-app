import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../models/menu_item.dart';
import 'database_helper.dart';

class SampleDataService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<void> createSampleMenuItems() async {
    final db = await _databaseHelper.database;

    // Check if sample data already exists
    final existingItems = await db.query('menu_items', limit: 1);
    if (existingItems.isNotEmpty) {
      print('Sample menu items already exist');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Sample Vietnamese dishes
    final sampleItems = [
      // Vietnamese Specials (category_id: 5)
      {
        'name': 'Pho Bo (Beef Noodle Soup)',
        'description': 'Traditional Vietnamese beef noodle soup with rice noodles, herbs, and tender beef slices',
        'price': 12.99,
        'category_id': 5,
        'cost_price': 6.50,
        'available_status': 1,
        'photos': 'pho_bo.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Pho Ga (Chicken Noodle Soup)',
        'description': 'Aromatic chicken noodle soup with fresh herbs and rice noodles',
        'price': 11.99,
        'category_id': 5,
        'cost_price': 5.80,
        'available_status': 1,
        'photos': 'pho_ga.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Banh Mi Thit Nuong',
        'description': 'Grilled pork banh mi with pickled vegetables, cilantro, and chili mayo',
        'price': 8.99,
        'category_id': 5,
        'cost_price': 4.20,
        'available_status': 1,
        'photos': 'banh_mi.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bun Bo Hue',
        'description': 'Spicy beef noodle soup from Hue with lemongrass and chili oil',
        'price': 13.99,
        'category_id': 5,
        'cost_price': 7.00,
        'available_status': 1,
        'photos': 'bun_bo_hue.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Goi Cuon (Fresh Spring Rolls)',
        'description': 'Fresh spring rolls with shrimp, pork, herbs, and peanut sauce',
        'price': 7.99,
        'category_id': 1, // Appetizers
        'cost_price': 3.50,
        'available_status': 1,
        'photos': 'goi_cuon.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Main Course (category_id: 2)
      {
        'name': 'Com Tam (Broken Rice)',
        'description': 'Grilled pork chop with broken rice, pickled vegetables, and fish sauce',
        'price': 14.99,
        'category_id': 2,
        'cost_price': 7.50,
        'available_status': 1,
        'photos': 'com_tam.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bun Cha Hanoi',
        'description': 'Grilled pork patties with rice vermicelli, herbs, and dipping sauce',
        'price': 13.99,
        'category_id': 2,
        'cost_price': 6.80,
        'available_status': 1,
        'photos': 'bun_cha.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Appetizers (category_id: 1)
      {
        'name': 'Cha Gio (Fried Spring Rolls)',
        'description': 'Crispy fried spring rolls with pork, shrimp, and vegetables',
        'price': 8.99,
        'category_id': 1,
        'cost_price': 4.00,
        'available_status': 1,
        'photos': 'cha_gio.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Nem Nuong (Grilled Pork Balls)',
        'description': 'Grilled seasoned pork balls served with rice paper and herbs',
        'price': 9.99,
        'category_id': 1,
        'cost_price': 4.50,
        'available_status': 1,
        'photos': 'nem_nuong.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Beverages (category_id: 4)
      {
        'name': 'Ca Phe Sua Da (Iced Coffee)',
        'description': 'Vietnamese iced coffee with condensed milk',
        'price': 4.99,
        'category_id': 4,
        'cost_price': 1.20,
        'available_status': 1,
        'photos': 'ca_phe_sua_da.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Nuoc Mia (Sugar Cane Juice)',
        'description': 'Fresh sugar cane juice served over ice',
        'price': 3.99,
        'category_id': 4,
        'cost_price': 1.00,
        'available_status': 1,
        'photos': 'nuoc_mia.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Tra Da (Iced Tea)',
        'description': 'Refreshing Vietnamese iced tea',
        'price': 2.99,
        'category_id': 4,
        'cost_price': 0.50,
        'available_status': 1,
        'photos': 'tra_da.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Desserts (category_id: 3)
      {
        'name': 'Che Ba Mau (Three-Color Dessert)',
        'description': 'Traditional Vietnamese dessert with mung beans, red beans, and coconut milk',
        'price': 5.99,
        'category_id': 3,
        'cost_price': 2.50,
        'available_status': 1,
        'photos': 'che_ba_mau.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Banh Flan',
        'description': 'Vietnamese caramel custard dessert',
        'price': 4.99,
        'category_id': 3,
        'cost_price': 2.00,
        'available_status': 1,
        'photos': 'banh_flan.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Additional Vietnamese Specials (category_id: 5)
      {
        'name': 'Mi Quang',
        'description': 'Central Vietnamese noodle soup with turmeric broth, shrimp, pork, and quail egg',
        'price': 14.99,
        'category_id': 5,
        'cost_price': 7.80,
        'available_status': 1,
        'photos': 'mi_quang.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bun Rieu Cua',
        'description': 'Crab and tomato noodle soup with fresh herbs and crispy tofu',
        'price': 13.99,
        'category_id': 5,
        'cost_price': 7.20,
        'available_status': 1,
        'photos': 'bun_rieu_cua.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Cao Lau',
        'description': 'Hoi An specialty noodles with char siu pork, herbs, and crispy rice crackers',
        'price': 12.99,
        'category_id': 5,
        'cost_price': 6.50,
        'available_status': 1,
        'photos': 'cao_lau.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Additional Main Course (category_id: 2)
      {
        'name': 'Thit Nuong Cuon La Lot',
        'description': 'Grilled beef wrapped in wild betel leaves served with rice paper and herbs',
        'price': 16.99,
        'category_id': 2,
        'cost_price': 8.50,
        'available_status': 1,
        'photos': 'thit_nuong_cuon_la_lot.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Ca Ri Ga (Chicken Curry)',
        'description': 'Vietnamese coconut curry with chicken, sweet potato, and French bread',
        'price': 15.99,
        'category_id': 2,
        'cost_price': 8.00,
        'available_status': 1,
        'photos': 'ca_ri_ga.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bo Luc Lac (Shaking Beef)',
        'description': 'Cubed beef sautéed with onions, served with watercress and rice',
        'price': 18.99,
        'category_id': 2,
        'cost_price': 9.50,
        'available_status': 1,
        'photos': 'bo_luc_lac.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Com Ga Hainan',
        'description': 'Hainanese chicken rice with poached chicken, fragrant rice, and ginger sauce',
        'price': 14.99,
        'category_id': 2,
        'cost_price': 7.50,
        'available_status': 1,
        'photos': 'com_ga_hainan.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Additional Appetizers (category_id: 1)
      {
        'name': 'Banh Khot',
        'description': 'Mini Vietnamese pancakes with shrimp, served with lettuce and herbs',
        'price': 9.99,
        'category_id': 1,
        'cost_price': 4.50,
        'available_status': 1,
        'photos': 'banh_khot.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Chao Tom',
        'description': 'Grilled shrimp paste on sugar cane with rice paper and herbs',
        'price': 11.99,
        'category_id': 1,
        'cost_price': 6.00,
        'available_status': 1,
        'photos': 'chao_tom.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Banh Cuon',
        'description': 'Steamed rice rolls filled with ground pork and mushrooms',
        'price': 8.99,
        'category_id': 1,
        'cost_price': 4.20,
        'available_status': 1,
        'photos': 'banh_cuon.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bi Cuon',
        'description': 'Fresh spring rolls with shredded pork skin, herbs, and peanut sauce',
        'price': 7.99,
        'category_id': 1,
        'cost_price': 3.80,
        'available_status': 1,
        'photos': 'bi_cuon.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Additional Beverages (category_id: 4)
      {
        'name': 'Sinh To Bo (Avocado Smoothie)',
        'description': 'Creamy avocado smoothie with condensed milk and ice',
        'price': 5.99,
        'category_id': 4,
        'cost_price': 2.00,
        'available_status': 1,
        'photos': 'sinh_to_bo.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Nuoc Chanh (Fresh Limeade)',
        'description': 'Fresh lime juice with soda water and sugar',
        'price': 3.99,
        'category_id': 4,
        'cost_price': 1.20,
        'available_status': 1,
        'photos': 'nuoc_chanh.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Ca Phe Den (Black Coffee)',
        'description': 'Strong Vietnamese drip coffee served hot or iced',
        'price': 3.99,
        'category_id': 4,
        'cost_price': 1.00,
        'available_status': 1,
        'photos': 'ca_phe_den.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Tra Atiso (Artichoke Tea)',
        'description': 'Herbal artichoke tea served hot or cold',
        'price': 3.49,
        'category_id': 4,
        'cost_price': 0.80,
        'available_status': 1,
        'photos': 'tra_atiso.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Additional Desserts (category_id: 3)
      {
        'name': 'Che Dau Do (Red Bean Dessert)',
        'description': 'Sweet red bean soup with coconut milk and tapioca pearls',
        'price': 4.99,
        'category_id': 3,
        'cost_price': 2.20,
        'available_status': 1,
        'photos': 'che_dau_do.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Banh Bo Nuong',
        'description': 'Vietnamese grilled honeycomb cake with coconut',
        'price': 3.99,
        'category_id': 3,
        'cost_price': 1.80,
        'available_status': 1,
        'photos': 'banh_bo_nuong.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Che Bap (Corn Dessert)',
        'description': 'Sweet corn pudding with coconut milk and tapioca',
        'price': 4.49,
        'category_id': 3,
        'cost_price': 2.00,
        'available_status': 1,
        'photos': 'che_bap.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Kem Xoi (Sticky Rice Ice Cream)',
        'description': 'Vietnamese ice cream with sticky rice and mung beans',
        'price': 5.99,
        'category_id': 3,
        'cost_price': 2.80,
        'available_status': 1,
        'photos': 'kem_xoi.jpg',
        'created_at': now,
        'updated_at': now,
      },
    ];

    // Insert sample menu items
    for (final item in sampleItems) {
      await db.insert('menu_items', item);
    }

    print('Created ${sampleItems.length} sample menu items');
  }

  Future<void> createSampleUser() async {
    final db = await _databaseHelper.database;

    // Check if test user already exists
    final existingUsers = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: ['test@gmail.com'],
      limit: 1,
    );

    if (existingUsers.isNotEmpty) {
      print('Test user already exists - updating password');
      // Update existing user's password
      await db.update(
        'users',
        {
          'password_hash': _hashPassword('123456'),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'email = ?',
        whereArgs: ['test@gmail.com'],
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Create test user with password: "123456"
    await db.insert('users', {
      'email': 'test@gmail.com',
      'password_hash': _hashPassword('123456'),
      'full_name': 'Test User',
      'role': 'staff',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    print('Created test user: test@gmail.com / password123');
  }

  String _hashPassword(String password) {
    // Use the same hashing method as AuthService
    final bytes = utf8.encode(password + '_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> addMoreMenuItems() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Additional menu items that can be added anytime
    final additionalItems = [
      // Vietnamese Street Food (category_id: 5)
      {
        'name': 'Banh Xeo',
        'description': 'Vietnamese crepe filled with shrimp, pork, and bean sprouts',
        'price': 10.99,
        'category_id': 5,
        'cost_price': 5.50,
        'available_status': 1,
        'photos': 'banh_xeo.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Hu Tieu Nam Vang',
        'description': 'Cambodian-style clear noodle soup with pork, shrimp, and quail egg',
        'price': 12.99,
        'category_id': 5,
        'cost_price': 6.80,
        'available_status': 1,
        'photos': 'hu_tieu_nam_vang.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bun Bo Nam Bo',
        'description': 'Dry beef vermicelli bowl with herbs, peanuts, and fish sauce dressing',
        'price': 11.99,
        'category_id': 5,
        'cost_price': 6.20,
        'available_status': 1,
        'photos': 'bun_bo_nam_bo.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Grilled Specialties (category_id: 2)
      {
        'name': 'Suon Nuong (Grilled Pork Ribs)',
        'description': 'Marinated grilled pork ribs with honey glaze, served with rice',
        'price': 17.99,
        'category_id': 2,
        'cost_price': 9.00,
        'available_status': 1,
        'photos': 'suon_nuong.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Ca Nuong La Chuoi (Grilled Fish)',
        'description': 'Whole fish grilled in banana leaves with herbs and spices',
        'price': 22.99,
        'category_id': 2,
        'cost_price': 12.00,
        'available_status': 1,
        'photos': 'ca_nuong_la_chuoi.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Tom Nuong (Grilled Shrimp)',
        'description': 'Grilled jumbo shrimp with lemongrass and chili sauce',
        'price': 19.99,
        'category_id': 2,
        'cost_price': 10.50,
        'available_status': 1,
        'photos': 'tom_nuong.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Light Snacks (category_id: 1)
      {
        'name': 'Banh Trang Nuong',
        'description': 'Grilled rice paper with egg, green onion, and dried shrimp',
        'price': 6.99,
        'category_id': 1,
        'cost_price': 3.20,
        'available_status': 1,
        'photos': 'banh_trang_nuong.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Che Cung (Imperial Dessert)',
        'description': 'Royal Vietnamese dessert with lotus seeds and coconut cream',
        'price': 6.99,
        'category_id': 3,
        'cost_price': 3.50,
        'available_status': 1,
        'photos': 'che_cung.jpg',
        'created_at': now,
        'updated_at': now,
      },

      // Refreshing Drinks (category_id: 4)
      {
        'name': 'Nuoc Sam (Pennywort Juice)',
        'description': 'Fresh pennywort juice blended with ice and a touch of salt',
        'price': 4.49,
        'category_id': 4,
        'cost_price': 1.50,
        'available_status': 1,
        'photos': 'nuoc_sam.jpg',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Sinh To Mang Cau (Soursop Smoothie)',
        'description': 'Creamy soursop smoothie with condensed milk',
        'price': 5.99,
        'category_id': 4,
        'cost_price': 2.20,
        'available_status': 1,
        'photos': 'sinh_to_mang_cau.jpg',
        'created_at': now,
        'updated_at': now,
      },
    ];

    // Insert additional menu items
    for (final item in additionalItems) {
      await db.insert('menu_items', item);
    }

    print('Added ${additionalItems.length} new menu items for testing');
  }

  Future<void> initializeSampleData() async {
    await createSampleUser();
    await createSampleMenuItems();
  }
}