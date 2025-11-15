-- Migration: Add user_id column to finance_entries table for user data isolation
-- Run this in your Supabase SQL Editor

-- Note: This table might already have user_id column from createFinanceEntry method
-- Check if the column exists first, if it does, skip to RLS setup

-- Step 1: Add user_id column to finance_entries table (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'finance_entries'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE finance_entries
        ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

-- Step 2: Add index for performance (if it doesn't exist)
CREATE INDEX IF NOT EXISTS idx_finance_entries_user_id ON finance_entries(user_id);

-- Step 3: Update existing finance_entries to assign to first admin/staff user
-- (Only for entries that don't have user_id set)
UPDATE finance_entries
SET user_id = (
    SELECT id
    FROM auth.users
    LIMIT 1
)
WHERE user_id IS NULL;

-- Step 4: Make user_id NOT NULL after data migration
ALTER TABLE finance_entries
ALTER COLUMN user_id SET NOT NULL;

-- Step 5: Add Row Level Security (RLS) policy for finance_entries
ALTER TABLE finance_entries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own finance entries
CREATE POLICY "Users can view own finance entries"
ON finance_entries
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert finance entries for themselves
CREATE POLICY "Users can insert own finance entries"
ON finance_entries
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own finance entries
CREATE POLICY "Users can update own finance entries"
ON finance_entries
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own finance entries
CREATE POLICY "Users can delete own finance entries"
ON finance_entries
FOR DELETE
USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON COLUMN finance_entries.user_id IS 'User ID (restaurant owner/staff) who owns this finance entry - for multi-tenant data isolation';