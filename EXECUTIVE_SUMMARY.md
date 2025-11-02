# Executive Summary: Database & Order Management Architecture

## System Overview

OishiMenu is transitioning from **SQLite** (local mobile database) to **Supabase** (PostgreSQL cloud backend) while maintaining backward compatibility through a **hybrid mode**. The architecture combines real-time order synchronization with a robust polling fallback mechanism.

---

## Architecture Layers

### 1. Data Layer (Supabase PostgreSQL)
- **15 tables** covering orders, customers, menu items, inventory, financial tracking
- **UUID primary keys** for scalability and global distribution
- **Version-tracked sync** via sync_metadata table
- **Automatic triggers** that increment version on data changes
- **JSONB support** for flexible order options storage

### 2. Service Layer (Dart Classes)
- **SupabaseOrderService**: Core order operations (CRUD, filtering, validation)
- **SupabaseCustomerService**: Customer management with search
- **SupabaseMenuService**: Menu items and availability
- **SupabaseInventoryService**: Ingredient and recipe tracking
- **Other Services**: Options, sources, import/export, auth

### 3. Sync Layer (Hybrid Polling)
- **HybridSyncManager**: Singleton that orchestrates synchronization
- **5-second polling** (configurable per app state)
- **Version-based detection**: Only syncs when data actually changes
- **Event-driven updates**: SyncEvent stream notifies UI of changes
- **Persistent state**: Last sync timestamp saved to SharedPreferences

### 4. Presentation Layer (Flutter)
- Listens to SyncEvent stream
- Optimistic UI updates (immediate local feedback)
- Confirms with server on next sync cycle
- Order pages, checkout flows, order status tracking

---

## Critical Data Flows

### Creating an Order
```
User Input
  ↓
Order with OrderItems created locally (optimistic UI update)
  ↓
SyncEvent emitted: orderCreated(isOptimistic=true)
  ↓
SupabaseOrderService.createOrder():
  - Validates payment method (DELIVERED orders require it)
  - Inserts order (Supabase generates UUID)
  - Inserts each order_item with selected_options as JSONB
  - Returns new order ID
  ↓
SyncEvent emitted: orderCreated(isOptimistic=false)
  ↓
UI confirms and persists
```

### Retrieving Orders
```
HybridSyncManager polling cycle (every 5 seconds)
  ↓
Query sync_metadata table for version
  ↓
If version changed:
  - Call SupabaseOrderService.getOrders()
  - Single optimized query with JOIN to orders AND order_items
  - Customer data nested in response
  - order_items array includes all line items
  - selected_options JSONB parsed to SelectedOption objects
  ↓
Emit SyncEvent.dataUpdated
  ↓
UI listeners update their state
```

### Updating Order Items
```
Item checkbox clicked
  ↓
SyncEvent.itemCompletionToggled(isOptimistic=true) emitted
  ↓
UI updates immediately with optimistic state
  ↓
Next polling cycle:
  - RPC function rpc_update_order_item_completion() called
  - Atomic update of order_item is_completed field
  - order's updated_at automatically incremented by trigger
  ↓
SyncEvent.itemCompletionToggled(isOptimistic=false) emitted
  ↓
Confirmed state persisted
```

---

## Order Item Storage Details

### In the Database (order_items table)
```sql
id (UUID)
order_id (FK to orders)
menu_item_id (FK to menu_items)
menu_item_name (denormalized text)
base_price (DECIMAL 10,2)
quantity (INTEGER)
selected_size (TEXT)
subtotal (DECIMAL 10,2)
notes (TEXT)
selected_options (JSONB)  ← Menu option selections stored here
```

### In the Dart Model
```dart
class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final double basePrice;
  final int quantity;
  final List<SelectedOption> selectedOptions;
  final String? selectedSize;
  final double subtotal;
  final String? notes;
}

class SelectedOption {
  final String optionGroupId;
  final String optionGroupName;
  final String optionId;
  final String optionName;
  final double price;
}
```

### Retrieval
```dart
getOrders() returns List<Order>
  where each Order has:
    items: List<OrderItem>
      where each OrderItem has:
        selectedOptions: List<SelectedOption>
          parsed from JSONB
```

---

## Sync Strategy: Why This Design?

### Polling-Based (Not WebSocket)
**Pros:**
- Works over all network types
- Survives temporary disconnections naturally
- No persistent connection overhead
- Fallback-proof (always catches updates)

**Cons:**
- ~5 second latency
- Constant light polling traffic

**Trade-off:** Simple, reliable sync for restaurant operations (not real-time stock trading)

