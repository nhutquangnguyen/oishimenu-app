#!/bin/bash

# Script to update Finance implementation to use transactions table as single source of truth
# This script updates the codebase after running migration 018

echo "🔄 Updating Finance implementation to use single source of truth (transactions table)..."

# Step 1: Backup original finance page
echo "📋 Creating backup of original finance page..."
cp lib/features/finance/presentation/pages/finance_page.dart lib/features/finance/presentation/pages/finance_page_backup.dart

# Step 2: Replace finance page with updated version
echo "🔄 Replacing finance page with updated implementation..."
mv lib/features/finance/presentation/pages/finance_page_updated.dart lib/features/finance/presentation/pages/finance_page.dart

# Step 3: Comment out SupabaseFinanceService references in providers
echo "🔄 Updating provider references..."
sed -i.bak 's/^final supabaseFinanceServiceProvider/\/\/ final supabaseFinanceServiceProvider/' lib/core/providers/supabase_providers.dart
sed -i.bak 's/^  return SupabaseFinanceService();/\/\/   return SupabaseFinanceService();/' lib/core/providers/supabase_providers.dart

# Step 4: Search for other SupabaseFinanceService usages
echo "🔍 Searching for remaining SupabaseFinanceService usages..."
echo "Files containing SupabaseFinanceService:"
grep -r "SupabaseFinanceService" lib/ --include="*.dart" || echo "No remaining usages found"

# Step 5: Search for finance_entries references
echo "🔍 Searching for finance_entries table references..."
echo "Files containing finance_entries:"
grep -r "finance_entries" lib/ --include="*.dart" || echo "No finance_entries references found"

echo ""
echo "✅ Finance implementation update completed!"
echo ""
echo "📝 Next steps:"
echo "1. Run the database migration: supabase db push --file migrations/018_remove_finance_entries_use_transactions_only.sql"
echo "2. Test the Finance page functionality"
echo "3. Remove any remaining SupabaseFinanceService references if found"
echo "4. Remove the backup files once everything is working"
echo ""
echo "🔍 Files to review:"
echo "- lib/features/finance/presentation/pages/finance_page.dart (updated)"
echo "- lib/features/finance/presentation/pages/finance_page_backup.dart (backup)"
echo "- lib/core/providers/supabase_providers.dart (updated)"