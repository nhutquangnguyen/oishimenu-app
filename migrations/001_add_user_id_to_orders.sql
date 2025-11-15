-- Migration: Add user_id column to orders table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to orders table
ALTER TABLE orders
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- Step 3: Update existing orders to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE orders
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE orders
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for orders
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own orders
CREATE POLICY "Users can view own orders"
ON orders
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert orders for themselves
CREATE POLICY "Users can insert own orders"
ON orders
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own orders
CREATE POLICY "Users can update own orders"
ON orders
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own orders
CREATE POLICY "Users can delete own orders"
ON orders
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN orders.user_id IS 'User ID (restaurant owner/staff) who owns this order - for multi-tenant data isolation';