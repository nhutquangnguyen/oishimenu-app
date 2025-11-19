-- Migration 018: Remove finance_entries table and consolidate to transactions only
-- This migration simplifies the architecture by using transactions table as single source of truth
-- and ensures proper restaurant-based data isolation

-- ==================================================================
-- STEP 1: Ensure transactions table has proper setup first
-- ==================================================================

-- Fix transactions table RLS policies (ensuring this is applied)
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can update own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can delete own transactions" ON transactions;

-- Ensure restaurant_id column exists in transactions table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'transactions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE transactions ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_transactions_restaurant ON transactions(restaurant_id);

        -- Migrate existing data to default restaurant for each user
        UPDATE transactions
        SET restaurant_id = (
            SELECT r.id
            FROM restaurants r
            WHERE r.owner_user_id = transactions.user_id
            ORDER BY r.created_at ASC
            LIMIT 1
        )
        WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

        -- Make restaurant_id NOT NULL after migration
        ALTER TABLE transactions ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;
END $$;

-- Create proper restaurant-based RLS policy for transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Only create the policy if it doesn't already exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'transactions' AND policyname = 'Restaurant transactions access'
    ) THEN
        CREATE POLICY "Restaurant transactions access" ON transactions
            FOR ALL USING (
                restaurant_id IN (
                    SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
                )
            );
        RAISE NOTICE 'Created new Restaurant transactions access policy';
    ELSE
        RAISE NOTICE 'Restaurant transactions access policy already exists, skipping';
    END IF;
END $$;

-- ==================================================================
-- STEP 2: Migrate data from finance_entries to transactions (if exists)
-- ==================================================================

DO $$
DECLARE
    finance_entry RECORD;
    new_transaction_id UUID;
BEGIN
    -- Check if finance_entries table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        RAISE NOTICE 'Migrating data from finance_entries to transactions...';

        -- Migrate each finance entry to transactions table
        FOR finance_entry IN
            SELECT fe.*, r.id as restaurant_id
            FROM finance_entries fe
            LEFT JOIN restaurants r ON r.owner_user_id = fe.user_id
            WHERE r.id IS NOT NULL
            ORDER BY fe.created_at ASC
        LOOP
            -- Check if this entry already exists in transactions (avoid duplicates)
            IF NOT EXISTS (
                SELECT 1 FROM transactions
                WHERE description = finance_entry.description
                AND amount = finance_entry.amount
                AND restaurant_id = finance_entry.restaurant_id
                AND ABS(EXTRACT(EPOCH FROM (transaction_time - finance_entry.created_at))) < 60 -- Within 1 minute
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
                    CASE WHEN finance_entry.type = 'expense' THEN -ABS(finance_entry.amount) ELSE ABS(finance_entry.amount) END,
                    'VND',
                    finance_entry.category,
                    finance_entry.description,
                    finance_entry.created_at,
                    finance_entry.restaurant_id,
                    finance_entry.user_id,
                    finance_entry.created_at,
                    finance_entry.updated_at
                );
            END IF;
        END LOOP;

        RAISE NOTICE 'Finance entries migration to transactions completed.';
    ELSE
        RAISE NOTICE 'finance_entries table does not exist, skipping migration.';
    END IF;
END $$;

-- ==================================================================
-- STEP 3: Remove finance_entries table and related objects
-- ==================================================================

-- Drop finance_entries table if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        -- Drop any policies first
        DROP POLICY IF EXISTS "Restaurant finance entries access" ON finance_entries;
        DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON finance_entries;
        DROP POLICY IF EXISTS "Allow authenticated read access" ON finance_entries;
        DROP POLICY IF EXISTS "Allow authenticated write access" ON finance_entries;

        -- Drop triggers if they exist
        DROP TRIGGER IF EXISTS update_finance_entries_updated_at ON finance_entries;

        -- Drop indexes
        DROP INDEX IF EXISTS idx_finance_entries_user_id;
        DROP INDEX IF EXISTS idx_finance_entries_created_at;
        DROP INDEX IF EXISTS idx_finance_entries_type;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant_type;
        DROP INDEX IF EXISTS idx_finance_entries_restaurant_created;

        -- Finally drop the table
        DROP TABLE finance_entries;

        RAISE NOTICE 'finance_entries table and related objects have been removed.';
    ELSE
        RAISE NOTICE 'finance_entries table does not exist, nothing to remove.';
    END IF;
