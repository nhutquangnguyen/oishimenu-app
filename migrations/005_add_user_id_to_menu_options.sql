-- Migration: Add user_id column to menu_options table for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to menu_options table
ALTER TABLE menu_options
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_menu_options_user_id ON menu_options(user_id);

-- Step 3: Update existing menu_options to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE menu_options
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE menu_options
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for menu_options
ALTER TABLE menu_options ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own menu options
CREATE POLICY "Users can view own menu options"
ON menu_options
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert menu options for themselves
CREATE POLICY "Users can insert own menu options"
ON menu_options
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own menu options
CREATE POLICY "Users can update own menu options"
ON menu_options
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own menu options
CREATE POLICY "Users can delete own menu options"
ON menu_options
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN menu_options.user_id IS 'User ID (restaurant owner/staff) who owns this menu option - for multi-tenant data isolation';