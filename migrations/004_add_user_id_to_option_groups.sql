-- Migration: Add user_id column to option_groups and menu_options tables for user data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to option_groups table
ALTER TABLE option_groups
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Step 2: Add index for performance
CREATE INDEX idx_option_groups_user_id ON option_groups(user_id);

-- Step 3: Update existing option_groups to assign to first admin/staff user
-- (You may need to adjust this based on your actual user data)
UPDATE option_groups
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE option_groups
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for option_groups
ALTER TABLE option_groups ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own option groups
CREATE POLICY "Users can view own option groups"
ON option_groups
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert option groups for themselves
CREATE POLICY "Users can insert own option groups"
ON option_groups
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own option groups
CREATE POLICY "Users can update own option groups"
ON option_groups
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own option groups
CREATE POLICY "Users can delete own option groups"
ON option_groups
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN option_groups.user_id IS 'User ID (restaurant owner/staff) who owns this option group - for multi-tenant data isolation';