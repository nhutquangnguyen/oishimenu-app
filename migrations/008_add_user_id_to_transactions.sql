-- Migration: Add user_id column to transactions table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to transactions table
ALTER TABLE transactions
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_transactions_user_id ON transactions(user_id);

-- Step 3: Update existing transactions to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE transactions
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE transactions
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own transactions
CREATE POLICY "Users can view own transactions"
ON transactions
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert transactions for themselves
CREATE POLICY "Users can insert own transactions"
ON transactions
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own transactions
CREATE POLICY "Users can update own transactions"
ON transactions
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own transactions
CREATE POLICY "Users can delete own transactions"
ON transactions
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN transactions.user_id IS 'User ID (restaurant owner/staff) who owns this transaction - for multi-tenant data isolation';