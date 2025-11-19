# Supabase Services Update Plan

This file tracks the progress of updating Supabase services from user_id to restaurant_id.

## Tables that need restaurant_id updates:
1. ✅ restaurants (already handled)
2. ⏳ menu_categories
3. ⏳ menu_items
4. ⏳ customers
5. ⏳ orders (CRITICAL - causing errors)
6. ⏳ ingredients
7. ⏳ option_groups
8. ⏳ menu_options
9. ⏳ transactions
10. ⏳ finance_entries

## Services to update:
1. ⏳ SupabaseMenuService
2. ⏳ SupabaseCustomerService
3. ⏳ SupabaseOrderService (CRITICAL)
4. ⏳ SupabaseInventoryService
5. ⏳ SupabaseMenuOptionService
6. ⏳ SupabaseOrderSourceService
7. ⏳ SupabaseFinanceService

## Strategy:
1. Add _getCurrentRestaurantId() helper to each service class
2. Replace user_id parameters with restaurant_id parameters
3. Update all .eq('user_id', ...) to .eq('restaurant_id', ...)
4. Focus on orders-related services first (causing immediate errors)

## Current Status:
- ✅ Added _getCurrentRestaurantId() to SupabaseMenuService
- ✅ Updated getMenuItems() method
- ⏳ Need to update all other methods