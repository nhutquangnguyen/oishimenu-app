-- Migration 016: Fix RLS policy for transactions table to ensure proper restaurant isolation
-- This migration fixes the overly permissive RLS policy that allows data sharing between restaurants

-- Step 1: Drop the problematic "Allow all operations for authenticated users" policy
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON transactions;

-- Step 2: Create proper restaurant-based isolation policy
-- This ensures users can only access transactions for restaurants they own
CREATE POLICY "Restaurant transactions access" ON transactions
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- Step 3: Verify RLS is enabled (should already be enabled, but ensuring it's set)
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Add documentation comment
COMMENT ON POLICY "Restaurant transactions access" ON transactions IS
'Ensures users can only access transactions for restaurants they own - prevents data leakage between different restaurants owned by the same or different users';

-- Migration completed successfully
DO $$
BEGIN
    RAISE NOTICE 'Transactions RLS policy fix completed successfully!';
    RAISE NOTICE 'Users can now only see transactions for their own restaurants.';
    RAISE NOTICE 'Data isolation between restaurants is now properly enforced.';
END $$;