# OishiMenu Database & Order Services Architecture Overview

## Current System Status
The application is in a **hybrid migration phase**, transitioning from **SQLite (legacy)** to **Supabase (cloud)**.

---

## 1. DATABASE SCHEMA STRUCTURE

### 1.1 Supabase Cloud Database (PostgreSQL)
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/supabase_schema.sql`

**Main Tables:**

#### Core Order Management
- **orders** (UUID primary key)
  - order_number (TEXT UNIQUE)
  - customer_id (FK to customers)
  - Status: PENDING, CONFIRMED, PREPARING, READY, DELIVERED, CANCELLED
  - OrderType: DINE_IN, TAKEAWAY, DELIVERY
  - PaymentMethod: cash, card, digital_wallet, bank_transfer
  - PaymentStatus: PENDING, PAID, FAILED, REFUNDED
  - Financial fields: subtotal, delivery_fee, discount, tax, service_charge, total
  - Metadata: table_number, platform (default: 'direct'), assigned_staff_id, notes
  - Timestamps: created_at, updated_at

- **order_items** (UUID primary key) - CRITICAL FOR ITEM STORAGE
  - order_id (FK to orders, ON DELETE CASCADE)
  - menu_item_id (FK to menu_items)
  - menu_item_name (denormalized for historical records)
  - base_price (DECIMAL(10,2))
  - quantity (INTEGER)
  - selected_size (TEXT)
  - subtotal (DECIMAL(10,2))
  - notes (TEXT)
  - selected_options (JSONB) - Stores menu options as JSON

#### Menu Management
- **menu_items** (UUID primary key)
  - name, description, price, cost_price
  - category_id (FK to menu_categories)
  - user_id (FK to users)
  - available_status (BOOLEAN)
  - availability_schedule (JSONB)
  - photos (TEXT array)
  - display_order (INTEGER)

- **menu_categories** (UUID primary key)
  - name, display_order, is_active

- **menu_options** (UUID primary key)
  - name, price, description, category
  - is_available (BOOLEAN)

- **option_groups** (UUID primary key)
  - name, description
  - min_selection, max_selection
  - is_required, display_order
  - is_active

- **option_group_options** (junction table)
  - Relationship between option_groups and menu_options

- **menu_item_option_groups** (junction table)
  - Relationship between menu_items and option_groups

#### Customer Management
- **customers** (UUID primary key)
  - name, phone, email, address
  - Timestamps: created_at, updated_at

- **users** (UUID primary key)
  - email (UNIQUE), full_name
  - role: admin, manager, staff
  - is_active (BOOLEAN)

#### Inventory Management
- **ingredients** (UUID primary key)
  - name, description, unit
  - current_quantity, minimum_threshold
  - cost_per_unit, supplier, category
  - expiry_date, last_restocked
  - is_active

- **recipes** (UUID primary key)
  - menu_item_id (FK)
  - ingredient_id (FK)
  - quantity, unit, notes

- **inventory_transactions** (UUID primary key)
  - ingredient_id (FK)
  - transaction_type: PURCHASE, USAGE, WASTE, ADJUSTMENT
  - quantity, unit, cost, reason
  - related_order_id (FK)
  - created_by (FK to users)

#### Restaurant Management
- **restaurant_tables** (UUID primary key)
  - name, seats, status (AVAILABLE, OCCUPIED, RESERVED, CLEANING, OUT_OF_ORDER)
  - location, description, current_order_id
  - reserved_by, reserved_at

- **order_sources** (UUID primary key) - IMPORTANT FOR COMMISSION TRACKING
  - name, icon_path, type (dine_in, takeaway, delivery)
  - commission_rate (DECIMAL)
  - requires_commission_input (BOOLEAN)
  - commission_input_type: before_fee, after_fee
  - is_active

#### Financial Management
- **finance_entries** (UUID primary key)
  - type: income, expense
  - amount, description, category
  - user_id (FK), created_at

#### Feedback Management
- **feedback** (UUID primary key)
  - customer_id (FK)
  - order_id (FK)
  - rating (1-5)
  - comment, category
  - status: pending, published, hidden

#### Stocktake Management
- **stocktake_sessions** (UUID primary key)
  - name, description, type (full, partial, cycle)
  - status: draft, in_progress, completed, cancelled
  - Counts: total_items, counted_items, variance_count
  - total_variance_value
  - Timestamps: created_at, started_at, completed_at

- **stocktake_items** (UUID primary key)
  - session_id (FK)
  - ingredient_id (FK)
  - expected_quantity, counted_quantity, variance
  - variance_value, notes, counted_at, counted_by

### 1.2 Hybrid Sync Schema Changes
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/database/hybrid_sync_schema.sql`

**Sync-Specific Tables:**

