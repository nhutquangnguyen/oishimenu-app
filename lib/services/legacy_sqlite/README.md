# Legacy SQLite Services Archive

**Archive Date:** October 27, 2025
**Status:** ARCHIVED - No longer used in production

## 📁 **Archived Files:**

### **Core Business Services (Migrated to Supabase):**
- `menu_service.dart` → **SupabaseMenuService**
- `menu_option_service.dart` → **SupabaseMenuOptionService**
- `inventory_service.dart` → **SupabaseInventoryService**
- `order_service.dart` → **SupabaseOrderService**
- `customer_service.dart` → **SupabaseCustomerService**
- `order_source_service.dart` → **SupabaseOrderSourceService**

### **Utility Services:**
- `sample_data_service.dart` - Sample data generation for SQLite
- `menu_import_service.dart` - Menu import functionality (uses multiple SQLite services)

## 🚀 **Migration Completed:**

✅ **All production code** has been successfully migrated to Supabase
✅ **Modern cloud-native architecture** with PostgreSQL
✅ **UUID primary keys** for better scalability
✅ **Row Level Security** enabled
✅ **Real-time capabilities** ready

## ⚠️ **Important Notes:**

1. **Do NOT restore these files** without careful consideration
2. **Test/debug files** may still reference these services - update them separately
3. **Database schema** has been migrated from SQLite to PostgreSQL
4. **New services** are in `/lib/services/supabase_service.dart`

## 🔄 **If Rollback Needed (Emergency Only):**

1. Move files back to `/lib/services/`
2. Update imports in production files
3. Ensure SQLite database is available
4. Test all functionality thoroughly

---

**Migration completed as part of Phase 3 cleanup - SQLite to Supabase migration project**