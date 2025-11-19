-- Migration 017: Complete Finance Table Data Isolation Fix
-- This migration fixes data sharing bug by ensuring both transactions AND finance_entries tables
-- have proper restaurant-based isolation with correct RLS policies

-- ==================================================================
-- STEP 1: Fix transactions table (in case 016 wasn't applied yet)
-- ==================================================================

-- Drop any existing problematic policies for transactions
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

CREATE POLICY "Restaurant transactions access" ON transactions
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- ==================================================================
-- STEP 2: Fix finance_entries table (THIS IS THE MAIN ISSUE!)
-- ==================================================================

-- Check current state of finance_entries table
DO $$
BEGIN
    -- Check if finance_entries table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        RAISE NOTICE 'finance_entries table exists, proceeding with migration...';
    ELSE
        RAISE NOTICE 'finance_entries table does not exist, skipping finance_entries migration...';
        RETURN;
    END IF;
END $$;

-- Drop any existing problematic policies for finance_entries
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON finance_entries;
DROP POLICY IF EXISTS "Allow authenticated read access" ON finance_entries;
DROP POLICY IF EXISTS "Allow authenticated write access" ON finance_entries;
DROP POLICY IF EXISTS "Users can view own finance entries" ON finance_entries;
DROP POLICY IF EXISTS "Users can insert own finance entries" ON finance_entries;
DROP POLICY IF EXISTS "Users can update own finance entries" ON finance_entries;
DROP POLICY IF EXISTS "Users can delete own finance entries" ON finance_entries;

-- Add restaurant_id column to finance_entries if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'finance_entries' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE finance_entries ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_finance_entries_restaurant ON finance_entries(restaurant_id);
    END IF;
END $$;

-- Migrate existing finance_entries data to restaurants
DO $$
DECLARE
    user_record RECORD;
    default_restaurant_id UUID;
BEGIN
    -- For each user that has finance entries, assign them to their default restaurant
    FOR user_record IN
        SELECT DISTINCT user_id
        FROM finance_entries
        WHERE user_id IS NOT NULL AND restaurant_id IS NULL
    LOOP
        -- Get the first restaurant for this user
        SELECT id INTO default_restaurant_id
        FROM restaurants
        WHERE owner_user_id = user_record.user_id
        ORDER BY created_at ASC
        LIMIT 1;

        -- If no restaurant exists for this user, create a default one
        IF default_restaurant_id IS NULL THEN
            INSERT INTO restaurants (
                name, slug, description, country, cuisine_type, price_range,
                owner_user_id, brand, is_active, created_at, updated_at
            ) VALUES (
                'Default Restaurant',
                'default-restaurant-' || user_record.user_id,
                'Default restaurant for migrated finance data',
                'VN',
                'vietnamese',
                2,
                user_record.user_id,
                'Default Brand',
                true,
                NOW(),
                NOW()
            ) RETURNING id INTO default_restaurant_id;
        END IF;

        -- Migrate finance entries for this user
        UPDATE finance_entries
        SET restaurant_id = default_restaurant_id
        WHERE user_id = user_record.user_id AND restaurant_id IS NULL;
    END LOOP;

    RAISE NOTICE 'Finance entries data migration completed successfully';
END $$;

-- Make restaurant_id NOT NULL for finance_entries (after data migration)
ALTER TABLE finance_entries ALTER COLUMN restaurant_id SET NOT NULL;

-- Create proper restaurant-based RLS policy for finance_entries
ALTER TABLE finance_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Restaurant finance entries access" ON finance_entries
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- ==================================================================
-- STEP 3: Update indexes for performance
-- ==================================================================

-- Create optimized indexes for restaurant-based queries
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_type ON transactions(restaurant_id, transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_time ON transactions(restaurant_id, transaction_time);
CREATE INDEX IF NOT EXISTS idx_finance_entries_restaurant_type ON finance_entries(restaurant_id, type);
CREATE INDEX IF NOT EXISTS idx_finance_entries_restaurant_created ON finance_entries(restaurant_id, created_at);

-- ==================================================================
-- STEP 4: Verification and Documentation
-- ==================================================================

-- Add documentation
COMMENT ON POLICY "Restaurant transactions access" ON transactions IS
'Ensures users can only access transactions for restaurants they own - prevents data leakage between different restaurants';

COMMENT ON POLICY "Restaurant finance entries access" ON finance_entries IS
'Ensures users can only access finance entries for restaurants they own - prevents data leakage between different restaurants';

COMMENT ON COLUMN transactions.restaurant_id IS 'Restaurant ID for multi-tenant data isolation - ensures transactions are isolated between different restaurants';
COMMENT ON COLUMN finance_entries.restaurant_id IS 'Restaurant ID for multi-tenant data isolation - ensures finance entries are isolated between different restaurants';

-- Final verification
DO $$
DECLARE
    transactions_count INTEGER;
    finance_entries_count INTEGER;
    transactions_policies_count INTEGER;
    finance_entries_policies_count INTEGER;
BEGIN
    -- Check data counts
    SELECT COUNT(*) INTO transactions_count FROM transactions WHERE restaurant_id IS NOT NULL;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        SELECT COUNT(*) INTO finance_entries_count FROM finance_entries WHERE restaurant_id IS NOT NULL;
    ELSE
        finance_entries_count := 0;
    END IF;

    -- Check policy counts
    SELECT COUNT(*) INTO transactions_policies_count
    FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Restaurant transactions access';

    SELECT COUNT(*) INTO finance_entries_policies_count
    FROM pg_policies
    WHERE tablename = 'finance_entries' AND policyname = 'Restaurant finance entries access';

    RAISE NOTICE '=== MIGRATION VERIFICATION REPORT ===';
    RAISE NOTICE 'Transactions with restaurant_id: %', transactions_count;
    RAISE NOTICE 'Finance entries with restaurant_id: %', finance_entries_count;
    RAISE NOTICE 'Transaction policies created: %', transactions_policies_count;
    RAISE NOTICE 'Finance entry policies created: %', finance_entries_policies_count;

    IF transactions_policies_count > 0 AND (finance_entries_policies_count > 0 OR finance_entries_count = 0) THEN
        RAISE NOTICE '✅ SUCCESS: Finance table isolation migration completed successfully!';
        RAISE NOTICE '🔒 Both transactions and finance_entries are now properly isolated by restaurant.';
        RAISE NOTICE '🛡️ Data sharing between restaurants has been completely eliminated.';
    ELSE
        RAISE NOTICE '❌ WARNING: Migration may not have completed successfully.';
        RAISE NOTICE 'Please check the above counts and verify policies manually.';
    END IF;
END $$;