class AppConstants {
  static const String appName = 'OishiMenu';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String baseUrl = 'https://oishimenu.com';
  static const String apiVersion = 'v1';

  // Database Collections
  static const String usersCollection = 'users';
  static const String storesCollection = 'stores';
  static const String menuItemsCollection = 'menu-items';
  static const String menuCategoriesCollection = 'menu-categories';
  static const String ordersCollection = 'orders';
  static const String customersCollection = 'customers';
  static const String employeesCollection = 'employees';
  static const String inventoryCollection = 'inventory';
  static const String ingredientsCollection = 'ingredients';
  static const String recipesCollection = 'recipes';
  static const String stockAlertsCollection = 'stock-alerts';
  static const String stocktakeSessionsCollection = 'stocktake-sessions';
  static const String stocktakeItemsCollection = 'stocktake-items';
  static const String tablesCollection = 'tables';
  static const String feedbackCollection = 'feedback';
  static const String optionGroupsCollection = 'option-groups';
  static const String analyticsCollection = 'analytics-cache';

  // Order Status
  static const String orderStatusPending = 'PENDING';
  static const String orderStatusConfirmed = 'CONFIRMED';
  static const String orderStatusPreparing = 'PREPARING';
  static const String orderStatusReady = 'READY';
  static const String orderStatusOutForDelivery = 'OUT_FOR_DELIVERY';
  static const String orderStatusDelivered = 'DELIVERED';
  static const String orderStatusCancelled = 'CANCELLED';
  static const String orderStatusFailed = 'FAILED';

  // Order Types
  static const String orderTypeDineIn = 'DINE_IN';
  static const String orderTypeTakeaway = 'TAKEAWAY';
  static const String orderTypeDelivery = 'DELIVERY';

  // Table Status
  static const String tableStatusAvailable = 'AVAILABLE';
  static const String tableStatusOccupied = 'OCCUPIED';
  static const String tableStatusReserved = 'RESERVED';
  static const String tableStatusCleaning = 'CLEANING';
  static const String tableStatusOutOfOrder = 'OUT_OF_ORDER';

  // Employee Roles
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleStaff = 'staff';

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentDigitalWallet = 'digital_wallet';
  static const String paymentBankTransfer = 'bank_transfer';

  // Platforms
  static const String platformGrab = 'grab';
  static const String platformShopeeFood = 'shopee_food';
  static const String platformOishiDelivery = 'oishi_delivery';
  static const String platformGomaFood = 'goma_food';
  static const String platformDirect = 'direct';

  // App Limits
  static const int maxPhotosPerMenuItem = 4;
  static const int ordersPerPage = 20;
  static const int itemsPerPage = 10;

  // Cache Keys
  static const String cacheKeyUser = 'user_data';
  static const String cacheKeyStore = 'store_data';
  static const String cacheKeyMenu = 'menu_data';
  static const String cacheKeySettings = 'app_settings';
}