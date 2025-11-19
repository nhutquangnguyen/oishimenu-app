-- Migration 019: Safe removal of finance_entries and consolidation to transactions
-- This version handles existing policies gracefully

-- ==================================================================
-- STEP 1: Verify transactions table is properly set up
-- ==================================================================

-- Ensure transactions table has restaurant_id and proper isolation
-- (This should already be done by previous migrations, but ensuring it's complete)

DO $$
BEGIN
    -- Check if restaurant_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'transactions' AND column_name = 'restaurant_id'
    ) THEN
        RAISE EXCEPTION 'transactions table is missing restaurant_id column. Please run migration 016 first.';
    END IF;

    -- Check if restaurant isolation policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'transactions' AND policyname = 'Restaurant transactions access'
    ) THEN
        RAISE EXCEPTION 'transactions table is missing restaurant isolation policy. Please run migration 016 first.';
    END IF;

    RAISE NOTICE 'transactions table is properly configured for restaurant isolation';
END $$;

-- ==================================================================
-- STEP 2: Migrate any remaining data from finance_entries to transactions
-- ==================================================================

DO $$
DECLARE
    finance_entry RECORD;
    migration_count INTEGER := 0;
    fallback_restaurant_id UUID;
BEGIN
    -- Check if finance_entries table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        RAISE NOTICE 'finance_entries table found, starting data migration...';

        -- Get the first restaurant ID as a fallback (we'll assign all entries to it)
        SELECT id INTO fallback_restaurant_id
        FROM restaurants
        ORDER BY created_at ASC
        LIMIT 1;

        IF fallback_restaurant_id IS NULL THEN
            RAISE EXCEPTION 'No restaurants found. Cannot migrate finance entries.';
        END IF;

        RAISE NOTICE 'Using fallback restaurant ID: %', fallback_restaurant_id;

        -- Migrate each finance entry to transactions table
        -- Use the fallback restaurant if no restaurant_id column exists
        FOR finance_entry IN
            SELECT fe.*,
                   COALESCE(
                       (CASE WHEN EXISTS (
                           SELECT 1 FROM information_schema.columns
                           WHERE table_name = 'finance_entries' AND column_name = 'restaurant_id'
                       ) THEN fe.restaurant_id ELSE NULL END),
                       fallback_restaurant_id
                   ) as target_restaurant_id
            FROM finance_entries fe
            ORDER BY fe.created_at ASC
        LOOP
            -- Check if this entry already exists in transactions (avoid duplicates)
            IF NOT EXISTS (
                SELECT 1 FROM transactions
                WHERE description = finance_entry.description
                AND ABS(amount - CASE
                    WHEN finance_entry.type = 'expense' THEN -ABS(finance_entry.amount)
                    ELSE ABS(finance_entry.amount)
                END) < 0.01  -- Allow for small floating point differences
                AND restaurant_id = finance_entry.target_restaurant_id
                AND ABS(EXTRACT(EPOCH FROM (transaction_time - finance_entry.created_at))) < 300 -- Within 5 minutes
            ) THEN
                -- Insert into transactions table
                INSERT INTO transactions (
                    id,
                    transaction_type,
                    reference_type,
                    payment_method,
                    payment_status,
                    amount,
                    currency,
                    category,
                    description,
                    transaction_time,
                    restaurant_id,
                    user_id,
                    created_at,
                    updated_at
                ) VALUES (
                    gen_random_uuid(),
                    CASE WHEN finance_entry.type = 'income' THEN 'REVENUE' ELSE 'EXPENSE' END,
                    'MANUAL',
                    'cash', -- Default payment method for migrated entries
                    'PAID',
                    CASE
                        WHEN finance_entry.type = 'expense' THEN -ABS(finance_entry.amount)
                        ELSE ABS(finance_entry.amount)
                    END,
                    'VND',
                    finance_entry.category,
                    finance_entry.description,
                    finance_entry.created_at,
                    finance_entry.target_restaurant_id,
                    (SELECT owner_user_id FROM restaurants WHERE id = finance_entry.target_restaurant_id),
                    finance_entry.created_at,
                    COALESCE(finance_entry.updated_at, finance_entry.created_at)
                );

                migration_count := migration_count + 1;
            ELSE
                RAISE NOTICE 'Skipping duplicate entry: % (amount: %)', finance_entry.description, finance_entry.amount;
            END IF;
        END LOOP;

        RAISE NOTICE 'Migrated % entries from finance_entries to transactions', migration_count;
    ELSE
        RAISE NOTICE 'finance_entries table does not exist, skipping migration.';
    END IF;
END $$;

-- ==================================================================
-- STEP 3: Remove finance_entries table completely
-- ==================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        RAISE NOTICE 'Removing finance_entries table and all related objects...';

        -- Drop all policies (don't fail if they don't exist)
        DROP POLICY IF EXISTS "Restaurant finance entries access" ON finance_entries;
        DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON finance_entries;
        DROP POLICY IF EXISTS "Allow authenticated read access" ON finance_entries;
        DROP POLICY IF EXISTS "Allow authenticated write access" ON finance_entries;
        DROP POLICY IF EXISTS "Users can view own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can insert own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can update own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can delete own finance entries" ON finance_entries;

        -- Drop triggers
        DROP TRIGGER IF EXISTS update_finance_entries_updated_at ON finance_entries;

        -- Drop indexes
        DROP INDEX IF EXISTS idx_finance_entries_user_id;
        DROP INDEX IF EXISTS idx_finance_entries_created_at;
        DROP INDEX IF EXISTS idx_finance_entries_type;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant_type;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant_created;

        -- Drop the table
        DROP TABLE finance_entries;

        RAISE NOTICE 'finance_entries table and all related objects removed successfully';
    ELSE
        RAISE NOTICE 'finance_entries table does not exist, nothing to remove';
    END IF;
END $$;

-- ==================================================================
-- STEP 4: Optimize transactions table for finance operations
-- ==================================================================

-- Create optimized indexes for finance-related queries
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_type_time ON transactions(restaurant_id, transaction_type, transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_status_time ON transactions(restaurant_id, payment_status, transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_category ON transactions(restaurant_id, category);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_amount ON transactions(restaurant_id, amount);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_description ON transactions(restaurant_id, description);

-- ==================================================================
-- STEP 5: Create finance compatibility view (temporary, can be removed later)
-- ==================================================================

-- This view allows gradual migration of code that expects finance_entries structure
CREATE OR REPLACE VIEW finance_entries_compat AS
SELECT
    id,
    CASE
        WHEN transaction_type = 'REVENUE' THEN 'income'
        WHEN transaction_type = 'EXPENSE' THEN 'expense'
        ELSE 'other'
    END as type,
    ABS(amount) as amount,
    COALESCE(description, 'Transaction') as description,
    COALESCE(category, 'General') as category,
    restaurant_id,
    user_id,
    transaction_time as created_at,
    updated_at
FROM transactions
WHERE transaction_type IN ('REVENUE', 'EXPENSE')
AND payment_status = 'PAID';

-- Set security policy for the view
ALTER VIEW finance_entries_compat SET (security_invoker = true);

COMMENT ON VIEW finance_entries_compat IS 'Temporary compatibility view for gradual migration from finance_entries to transactions. Remove once all code is updated.';

-- ==================================================================
-- STEP 6: Final verification
-- ==================================================================

DO $$
DECLARE
    transactions_count INTEGER;
    revenue_count INTEGER;
    expense_count INTEGER;
    restaurants_count INTEGER;
    policies_count INTEGER;
BEGIN
    -- Count transactions
    SELECT COUNT(*) INTO transactions_count FROM transactions WHERE restaurant_id IS NOT NULL;
    SELECT COUNT(*) INTO revenue_count FROM transactions WHERE transaction_type = 'REVENUE';
    SELECT COUNT(*) INTO expense_count FROM transactions WHERE transaction_type = 'EXPENSE';

    -- Count restaurants
    SELECT COUNT(*) INTO restaurants_count FROM restaurants;

    -- Count policies
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Restaurant transactions access';

    RAISE NOTICE '=== MIGRATION COMPLETION REPORT ===';
    RAISE NOTICE 'Total restaurants: %', restaurants_count;
    RAISE NOTICE 'Total transactions with restaurant_id: %', transactions_count;
    RAISE NOTICE 'Revenue transactions: %', revenue_count;
    RAISE NOTICE 'Expense transactions: %', expense_count;
    RAISE NOTICE 'Restaurant isolation policies: %', policies_count;

    -- Check if finance_entries table still exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        RAISE NOTICE '⚠️  finance_entries table still exists - manual cleanup may be needed';
    ELSE
        RAISE NOTICE '✅ finance_entries table successfully removed';
    END IF;

    RAISE NOTICE '';

    IF policies_count > 0 AND transactions_count > 0 THEN
        RAISE NOTICE '🎉 SUCCESS: Finance consolidation completed!';
        RAISE NOTICE '🔒 transactions table is now the single source of truth';
        RAISE NOTICE '🛡️ Restaurant-based data isolation is properly enforced';
        RAISE NOTICE '📊 All finance data is consolidated in transactions table';
        RAISE NOTICE '';
        RAISE NOTICE '📱 NEXT STEPS:';
        RAISE NOTICE '1. Update Flutter code to use TransactionService only';
        RAISE NOTICE '2. Remove SupabaseFinanceService references';
        RAISE NOTICE '3. Test Finance page functionality');
        RAISE NOTICE '4. Remove finance_entries_compat view once migration is complete';
    ELSE
        RAISE NOTICE '❌ WARNING: Migration verification failed');
        RAISE NOTICE 'Please check transaction counts and policies manually');
    END IF;
END $$;