- **sync_metadata** (CRITICAL FOR SYNC SYSTEM)
  - key (TEXT PRIMARY KEY) - defaults to 'orders_last_updated'
  - last_updated (TIMESTAMPTZ)
  - version (INTEGER)
  - created_at (TIMESTAMPTZ)

**Database Functions:**

- `update_orders_sync_timestamp()` - Trigger function that increments version when orders/items change
- `rpc_get_sync_metadata(sync_key TEXT)` - RPC to fetch sync metadata
- `rpc_update_order_item_completion()` - Atomic RPC for item completion updates
- `rpc_batch_update_items()` - Batch operations for multiple items

**Triggers:**

- `trigger_orders_sync` - On INSERT/UPDATE/DELETE on orders table
- `trigger_order_items_sync` - On INSERT/UPDATE/DELETE on order_items table

**Indexes:**

- `idx_sync_metadata_key` - For fast metadata lookups
- `idx_orders_updated_at` - For sync queries
- `idx_order_items_completed` - For tracking completion status

### 1.3 Legacy SQLite Database (Local/Deprecated)
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/services/database_helper.dart`

Uses same schema as Supabase but with:
- INTEGER primary keys (auto-increment) instead of UUIDs
- Timestamps stored as INTEGER (millisecondsSinceEpoch)
- Tables: users, menu_categories, menu_items, menu_item_sizes, customers, orders, order_items, order_sources, ingredients, recipes, inventory_transactions, restaurant_tables, feedback

Database version: 8 (with upgrade path)

---

## 2. ORDER SERVICES IMPLEMENTATION

### 2.1 SupabaseOrderService (PRIMARY - Cloud)
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/services/supabase_service.dart` (lines 2112+)

**Key Methods:**

#### Read Operations
- `getOrders(status?, startDate?, endDate?, limit?, customerId?)` 
  - **OPTIMIZED**: Single query with JOIN to fetch orders + items
  - Returns List<Order> with nested order_items
  - Filters by status, date range, customer
  - Orders by created_at DESC

- `getOrderById(String id)`
  - Fetches single order with customer nested data
  - Loads order_items separately (could be combined)

- `getOrderItems(String orderId)`
  - Fetches all OrderItem objects for an order

#### Write Operations
- `createOrder(Order order)`
  - Validates payment method for delivered orders
  - Inserts order (Supabase generates UUID)
  - Inserts related order_items
  - Returns generated order ID
  - Converts timestamps to ISO8601 strings

- `updateOrder(Order order)`
  - Updates order except id and created_at
  - Payment method validation for delivered status
  - Updates updated_at timestamp

- `updateOrderStatus(String orderId, OrderStatus status)`
  - Updates only status field
  - Validates payment method requirement
  - Updates updated_at

#### Validation
- `_requiresPaymentMethod(OrderStatus)` - True for DELIVERED status
- `_validatePaymentMethodForCompletion(orderId, targetStatus)` - Ensures payment_method is not null/empty/'none'
- `_validatePaymentMethodForOrder(order)` - Checks order's payment method

#### ID Conversion
- `_convertToSupabaseId(String id)` - Handles both UUID and integer IDs for backward compatibility

### 2.2 Legacy OrderService (SQLite)
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/services/legacy_sqlite/order_service.dart`

**Key Methods:**

- `getOrders(status?, startDate?, endDate?, limit?)` - Query builder with WHERE clauses
- `getOrderById(String id)` - Single order fetch
- `getOrderItems(String orderId)` - Separate query for items
- `createOrder(Order order)` - Transaction-based insertion
- Transaction support for atomic operations

**Difference from Supabase:**
- Separate queries (N+1 problem potential)
- Manual transaction management
- Integer ID handling
- Millisecond timestamp storage

### 2.3 SupabaseCustomerService
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/services/supabase_service.dart` (lines 732+)

- `getCustomers()` - All customers
- `getCustomerById(String id)` - Single customer
- `searchCustomers(String query)` - Search by name/phone
- `createCustomer(Customer customer)` - Insert new
- `updateCustomer(Customer customer)` - Update existing
- `deleteCustomer(String id)` - Delete customer

### 2.4 Other Supabase Services

**SupabaseInventoryService** (lines 1620+)
- Manage ingredients, recipes, inventory transactions
- Stocktake sessions and items
- Stock management and variance tracking

**SupabaseMenuService** (lines 21+)
- Menu items with categories
- Menu options and option groups
- Availability management

**SupabaseMenuOptionService**
- Option groups configuration
- Option management
- Option-group relationships

**SupabaseOrderSourceService**
- Order source management (dine_in, takeaway, delivery)
- Commission rate management
- Platform tracking

**SupabaseImportExportService**
- Bulk import/export operations
- Data migration support

