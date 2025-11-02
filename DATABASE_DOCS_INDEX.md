# Database & Order Services Documentation Index

## Start Here

If you're just learning about the system, start with these in order:

1. **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** - 10 min read
   - High-level architecture overview
   - System layers and data flows
   - Current status and limitations
   - Best for: Understanding the big picture

2. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - 5 min lookup
   - Key files, tables, services at a glance
   - Polling strategy and ID handling
   - Troubleshooting checklist
   - Best for: Quick lookups while coding

3. **[DATABASE_AND_SERVICES_OVERVIEW.md](DATABASE_AND_SERVICES_OVERVIEW.md)** - 30 min deep dive
   - Complete schema documentation (15 tables)
   - Service layer details with code line numbers
   - Order item storage and retrieval specifics
   - Sync mechanisms and event system
   - File structure and critical insights
   - Best for: Understanding implementation details

## Reference by Task

### I need to... understand order item storage
- See section 3 in DATABASE_AND_SERVICES_OVERVIEW.md
- Check OrderItem class in `/lib/models/order.dart`
- Query: `order_items` table with `selected_options` JSONB field

### I need to... add a new feature that syncs with server
- Read sync system section in EXECUTIVE_SUMMARY.md
- Implement a SyncEvent in `/lib/core/sync/sync_events.dart`
- Add listener to HybridSyncManager stream
- See examples in current code

### I need to... trace how orders are retrieved
- Flow diagram in EXECUTIVE_SUMMARY.md section "Retrieving Orders"
- Code: `SupabaseOrderService.getOrders()` in supabase_service.dart (line 2117)
- Uses optimized single JOIN query (no N+1 problems)

### I need to... understand payment validation
- Search for "Payment Validation" in EXECUTIVE_SUMMARY.md
- Code: `_validatePaymentMethodForOrder()` in supabase_service.dart
- Rule: DELIVERED orders require payment_method not null/empty/'none'

### I need to... debug sync issues
- Troubleshooting section in QUICK_REFERENCE.md
- Check sync_metadata table exists in Supabase
- Monitor SyncEvent stream in app logs
- Verify triggers on orders and order_items tables

### I need to... migrate existing data from SQLite
- See SUPABASE_SETUP.md section "Step 8: Data Migration"
- Use SupabaseImportExportService for bulk operations
- Gradual migration via `useSupabaseProvider` toggle

## Documentation Overview

```
EXECUTIVE_SUMMARY.md (8.7 KB)
├─ System overview
├─ Architecture layers
├─ Critical data flows (order creation, retrieval, updates)
├─ Order item storage details
├─ Sync strategy explanation
├─ Key differentiators from SQLite
├─ Payment validation rules
└─ Getting started quick path

QUICK_REFERENCE.md (4.4 KB)
├─ Key files at a glance
├─ Order item storage summary
├─ Sync flow diagram
├─ Important tables (5 highlighted)
├─ Available services (7 listed)
├─ Mode switching and ID handling
├─ Polling strategy
├─ Performance notes
└─ Troubleshooting checklist

DATABASE_AND_SERVICES_OVERVIEW.md (18 KB)
├─ 1. Database Schema Structure
│  ├─ 1.1 Supabase Cloud Database (15 tables with fields)
│  ├─ 1.2 Hybrid Sync Schema Changes (functions, triggers, indexes)
│  └─ 1.3 Legacy SQLite Database
├─ 2. Order Services Implementation
│  ├─ 2.1 SupabaseOrderService (CRUD, validation)
│  ├─ 2.2 Legacy OrderService
│  ├─ 2.3 SupabaseCustomerService
│  └─ 2.4 Other Services
├─ 3. Order Item Storage & Retrieval
│  ├─ 3.1 Data Model (OrderItem, SelectedOption classes)
│  ├─ 3.2 Storage Method (order_items table structure)
│  └─ 3.3 Retrieval Flow (getOrders() process)
├─ 4. Sync Mechanisms
│  ├─ 4.1 Hybrid Sync Manager (singleton, polling intervals)
│  ├─ 4.2 Sync Event System (event types, structures)
│  └─ 4.3 Sync Flow (step-by-step)
├─ 5. Service Providers & Configuration
├─ 6. Authentication Integration
├─ 7. Key Differences: SQLite vs Supabase
├─ 8. Migration Status
├─ 9. File Structure Summary
└─ 10. Critical Insights

SUPABASE_SETUP.md (6.6 KB) [Original setup guide]
├─ Prerequisites
├─ Create Supabase project
├─ Setup database schema
├─ Configure API keys
├─ Install dependencies
├─ Replace services
├─ Authentication setup
├─ Data migration
├─ Testing guide
├─ Benefits overview
└─ Troubleshooting
```

