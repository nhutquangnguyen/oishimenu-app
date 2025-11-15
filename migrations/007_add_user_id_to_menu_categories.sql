-- Migration: Add user_id column to menu_categories table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to menu_categories table
ALTER TABLE menu_categories
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_menu_categories_user_id ON menu_categories(user_id);

-- Step 3: Update existing menu_categories to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE menu_categories
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE menu_categories
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for menu_categories
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own menu categories
CREATE POLICY "Users can view own menu categories"
ON menu_categories
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert menu categories for themselves
CREATE POLICY "Users can insert own menu categories"
ON menu_categories
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own menu categories
CREATE POLICY "Users can update own menu categories"
ON menu_categories
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own menu categories
CREATE POLICY "Users can delete own menu categories"
ON menu_categories
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN menu_categories.user_id IS 'User ID (restaurant owner/staff) who owns this menu category - for multi-tenant data isolation';