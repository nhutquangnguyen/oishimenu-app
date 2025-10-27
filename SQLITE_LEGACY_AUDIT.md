# SQLite Legacy Code Audit Report

**Generated:** October 27, 2025
**Status:** Complete inventory of remaining SQLite services that need Supabase migration

---

## 🎯 **CRITICAL - Active Production Code**

### **A. Active UI Components Using SQLite:**

#### **1. Inventory Management** ⚠️ **HIGH PRIORITY**
- **File:** `lib/features/inventory/providers/inventory_provider.dart`
  - **Issue:** Uses `InventoryService()` directly
  - **Impact:** Inventory management completely on SQLite
  - **Migration:** Create `SupabaseInventoryService`

- **File:** `lib/features/dashboard/presentation/pages/dashboard_page.dart`
  - **Issue:** Uses `OrderService()` directly
  - **Impact:** Dashboard analytics broken without SQLite
  - **Migration:** Create `SupabaseOrderService`

- **File:** `lib/features/dashboard/presentation/widgets/best_sellers.dart`
  - **Issue:** Uses `DatabaseHelper()` directly
  - **Impact:** Best sellers widget relies on SQLite
  - **Migration:** Use Supabase analytics queries

#### **2. Menu Management** ⚠️ **MEDIUM PRIORITY**
- **File:** `lib/features/menu/presentation/pages/scan_menu_page.dart`
  - **Issue:** Uses `MenuService()` directly
  - **Impact:** QR code menu scanning uses old service
  - **Migration:** Update to use `SupabaseMenuService`

#### **3. Authentication** ⚠️ **LOW PRIORITY**
- **File:** `lib/features/auth/services/auth_service.dart`
  - **Issue:** Uses `DatabaseHelper()` for user management
  - **Impact:** Local user authentication vs Supabase Auth
  - **Migration:** Integrate with Supabase Auth system

---

## 🧪 **NON-CRITICAL - Test/Debug/Import Files**

### **B. Test & Debug Files:**
- `lib/test_option_saving.dart` - Testing option group saving
- `lib/debug_database.dart` - Database debugging tools
- `lib/debug_option_groups.dart` - Option group debugging
- `lib/run_import_test.dart` - Import functionality testing
- `lib/test_import_validation.dart` - Import validation testing

### **C. Database Reset/Import Scripts:**
- `lib/reset_database.dart` - Database reset utility
- `lib/reset_db.dart` - Simple database reset
- `lib/reset_and_import.dart` - Reset and import utility

### **D. Legacy Service Classes** 📁 **Full SQLite Services**

#### **Core Services:**
- `lib/services/menu_service.dart` - Menu management (SQLite)
- `lib/services/menu_option_service.dart` - Option groups (SQLite) ✅ **MIGRATED**
- `lib/services/inventory_service.dart` - Inventory management (SQLite)
- `lib/services/order_service.dart` - Order management (SQLite)
- `lib/services/customer_service.dart` - Customer management (SQLite)
- `lib/services/order_source_service.dart` - Order sources (SQLite)

#### **Utility Services:**
- `lib/services/sample_data_service.dart` - Sample data generation (SQLite)
- `lib/services/menu_import_service.dart` - Menu import (uses multiple SQLite services)

---

## 🚀 **Migration Priority Recommendations**

### **🔥 Phase 1 - Critical Business Features (Week 1)**
1. **Inventory System**
   - Create `SupabaseInventoryService`
   - Migrate inventory tables to Supabase
   - Update `inventory_provider.dart`

2. **Dashboard/Analytics**
   - Create `SupabaseOrderService`
   - Migrate orders tables to Supabase
   - Update dashboard components

3. **Best Sellers Widget**
   - Replace direct DatabaseHelper usage
   - Use Supabase analytics queries

### **📊 Phase 2 - Secondary Features (Week 2)**
4. **Menu QR Scanning**
   - Update scan_menu_page.dart to use `SupabaseMenuService`

5. **Authentication System**
   - Integrate with Supabase Auth
   - Migrate user management

### **🧹 Phase 3 - Cleanup (Week 3)**
6. **Legacy Service Files**
   - Archive or delete unused SQLite services
   - Update any remaining references

7. **Test/Debug Files**
   - Update test files to use Supabase
   - Create new debugging tools for Supabase

8. **Import Scripts**
   - Create Supabase-compatible import tools
   - Update data migration utilities

---

## ✅ **Already Successfully Migrated**
- ✅ **Menu Items** → `SupabaseMenuService`
- ✅ **Option Groups** → `SupabaseMenuOptionService`
- ✅ **Menu Categories** → Part of `SupabaseMenuService`
- ✅ **Menu Item ↔ Option Group Linking** → UUID-compatible

---

## 🛠️ **Missing Supabase Services Needed:**

```dart
// Priority order for creation:
class SupabaseInventoryService extends SupabaseService {
  // Inventory management, stocktaking, ingredient tracking
}

class SupabaseOrderService extends SupabaseService {
  // Order management, dashboard analytics, reporting
}

class SupabaseCustomerService extends SupabaseService {
  // Customer management, order history
}

class SupabaseAuthService extends SupabaseService {
  // User authentication, role management
}
```

---

## 📊 **Database Schema Status**

### **Supabase Tables (Already Created):**
- ✅ `menu_items` - Menu item management
- ✅ `menu_categories` - Category management
- ✅ `menu_options` - Individual options
- ✅ `option_groups` - Option group management
- ✅ `option_group_options` - Group ↔ Option linking
- ✅ `menu_item_option_groups` - Item ↔ Group linking
- ✅ `users`, `customers`, `orders`, `order_items` - Ready for migration
- ✅ `ingredients`, `inventory_transactions` - Ready for migration

### **Migration Required:**
- 🔄 **Data Migration:** SQLite → Supabase for existing data
- 🔄 **Service Migration:** Update Flutter services to use Supabase
- 🔄 **Provider Migration:** Update Riverpod providers

---

## 🎯 **Immediate Next Steps:**

1. **Start with Inventory Migration** (Highest business impact)
   - Most critical for restaurant operations
   - Affects ingredient tracking and cost management

2. **Then Orders/Dashboard** (User-facing impact)
   - Essential for daily operations monitoring
   - Customer-facing features

3. **Finally Authentication & Cleanup** (Technical improvement)
   - Better security with Supabase Auth
   - Remove technical debt

---

## 📝 **Implementation Notes:**

- **UUID Compatibility:** All new services must handle UUID primary keys
- **Row Level Security:** Enable RLS policies for all migrated tables
- **Error Handling:** Implement proper error handling for network operations
- **Offline Support:** Consider offline capabilities for critical operations
- **Data Validation:** Ensure data integrity during migration

---

**Last Updated:** October 27, 2025
**Next Review:** After Phase 1 completion