---

## 3. ORDER ITEM STORAGE & RETRIEVAL

### 3.1 Data Model
File: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/models/order.dart`

**OrderItem Class:**
```dart
class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final double basePrice;
  final int quantity;
  final List<SelectedOption> selectedOptions; // Menu option selections
  final String? selectedSize;
  final double subtotal;
  final String? notes;
}
```

**SelectedOption Class:**
```dart
class SelectedOption {
  final String optionGroupId;
  final String optionGroupName;
  final String optionId;
  final String optionName;
  final double price;
}
```

### 3.2 Storage Method
- **Database**: order_items table
- **Structure**: Flat table with JSONB column for selected_options
- **Relationship**: order_id (FK to orders)
- **Fields Stored**:
  - menu_item_id, menu_item_name (denormalized)
  - base_price, quantity, selected_size
  - subtotal, notes
  - selected_options (JSON structure with optionGroupId, optionId, etc.)

### 3.3 Retrieval Flow
1. `getOrders()` - Single optimized query with JOIN fetches all items
2. Each order_item row becomes an OrderItem object
3. selected_options JSONB parsed to SelectedOption list
4. Order object with `.items` list created

---

## 4. SYNC MECHANISMS

### 4.1 Hybrid Sync Manager
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/sync/hybrid_sync_manager.dart`

**Architecture:**
- Singleton pattern
- Combines instant local updates + periodic server polling
- Emits SyncEvent stream for UI listeners

**Configuration:**
```
- Default poll interval: 5 seconds (foreground)
- Reconnect poll interval: 3 seconds (after disconnect)
- Background poll interval: 30 seconds (app in background)
```

**Key Features:**
1. **Optimistic Updates**: UI updates immediately while syncing in background
2. **Version Tracking**: sync_metadata table tracks last_updated and version
3. **Event Streaming**: SyncEvent emitted for dataUpdated, orderCreated, itemCompletionToggled, etc.
4. **Persistent Storage**: Last sync state saved to SharedPreferences
5. **Polling Strategy**: Adaptive based on app state (foreground/background) and connectivity

**State Management:**
- `_isPolling` - Polling active flag
- `_isSyncing` - Sync in progress flag
- `_lastKnownUpdate` - DateTime of last sync
- `_lastKnownVersion` - Version number from sync_metadata

**Methods:**
- `initialize()` - Must be called before use
- `startPolling()` / `stopPolling()` - Control polling
- `_checkForUpdates()` - Polls server for changes
- `_loadSyncState()` / `_saveSyncState()` - Persistent sync state
- `_scheduleNextPoll()` - Adaptive polling scheduler

### 4.2 Sync Event System
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/sync/sync_events.dart`

**SyncEvent Types:**
- syncStarted, syncCompleted, dataUpdated
- orderCreated, orderUpdated, orderDeleted, orderStatusUpdated
- itemCompletionToggled, itemCompletionConfirmed
- itemQuantityUpdated
- error, networkError, syncConflict
- connectionRestored, connectionLost

**SyncEvent Structure:**
```dart
class SyncEvent {
  final SyncEventType type;
  final dynamic data; // Order, OrderItem, etc.
  final dynamic previousData; // For conflict detection
  final String message;
  final DateTime timestamp;
  final String? errorCode;
  final Map<String, dynamic>? metadata;
}
```

**SyncMetadata Class:**
```dart
class SyncMetadata {
  final DateTime lastUpdated;
  final int version;
  final String key; // 'orders_last_updated'
}
```

**BatchOperation Class:**
For efficient batch syncing:
- type: 'item_completion' or 'order_status'
- orderId, itemId (optional)
- data: operation-specific payload
- timestamp

### 4.3 Sync Flow
1. App initializes HybridSyncManager
2. Loads last known sync state from SharedPreferences
3. Starts polling with adaptive intervals
4. On each poll:
   - Query sync_metadata to check version
   - If version changed, fetch updated orders
   - Emit SyncEvent for changes
   - Update local state via stream listeners
5. Optimistic updates:
   - UI updates immediately with optimistic state
   - Background sync confirms with server
   - Emit confirmation event when complete

---

## 5. SERVICE PROVIDERS & CONFIGURATION

### 5.1 Riverpod Providers
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/providers/supabase_providers.dart`

**Service Providers:**
```dart
final supabaseOrderServiceProvider = Provider<SupabaseOrderService>
final supabaseCustomerServiceProvider = Provider<SupabaseCustomerService>
final supabaseMenuServiceProvider = Provider<SupabaseMenuService>
final supabaseMenuOptionServiceProvider = Provider<SupabaseMenuOptionService>
final supabaseOrderSourceServiceProvider = Provider<SupabaseOrderSourceService>
final supabaseInventoryServiceProvider = Provider<SupabaseInventoryService>
final supabaseImportExportServiceProvider = Provider<SupabaseImportExportService>
final supabaseAuthServiceProvider = Provider<AuthService> (SupabaseAuthServiceAdapter)
```

