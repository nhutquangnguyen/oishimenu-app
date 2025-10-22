import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal() {
    _initializeDatabaseFactory();
  }

  factory DatabaseHelper() => _instance;

  void _initializeDatabaseFactory() {
    if (kIsWeb) {
      // Initialize database factory for web
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;

    if (kIsWeb) {
      // For web, use a simple in-memory database path
      path = 'oishimenu.db';
    } else {
      // For mobile platforms, use the standard path
      final String databasesPath = await getDatabasesPath();
      path = join(databasesPath, 'oishimenu.db');
    }

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Users table for authentication
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT,
        role TEXT DEFAULT 'staff',
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Menu Categories table
    await db.execute('''
      CREATE TABLE menu_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        display_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Menu Items table
    await db.execute('''
      CREATE TABLE menu_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        category_id INTEGER,
        user_id INTEGER NOT NULL,
        cost_price REAL,
        available_status INTEGER DEFAULT 1,
        availability_schedule TEXT, -- JSON for scheduling availability
        photos TEXT, -- JSON array of photo paths
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES menu_categories (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Menu Item Sizes table
    await db.execute('''
      CREATE TABLE menu_item_sizes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        menu_item_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        is_default INTEGER DEFAULT 0,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        subtotal REAL NOT NULL,
        delivery_fee REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        service_charge REAL DEFAULT 0,
        total REAL NOT NULL,
        order_type TEXT NOT NULL, -- DINE_IN, TAKEAWAY, DELIVERY
        status TEXT NOT NULL, -- PENDING, CONFIRMED, PREPARING, READY, DELIVERED, CANCELLED
        payment_method TEXT NOT NULL, -- cash, card, digital_wallet, bank_transfer
        payment_status TEXT NOT NULL, -- PENDING, PAID, FAILED, REFUNDED
        table_number TEXT,
        platform TEXT DEFAULT 'direct',
        assigned_staff_id INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (assigned_staff_id) REFERENCES users (id)
      )
    ''');

    // Order Items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        menu_item_id INTEGER NOT NULL,
        menu_item_name TEXT NOT NULL,
        base_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        selected_size TEXT,
        subtotal REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');

    // Ingredients table for inventory
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        unit TEXT NOT NULL,
        current_quantity REAL DEFAULT 0,
        minimum_threshold REAL DEFAULT 0,
        cost_per_unit REAL DEFAULT 0,
        supplier TEXT,
        category TEXT,
        expiry_date INTEGER,
        last_restocked INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Recipes table
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        menu_item_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id)
      )
    ''');

    // Inventory Transactions table
    await db.execute('''
      CREATE TABLE inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL, -- PURCHASE, USAGE, WASTE, ADJUSTMENT
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        cost REAL DEFAULT 0,
        reason TEXT,
        related_order_id INTEGER,
        created_by INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id),
        FOREIGN KEY (related_order_id) REFERENCES orders (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Stocktake Sessions table
    await db.execute('''
      CREATE TABLE stocktake_sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL, -- full, partial, cycle
        status TEXT NOT NULL DEFAULT 'draft', -- draft, in_progress, completed, cancelled
        location TEXT,
        total_items INTEGER DEFAULT 0,
        counted_items INTEGER DEFAULT 0,
        variance_count INTEGER DEFAULT 0,
        total_variance_value REAL DEFAULT 0,
        created_at INTEGER NOT NULL,
        started_at INTEGER,
        completed_at INTEGER,
        created_by INTEGER,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Stocktake Items table
    await db.execute('''
      CREATE TABLE stocktake_items (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        ingredient_id INTEGER NOT NULL,
        ingredient_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        expected_quantity REAL NOT NULL,
        counted_quantity REAL,
        variance REAL,
        variance_value REAL,
        notes TEXT,
        counted_at INTEGER,
        counted_by INTEGER,
        FOREIGN KEY (session_id) REFERENCES stocktake_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id),
        FOREIGN KEY (counted_by) REFERENCES users (id)
      )
    ''');

    // Tables for dine-in management
    await db.execute('''
      CREATE TABLE restaurant_tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        seats INTEGER NOT NULL,
        status TEXT DEFAULT 'AVAILABLE', -- AVAILABLE, OCCUPIED, RESERVED, CLEANING, OUT_OF_ORDER
        location TEXT,
        description TEXT,
        current_order_id INTEGER,
        reserved_by TEXT,
        reserved_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (current_order_id) REFERENCES orders (id)
      )
    ''');

    // Feedback table
    await db.execute('''
      CREATE TABLE feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        order_id INTEGER,
        rating INTEGER NOT NULL,
        comment TEXT,
        category TEXT, -- service, product, delivery, other
        status TEXT DEFAULT 'pending', -- pending, published, hidden
        response TEXT,
        responded_by INTEGER,
        responded_at INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (responded_by) REFERENCES users (id)
      )
    ''');

    // Menu Options tables (for customizable items)
    await db.execute('''
      CREATE TABLE menu_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        description TEXT,
        category TEXT,
        is_available INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Option Groups (like Size, Sweetness, Toppings)
    await db.execute('''
      CREATE TABLE option_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        min_selection INTEGER DEFAULT 0,
        max_selection INTEGER DEFAULT 1,
        is_required INTEGER DEFAULT 0,
        display_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Junction table: Option Groups to Menu Options
    await db.execute('''
      CREATE TABLE option_group_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        option_group_id INTEGER NOT NULL,
        option_id INTEGER NOT NULL,
        display_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE,
        FOREIGN KEY (option_id) REFERENCES menu_options (id) ON DELETE CASCADE
      )
    ''');

    // Junction table: Menu Items to Option Groups
    await db.execute('''
      CREATE TABLE menu_item_option_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        menu_item_id INTEGER NOT NULL,
        option_group_id INTEGER NOT NULL,
        is_required INTEGER DEFAULT 0,
        display_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE,
        FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE
      )
    ''');

    // Create default admin user
    await _createDefaultAdmin(db);

    // Create sample categories
    await _createSampleCategories(db);

    // Create sample inventory data
    await _createSampleInventoryData(db);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2 && newVersion >= 2) {
      // Add menu options tables for version 2
      await db.execute('''
        CREATE TABLE menu_options (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL DEFAULT 0,
          description TEXT,
          category TEXT,
          is_available INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE option_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          min_selection INTEGER DEFAULT 0,
          max_selection INTEGER DEFAULT 1,
          is_required INTEGER DEFAULT 0,
          display_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE option_group_options (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          option_group_id INTEGER NOT NULL,
          option_id INTEGER NOT NULL,
          display_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE,
          FOREIGN KEY (option_id) REFERENCES menu_options (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE menu_item_option_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          menu_item_id INTEGER NOT NULL,
          option_group_id INTEGER NOT NULL,
          is_required INTEGER DEFAULT 0,
          display_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE,
          FOREIGN KEY (option_group_id) REFERENCES option_groups (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3 && newVersion >= 3) {
      // Add availability_schedule column for version 3
      await db.execute('''
        ALTER TABLE menu_items ADD COLUMN availability_schedule TEXT
      ''');
    }

    if (oldVersion < 4 && newVersion >= 4) {
      // Add stocktake tables for version 4
      await db.execute('''
        CREATE TABLE stocktake_sessions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL, -- full, partial, cycle
          status TEXT NOT NULL DEFAULT 'draft', -- draft, in_progress, completed, cancelled
          location TEXT,
          total_items INTEGER DEFAULT 0,
          counted_items INTEGER DEFAULT 0,
          variance_count INTEGER DEFAULT 0,
          total_variance_value REAL DEFAULT 0,
          created_at INTEGER NOT NULL,
          started_at INTEGER,
          completed_at INTEGER,
          created_by INTEGER,
          FOREIGN KEY (created_by) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE stocktake_items (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          ingredient_id INTEGER NOT NULL,
          ingredient_name TEXT NOT NULL,
          unit TEXT NOT NULL,
          expected_quantity REAL NOT NULL,
          counted_quantity REAL,
          variance REAL,
          variance_value REAL,
          notes TEXT,
          counted_at INTEGER,
          counted_by INTEGER,
          FOREIGN KEY (session_id) REFERENCES stocktake_sessions (id) ON DELETE CASCADE,
          FOREIGN KEY (ingredient_id) REFERENCES ingredients (id),
          FOREIGN KEY (counted_by) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 5 && newVersion >= 5) {
      // Add user_id column to menu_items for version 5 (multi-user support)
      await db.execute('''
        ALTER TABLE menu_items ADD COLUMN user_id INTEGER
      ''');

      // Get the admin user ID to assign existing menu items
      final adminUsers = await db.query(
        'users',
        where: 'email = ? OR role = ?',
        whereArgs: ['admin@oishimenu.com', 'admin'],
        limit: 1,
      );

      final adminUserId = adminUsers.isNotEmpty ? adminUsers.first['id'] : 1;

      // Update all existing menu items to belong to admin user
      await db.update(
        'menu_items',
        {'user_id': adminUserId},
        where: 'user_id IS NULL',
      );

      // Make user_id column NOT NULL after data migration
      // Note: SQLite doesn't support ALTER COLUMN, so we'll enforce this in the application layer
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Create default admin user with password: "admin123"
    // In production, you should require password change on first login
    await db.insert('users', {
      'email': 'admin@oishimenu.com',
      'password_hash': _hashPassword('admin123'),
      'full_name': 'System Administrator',
      'role': 'admin',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _createSampleCategories(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final categories = [
      {'name': 'Appetizers', 'display_order': 1},
      {'name': 'Main Course', 'display_order': 2},
      {'name': 'Desserts', 'display_order': 3},
      {'name': 'Beverages', 'display_order': 4},
      {'name': 'Vietnamese Specials', 'display_order': 5},
    ];

    for (final category in categories) {
      await db.insert('menu_categories', {
        ...category,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _createSampleInventoryData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if ingredients already exist
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM ingredients');
    if ((count.first['count'] as int) > 0) {
      print('Sample inventory data already exists');
      return;
    }

    final sampleIngredients = [
      {
        'name': 'Thịt bò nạm (Beef Brisket)',
        'description': 'Premium beef brisket for phở bò',
        'category': 'protein',
        'unit': 'kg',
        'current_quantity': 15.5,
        'minimum_threshold': 5.0,
        'cost_per_unit': 280000.0,
        'supplier': 'Chợ Bến Thành',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Rau húng quế (Thai Basil)',
        'description': 'Fresh Thai basil for phở garnish',
        'category': 'vegetables',
        'unit': 'kg',
        'current_quantity': 2.1,
        'minimum_threshold': 1.0,
        'cost_per_unit': 35000.0,
        'supplier': 'Dalat Farm',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Bánh phở tươi (Fresh Rice Noodles)',
        'description': 'Fresh rice noodles for phở',
        'category': 'grains',
        'unit': 'kg',
        'current_quantity': 25.0,
        'minimum_threshold': 10.0,
        'cost_per_unit': 18000.0,
        'supplier': 'Xưởng bánh phở Sài Gòn',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Nước mắm (Fish Sauce)',
        'description': 'Premium Vietnamese fish sauce',
        'category': 'spices',
        'unit': 'lít',
        'current_quantity': 8.5,
        'minimum_threshold': 3.0,
        'cost_per_unit': 65000.0,
        'supplier': 'Phú Quốc Fish Sauce',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Cà phê robusta (Robusta Coffee)',
        'description': 'Premium Vietnamese robusta coffee beans',
        'category': 'beverages',
        'unit': 'kg',
        'current_quantity': 4.8,
        'minimum_threshold': 2.0,
        'cost_per_unit': 120000.0,
        'supplier': 'Buôn Ma Thuột Coffee',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      // Low stock item for testing alerts
      {
        'name': 'Gừng tươi (Fresh Ginger)',
        'description': 'Fresh ginger for broth and marinades',
        'category': 'vegetables',
        'unit': 'kg',
        'current_quantity': 0.3, // Below minimum threshold
        'minimum_threshold': 0.5,
        'cost_per_unit': 45000.0,
        'supplier': 'Chợ Bến Thành',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final ingredient in sampleIngredients) {
      await db.insert('ingredients', ingredient);
    }

    print('Sample inventory data created with ${sampleIngredients.length} ingredients');
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode('${password}_salt'); // Add salt for security
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Helper method to close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Helper method to delete database (for testing)
  Future<void> deleteDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, 'oishimenu.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}