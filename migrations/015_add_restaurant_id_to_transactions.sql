-- Migration 015: Add restaurant_id to transactions table for proper restaurant isolation
-- This migration fixes the critical bug where transactions are shared between restaurants owned by the same user

-- Step 1: Add restaurant_id column to transactions table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'transactions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE transactions ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_transactions_restaurant ON transactions(restaurant_id);
    END IF;
END $$;

-- Step 2: Data Migration - Assign existing transactions to restaurants
-- This is critical to maintain existing data while implementing proper isolation
DO $$
DECLARE
    user_record RECORD;
    default_restaurant_id UUID;
BEGIN
    -- For each user that has transactions, assign them to their default restaurant
    FOR user_record IN
        SELECT DISTINCT user_id
        FROM transactions
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
                'Default restaurant for migrated transaction data',
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

        -- Migrate transactions for this user
        UPDATE transactions
        SET restaurant_id = default_restaurant_id
        WHERE user_id = user_record.user_id AND restaurant_id IS NULL;
    END LOOP;

    RAISE NOTICE 'Transaction data migration completed successfully';
END $$;

-- Step 3: Make restaurant_id NOT NULL (after data migration)
ALTER TABLE transactions ALTER COLUMN restaurant_id SET NOT NULL;

-- Step 4: Update RLS Policies to enforce restaurant-level isolation
-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can update own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can delete own transactions" ON transactions;

-- Create new restaurant-specific policies
-- Users can only access transactions for restaurants they own
CREATE POLICY "Restaurant transactions access" ON transactions
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- Step 5: Update the updated_at trigger to include restaurant_id in index
DROP INDEX IF EXISTS idx_transactions_user_id;
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_user ON transactions(restaurant_id, user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_type ON transactions(restaurant_id, transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_restaurant_time ON transactions(restaurant_id, transaction_time);

-- Add documentation
COMMENT ON COLUMN transactions.restaurant_id IS 'Restaurant ID for multi-tenant data isolation - ensures transactions are isolated between different restaurants';

-- Migration completed successfully
DO $$
BEGIN
    RAISE NOTICE 'Transaction restaurant isolation migration completed successfully!';
    RAISE NOTICE 'Transactions are now properly isolated by restaurant_id.';
END $$;