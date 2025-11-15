-- Migration: Add user_id column to customers table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to customers table
ALTER TABLE customers
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_customers_user_id ON customers(user_id);

-- Step 3: Update existing customers to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE customers
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE customers
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for customers
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own customers
CREATE POLICY "Users can view own customers"
ON customers
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert customers for themselves
CREATE POLICY "Users can insert own customers"
ON customers
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own customers
CREATE POLICY "Users can update own customers"
ON customers
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own customers
CREATE POLICY "Users can delete own customers"
ON customers
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN customers.user_id IS 'User ID (restaurant owner/staff) who owns this customer - for multi-tenant data isolation';