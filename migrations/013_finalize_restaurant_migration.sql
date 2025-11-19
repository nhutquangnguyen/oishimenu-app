-- Migration 013: Finalize restaurant migration
-- Make restaurant_id NOT NULL and remove user_id columns (optional step)

-- Step 1: Make restaurant_id NOT NULL for core tables
-- Only execute after data migration is complete and verified

-- Make restaurant_id NOT NULL for menu_categories
ALTER TABLE menu_categories ALTER COLUMN restaurant_id SET NOT NULL;

-- Make restaurant_id NOT NULL for menu_items
ALTER TABLE menu_items ALTER COLUMN restaurant_id SET NOT NULL;

-- Make restaurant_id NOT NULL for customers
ALTER TABLE customers ALTER COLUMN restaurant_id SET NOT NULL;

-- Make restaurant_id NOT NULL for orders
ALTER TABLE orders ALTER COLUMN restaurant_id SET NOT NULL;

-- Make restaurant_id NOT NULL for ingredients
ALTER TABLE ingredients ALTER COLUMN restaurant_id SET NOT NULL;

-- Optional: Remove user_id columns (uncomment when ready)
-- WARNING: This is irreversible. Ensure all data is properly migrated first.
-- Consider keeping user_id for a transition period.

/*
-- Remove user_id from menu_categories
ALTER TABLE menu_categories DROP COLUMN IF EXISTS user_id;

-- Remove user_id from menu_items
ALTER TABLE menu_items DROP COLUMN IF EXISTS user_id;

-- Remove user_id from customers
ALTER TABLE customers DROP COLUMN IF EXISTS user_id;

-- Remove user_id from orders
ALTER TABLE orders DROP COLUMN IF EXISTS user_id;

-- Remove user_id from ingredients
ALTER TABLE ingredients DROP COLUMN IF EXISTS user_id;

-- Remove user_id from option_groups (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'option_groups') THEN
        ALTER TABLE option_groups DROP COLUMN IF EXISTS user_id;
    END IF;
END $$;

-- Remove user_id from menu_options (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'menu_options') THEN
        ALTER TABLE menu_options DROP COLUMN IF EXISTS user_id;
    END IF;
END $$;

-- Remove user_id from transactions (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'transactions') THEN
        ALTER TABLE transactions DROP COLUMN IF EXISTS user_id;
    END IF;
END $$;

-- Remove user_id from finance_entries (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        ALTER TABLE finance_entries DROP COLUMN IF EXISTS user_id;
    END IF;
END $$;
*/

-- Update RLS policies to use restaurant ownership instead of direct user ownership
-- For menu_categories
DROP POLICY IF EXISTS "Users can view own menu categories" ON menu_categories;
CREATE POLICY "Users can view restaurant menu categories" ON menu_categories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_categories.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert restaurant menu categories" ON menu_categories
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_categories.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update restaurant menu categories" ON menu_categories
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_categories.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete restaurant menu categories" ON menu_categories
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_categories.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

-- For menu_items
DROP POLICY IF EXISTS "Users can view own menu items" ON menu_items;
CREATE POLICY "Users can view restaurant menu items" ON menu_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_items.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert restaurant menu items" ON menu_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_items.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update restaurant menu items" ON menu_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_items.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete restaurant menu items" ON menu_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM restaurants r
            WHERE r.id = menu_items.restaurant_id
            AND r.owner_user_id = auth.uid()
        )
    );

-- Enable RLS for menu_categories and menu_items if not already enabled
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;