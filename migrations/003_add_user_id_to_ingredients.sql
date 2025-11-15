-- Migration: Add user_id column to ingredients table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to ingredients table
ALTER TABLE ingredients
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_ingredients_user_id ON ingredients(user_id);

-- Step 3: Update existing ingredients to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE ingredients
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE ingredients
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for ingredients
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own ingredients
CREATE POLICY "Users can view own ingredients"
ON ingredients
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert ingredients for themselves
CREATE POLICY "Users can insert own ingredients"
ON ingredients
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own ingredients
CREATE POLICY "Users can update own ingredients"
ON ingredients
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own ingredients
CREATE POLICY "Users can delete own ingredients"
ON ingredients
FOR DELETE
USING (auth.uid() = user_id);

-- Step 6: Update related tables that reference ingredients
-- Update inventory_transactions to also have user_id for better isolation
ALTER TABLE inventory_transactions
ADD COLUMN user_id UUID REFERENCES auth.users(id);

UPDATE inventory_transactions
SET user_id = (
    SELECT user_id
    FROM ingredients
    WHERE ingredients.id = inventory_transactions.ingredient_id
);

-- Make user_id NOT NULL for inventory_transactions
ALTER TABLE inventory_transactions
ALTER COLUMN user_id SET NOT NULL;

-- Add RLS for inventory_transactions
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own inventory transactions"
ON inventory_transactions
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own inventory transactions"
ON inventory_transactions
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own inventory transactions"
ON inventory_transactions
FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own inventory transactions"
ON inventory_transactions
FOR DELETE
USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON COLUMN ingredients.user_id IS 'User ID (restaurant owner/staff) who owns this ingredient - for multi-tenant data isolation';
COMMENT ON COLUMN inventory_transactions.user_id IS 'User ID (restaurant owner/staff) who owns this transaction - for multi-tenant data isolation';