**Dynamic Switching:**
```dart
final useSupabaseProvider = StateProvider<bool>((ref) => true)
final dynamicOrderServiceProvider = Provider<dynamic>((ref) => ...)
final dynamicCustomerServiceProvider = Provider<dynamic>((ref) => ...)
final dynamicMenuServiceProvider = Provider<dynamic>((ref) => ...)
```

### 5.2 Supabase Configuration
Location: `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/config/supabase_config.dart`

Contains:
- Project URL
- Anonymous public key
- Client initialization
- Error handling

---

## 6. AUTHENTICATION INTEGRATION

**SupabaseAuthServiceAdapter** (in supabase_providers.dart)
- Bridges Supabase auth to existing AuthService interface
- Converts Supabase User to AppUser model
- Listens to Supabase onAuthStateChange stream
- Supports: Email/Password, Google Sign-In
- Role-based access (admin, manager, staff)

---

## 7. KEY DIFFERENCES: SQLite vs Supabase

| Aspect | SQLite | Supabase |
|--------|--------|----------|
| **ID Type** | INTEGER (auto-increment) | UUID (uuid_generate_v4()) |
| **Timestamps** | INTEGER (ms since epoch) | TIMESTAMPTZ (ISO8601 strings) |
| **Sync** | Manual, transaction-based | Automatic, event-based with version tracking |
| **Query Performance** | N+1 issues possible | Optimized JOINs, single queries |
| **Transactions** | Native SQLite transactions | RPC functions for atomicity |
| **Storage** | Local device | Cloud PostgreSQL |
| **Real-time** | Poll-based only | WebSocket + polling hybrid |
| **Scalability** | Device storage limited | Cloud-scalable |
| **Network | Offline-first | Online-first with sync |
| **JSON Fields** | TEXT (custom parsing) | JSONB (native support) |

---

## 8. MIGRATION STATUS

**Current State: HYBRID MODE**
- Both SQLite and Supabase services exist
- App can switch via `useSupabaseProvider`
- Default: Supabase enabled (`useSupabaseProvider = true`)

**Completed:**
- Supabase schema design and setup
- Service implementations for all modules
- Hybrid sync manager
- Event-based updates
- RLS policies (basic)

**TODO / In Progress:**
- Complete migration of existing SQLite data
- Connectivity monitoring integration
- Advanced RLS policies refinement
- Real-time WebSocket implementation
- Edge functions for complex operations

---

## 9. FILE STRUCTURE SUMMARY

```
lib/
├── services/
│   ├── supabase_service.dart (ALL Supabase services)
│   ├── database_helper.dart (SQLite local DB)
│   ├── supabase_import_export_service.dart
│   └── legacy_sqlite/
│       ├── order_service.dart
│       ├── order_source_service.dart
│       ├── menu_service.dart
│       ├── customer_service.dart
│       └── ...
├── models/
│   ├── order.dart (Order, OrderItem, SelectedOption, Customer, DeliveryInfo)
│   ├── menu_item.dart
│   ├── menu_options.dart
│   ├── order_source.dart
│   ├── inventory_models.dart
│   └── user.dart
├── core/
│   ├── providers/
│   │   └── supabase_providers.dart (Riverpod providers)
│   ├── config/
│   │   └── supabase_config.dart
│   └── sync/
│       ├── hybrid_sync_manager.dart (Main sync orchestrator)
│       └── sync_events.dart (Event definitions)
└── features/
    ├── orders/presentation/pages/orders_page.dart
    ├── checkout/presentation/pages/checkout_page.dart
    └── ...

Root:
├── supabase_schema.sql (Cloud schema)
├── database/hybrid_sync_schema.sql (Sync changes)
└── SUPABASE_SETUP.md (Migration guide)
```

---

## 10. CRITICAL INSIGHTS

1. **Order Items Storage**: Stored in separate `order_items` table, joined with orders for retrieval
2. **Menu Options**: Stored as JSONB in selected_options field of order_items
3. **Sync Strategy**: Polled-based (5s intervals) with version tracking via sync_metadata
4. **ID Handling**: Dual compatibility for UUID and integer IDs via `_convertToSupabaseId()`
5. **Performance Optimization**: Single optimized query with JOINs in `getOrders()` eliminates N+1 queries
6. **Atomic Operations**: RPC functions for guaranteed data consistency
7. **Event Stream**: Real-time UI updates via SyncEvent stream listeners
8. **Transaction Support**: Limited in Supabase; use RPC functions for multi-step operations