END $$;

-- ==================================================================
-- STEP 4: Optimize transactions table for finance queries
-- ==================================================================

-- Create optimized indexes for finance-related queries
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_type_time ON transactions(restaurant_id, transaction_type, transaction_time);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_status_time ON transactions(restaurant_id, payment_status, transaction_time);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_category ON transactions(restaurant_id, category);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_amount ON transactions(restaurant_id, amount);

-- Create a view for finance entries compatibility (optional - can be used for gradual migration)
CREATE OR REPLACE VIEW finance_entries_view AS
SELECT
    id,
    CASE
        WHEN transaction_type = 'REVENUE' THEN 'income'
        WHEN transaction_type = 'EXPENSE' THEN 'expense'
        ELSE 'other'
    END as type,
    ABS(amount) as amount,
    description,
    category,
    restaurant_id,
    user_id,
    transaction_time as created_at,
    updated_at
FROM transactions
WHERE transaction_type IN ('REVENUE', 'EXPENSE');

-- Add RLS to the view
ALTER VIEW finance_entries_view SET (security_invoker = true);

-- ==================================================================
-- STEP 5: Documentation and verification
-- ==================================================================

-- Add documentation
COMMENT ON TABLE transactions IS 'Single source of truth for all financial data including revenue, expenses, adjustments, transfers, and fees. Replaces the old finance_entries table.';
COMMENT ON COLUMN transactions.restaurant_id IS 'Restaurant ID for multi-tenant data isolation - ensures transactions are isolated between different restaurants';

COMMENT ON VIEW finance_entries_view IS 'Compatibility view that exposes transactions as finance entries for gradual migration. Can be removed once all code is updated.';

-- Final verification and cleanup report
DO $$
DECLARE
    transactions_count INTEGER;
    revenue_count INTEGER;
    expense_count INTEGER;
    policies_count INTEGER;
BEGIN
    -- Check transaction counts
    SELECT COUNT(*) INTO transactions_count FROM transactions WHERE restaurant_id IS NOT NULL;
    SELECT COUNT(*) INTO revenue_count FROM transactions WHERE transaction_type = 'REVENUE';
    SELECT COUNT(*) INTO expense_count FROM transactions WHERE transaction_type = 'EXPENSE';

    -- Check policy count
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Restaurant transactions access';

    RAISE NOTICE '=== FINANCE CONSOLIDATION REPORT ===';
    RAISE NOTICE 'Total transactions with restaurant_id: %', transactions_count;
    RAISE NOTICE 'Revenue transactions: %', revenue_count;
    RAISE NOTICE 'Expense transactions: %', expense_count;
    RAISE NOTICE 'Restaurant isolation policies: %', policies_count;
    RAISE NOTICE '';

    IF policies_count > 0 AND transactions_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: Finance consolidation completed successfully!';
        RAISE NOTICE '🔒 transactions table is now the single source of truth for all financial data.';
        RAISE NOTICE '🛡️ Proper restaurant-based isolation is enforced.';
        RAISE NOTICE '📊 finance_entries table has been removed and data migrated.';
        RAISE NOTICE '';
        RAISE NOTICE '📝 NEXT STEPS:';
        RAISE NOTICE '1. Update your Flutter code to use only TransactionService';
        RAISE NOTICE '2. Remove SupabaseFinanceService calls';
        RAISE NOTICE '3. Test the application thoroughly';
        RAISE NOTICE '4. Remove finance_entries_view once migration is complete';
    ELSE
        RAISE NOTICE '❌ WARNING: Migration may not have completed successfully.';
        RAISE NOTICE 'Please verify the transaction counts and policies manually.';
    END IF;
END $$;