## Key Files Referenced

### Database Schemas
- `/supabase_schema.sql` - Main Supabase PostgreSQL schema
- `/database/hybrid_sync_schema.sql` - Sync metadata tables and triggers
- `/lib/services/database_helper.dart` - SQLite local database

### Core Services
- `/lib/services/supabase_service.dart` - All Supabase service classes
- `/lib/services/legacy_sqlite/order_service.dart` - SQLite implementation
- `/lib/services/supabase_import_export_service.dart` - Bulk operations

### Data Models
- `/lib/models/order.dart` - Order, OrderItem, SelectedOption, Customer
- `/lib/models/menu_item.dart` - MenuItem
- `/lib/models/menu_options.dart` - MenuOption models

### Sync System
- `/lib/core/sync/hybrid_sync_manager.dart` - Main sync orchestrator
- `/lib/core/sync/sync_events.dart` - Event definitions and metadata

### Integration
- `/lib/core/providers/supabase_providers.dart` - Riverpod providers
- `/lib/core/config/supabase_config.dart` - Configuration

## Architecture Diagram (Text)

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer (Flutter)             │
│              Order Pages, Checkout, Status Tracking          │
│                  Listens to SyncEvent stream                │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                   Sync Layer (Polling-Based)                │
│    HybridSyncManager (5s intervals) → SyncEvent stream     │
│         Version tracking via sync_metadata table            │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer (Dart)                     │
│  SupabaseOrderService (CRUD)                               │
│  SupabaseCustomerService (Search)                          │
│  SupabaseMenuService (Availability)                        │
│  SupabaseInventoryService (Tracking)                       │
│  + Other specialized services                              │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────┐
│               Data Layer (Supabase PostgreSQL)              │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Orders     │  │ Order Items  │  │  Customers   │     │
│  │  (UUID PK)   │  │ (JSONB opts) │  │  (Search)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Menu Items  │  │  Inventory   │  │   Finance    │     │
│  │ (Categories) │  │ (Ingredients)│  │  (Tracking)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │        sync_metadata (version tracking)         │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │ Triggers (auto-increment version on changes)    │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Current System Status

**Mode**: Hybrid (both SQLite and Supabase active)
**Default**: Supabase enabled (`useSupabaseProvider = true`)
**Sync Strategy**: Polling (5s intervals)
**Sync Latency**: ~5 seconds
**ID Type**: UUID (Supabase), Integer (SQLite legacy)
**Transaction Support**: RPC functions on Supabase, native SQLite transactions

## Common Questions

**Q: How are order items stored?**
A: In the `order_items` table with `selected_options` as JSONB. See section 3 of DATABASE_AND_SERVICES_OVERVIEW.md

**Q: How does sync work?**
A: Polling every 5 seconds with version tracking. See EXECUTIVE_SUMMARY.md "Retrieving Orders" flow.

**Q: What's the payment method rule?**
A: DELIVERED orders require `payment_method NOT IN (null, '', 'none')`. See payment validation section.

**Q: Can I use SQLite instead of Supabase?**
A: Yes, toggle `useSupabaseProvider = false` in supabase_providers.dart (not recommended).

**Q: Is there real-time sync?**
A: Currently polling-based (5s). WebSocket support is a future enhancement.

---

**Last Updated**: November 1, 2025
**Created**: November 1, 2025
**Author**: Database & Architecture Analysis