### Version Tracking
**Why it matters:**
- Prevents re-fetching unchanged data
- Database trigger automatically increments on any change
- Reduces bandwidth and battery drain
- Single authoritative source (server version always wins)

### Optimistic Updates
**Why it matters:**
- Instant UI feedback (feels responsive)
- Works during network hiccups
- Confirmed on next polling cycle
- Fallback: server state always wins on conflict

---

## Key Differentiators from SQLite

| Feature | SQLite | Supabase |
|---------|--------|----------|
| **Scalability** | Device storage only | Cloud unlimited |
| **Sync** | Manual, fragile | Automatic, reliable |
| **Sharing** | Single device | Multi-device capable |
| **Backup** | Manual/risky | Automatic daily |
| **Query Performance** | Potential N+1 | Optimized JOINs |
| **JSON Support** | Text parsing | Native JSONB |
| **Transactions** | SQLite native | RPC functions |
| **ID Type** | INT auto-increment | UUID v4 |

---

## Important Validation Rules

### Payment Method (Critical Business Rule)
Orders transitioning to **DELIVERED** status require:
```
payment_method NOT IN (null, '', 'none')
```

This is enforced in:
- `createOrder()` - If order.status == DELIVERED
- `updateOrder()` - If new status == DELIVERED
- `updateOrderStatus()` - When setting status = DELIVERED

**Rationale:** Ensures payment info captured before order complete

---

## File Locations Summary

```
DATABASE SCHEMAS:
  supabase_schema.sql → Main Supabase PostgreSQL schema (15 tables)
  database/hybrid_sync_schema.sql → Sync metadata, triggers, RPCs
  lib/services/database_helper.dart → Legacy SQLite schema

SERVICES:
  lib/services/supabase_service.dart → ALL Supabase service classes
  lib/services/legacy_sqlite/order_service.dart → SQLite version

MODELS:
  lib/models/order.dart → Order, OrderItem, SelectedOption, Customer

SYNC:
  lib/core/sync/hybrid_sync_manager.dart → Main sync orchestrator
  lib/core/sync/sync_events.dart → Event type definitions

PROVIDERS & CONFIG:
  lib/core/providers/supabase_providers.dart → Riverpod providers
  lib/core/config/supabase_config.dart → Supabase URL & API key

DOCUMENTATION:
  SUPABASE_SETUP.md → Migration guide
  DATABASE_AND_SERVICES_OVERVIEW.md → Detailed architecture
  QUICK_REFERENCE.md → Fast lookup guide
```

---

## Current Status

**Migration Phase**: HYBRID MODE
- Both SQLite and Supabase services coexist
- Default: Supabase enabled (`useSupabaseProvider = true`)
- Can switch at runtime via provider

**Completed**:
- Full schema design and implementation
- Service layer for all modules
- Hybrid sync manager with polling
- Event-driven architecture
- Basic RLS policies

**In Progress**:
- Data migration from SQLite to cloud
- Connectivity monitoring
- Real-time WebSocket (optional future enhancement)
- Advanced RLS policies

**Known Limitations**:
- 5-second sync latency (acceptable for restaurant use)
- Requires customer record before order (FK constraint)
- RLS policies need refinement for multi-tenant support

---

## Success Metrics

After full migration, you'll have:
- ✅ Real-time order synchronization across staff devices
- ✅ Automatic cloud backups every night
- ✅ Scalability for thousands of orders
- ✅ Historical data preserved (append-only patterns)
- ✅ Multi-location support (future)
- ✅ API auto-generated for external integrations

---

## Getting Started (Quick Path)

1. **Verify Supabase Setup**
   - Run `supabase_schema.sql` in your Supabase SQL editor
   - Run `database/hybrid_sync_schema.sql` for sync tables
   - Check sync_metadata table exists

2. **Configure App**
   - Update supabase_config.dart with your URL and API key
   - Verify `useSupabaseProvider = true`

3. **Test Flow**
   - Create an order → Check order_items table
   - Wait 5 seconds → Sync should trigger
   - Watch for SyncEvent in logs

4. **Monitor**
   - Check Supabase dashboard for table content
   - Monitor sync_metadata version increments
   - Verify performance metrics in Reports tab

---

**Document Location**: 
`/Users/macbook/Projects/github/P/oishimenu-app-flutter/`

**Related Docs**:
- DATABASE_AND_SERVICES_OVERVIEW.md (comprehensive)
- QUICK_REFERENCE.md (quick lookup)
- SUPABASE_SETUP.md (original setup guide)

