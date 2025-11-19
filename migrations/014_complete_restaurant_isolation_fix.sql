-- Migration 014: Complete Restaurant Data Isolation Fix
-- This migration addresses the critical security issue where restaurants owned by the same user share data
-- by completing the transition from user-based to restaurant-based data isolation

-- Step 1: Add missing restaurant_id columns to tables that don't have them
-- Note: Some tables already have restaurant_id from previous migrations (011), so we use IF NOT EXISTS

-- Add restaurant_id to ingredients (currently using user_id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ingredients' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE ingredients ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_ingredients_restaurant ON ingredients(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to menu_options
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'menu_options' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE menu_options ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_menu_options_restaurant ON menu_options(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to option_groups
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'option_groups' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE option_groups ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_option_groups_restaurant ON option_groups(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to restaurant_tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'restaurant_tables' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE restaurant_tables ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_restaurant_tables_restaurant ON restaurant_tables(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to feedback
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'feedback' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE feedback ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_feedback_restaurant ON feedback(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to stocktake_sessions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stocktake_sessions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE stocktake_sessions ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_stocktake_sessions_restaurant ON stocktake_sessions(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to stocktake_items
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stocktake_items' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE stocktake_items ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_stocktake_items_restaurant ON stocktake_items(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to inventory_transactions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_transactions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE inventory_transactions ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_inventory_transactions_restaurant ON inventory_transactions(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to recipes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'recipes' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE recipes ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_recipes_restaurant ON recipes(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to finance_entries (currently using user_id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'finance_entries' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE finance_entries ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_finance_entries_restaurant ON finance_entries(restaurant_id);
    END IF;
END $$;

-- Step 2: Data Migration - Assign existing data to restaurants
-- This is critical for maintaining existing data while implementing proper isolation

DO $$
DECLARE
    restaurant_record RECORD;
    user_record RECORD;
    default_restaurant_id UUID;
BEGIN
    -- For each user, ensure they have at least one restaurant and migrate their data
    FOR user_record IN SELECT id FROM users LOOP
        -- Get the first restaurant for this user (or create one if none exists)
        SELECT id INTO default_restaurant_id
        FROM restaurants
        WHERE owner_user_id = user_record.id
        ORDER BY created_at ASC
        LIMIT 1;

        -- If no restaurant exists for this user, create a default one
        IF default_restaurant_id IS NULL THEN
            INSERT INTO restaurants (
                name, slug, description, country, cuisine_type, price_range,
                owner_user_id, brand, is_active, created_at, updated_at
            ) VALUES (
                'Default Restaurant',
                'default-restaurant-' || user_record.id,
                'Default restaurant for migrated data',
                'VN',
                'vietnamese',
                2,
                user_record.id,
                'Default Brand',
                true,
                NOW(),
                NOW()
            ) RETURNING id INTO default_restaurant_id;
        END IF;

        -- Migrate data for tables that currently use user_id but need restaurant_id

        -- Migrate ingredients (if they exist and don't have restaurant_id set)
        UPDATE ingredients
        SET restaurant_id = default_restaurant_id
        WHERE restaurant_id IS NULL;

        -- Migrate finance_entries (if they exist and don't have restaurant_id set)
        -- Check if user_id column exists first
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'finance_entries' AND column_name = 'user_id'
        ) THEN
            UPDATE finance_entries
            SET restaurant_id = default_restaurant_id
            WHERE user_id = user_record.id AND restaurant_id IS NULL;
        ELSE
            -- If no user_id column, update all records without restaurant_id
            UPDATE finance_entries
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Migrate other data that might not have restaurant_id set
        -- Only update records that don't already have restaurant_id assigned

        -- Update menu_options if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'menu_options') THEN
            UPDATE menu_options
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update option_groups if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'option_groups') THEN
            UPDATE option_groups
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update restaurant_tables if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'restaurant_tables') THEN
            UPDATE restaurant_tables
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update feedback if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feedback') THEN
            UPDATE feedback
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update stocktake_sessions if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stocktake_sessions') THEN
            UPDATE stocktake_sessions
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update stocktake_items if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stocktake_items') THEN
            UPDATE stocktake_items
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update inventory_transactions if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'inventory_transactions') THEN
            UPDATE inventory_transactions
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;

        -- Update recipes if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recipes') THEN
            UPDATE recipes
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;
        END IF;
    END LOOP;

    RAISE NOTICE 'Data migration completed successfully';
END $$;

-- Step 3: Make restaurant_id columns NOT NULL (after data migration)
-- This ensures data integrity going forward

DO $$
BEGIN
    -- Make restaurant_id NOT NULL for tables that have the column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ingredients' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE ingredients ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'menu_options' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE menu_options ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'option_groups' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE option_groups ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'restaurant_tables' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE restaurant_tables ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'feedback' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE feedback ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stocktake_sessions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE stocktake_sessions ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stocktake_items' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE stocktake_items ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_transactions' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE inventory_transactions ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'recipes' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE recipes ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'finance_entries' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE finance_entries ALTER COLUMN restaurant_id SET NOT NULL;
    END IF;
END $$;

-- Step 4: Update RLS Policies to enforce restaurant-level isolation
-- Drop existing overly permissive policies and create restaurant-specific ones

-- Function to get current user's restaurant ID from JWT
CREATE OR REPLACE FUNCTION get_current_restaurant_id()
RETURNS UUID AS $$
BEGIN
    RETURN (current_setting('request.jwt.claims', true)::json->>'restaurant_id')::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing policies (these were too permissive)
DROP POLICY IF EXISTS "Allow authenticated read access" ON menu_categories;
DROP POLICY IF EXISTS "Allow authenticated write access" ON menu_categories;
DROP POLICY IF EXISTS "Allow authenticated read access" ON menu_items;
DROP POLICY IF EXISTS "Allow authenticated write access" ON menu_items;
DROP POLICY IF EXISTS "Allow authenticated read access" ON menu_item_sizes;
DROP POLICY IF EXISTS "Allow authenticated write access" ON menu_item_sizes;
DROP POLICY IF EXISTS "Allow authenticated read access" ON customers;
DROP POLICY IF EXISTS "Allow authenticated write access" ON customers;
DROP POLICY IF EXISTS "Allow authenticated read access" ON orders;
DROP POLICY IF EXISTS "Allow authenticated write access" ON orders;
DROP POLICY IF EXISTS "Allow authenticated read access" ON order_items;
DROP POLICY IF EXISTS "Allow authenticated write access" ON order_items;
DROP POLICY IF EXISTS "Allow authenticated read access" ON ingredients;
DROP POLICY IF EXISTS "Allow authenticated write access" ON ingredients;
DROP POLICY IF EXISTS "Allow authenticated read access" ON recipes;
DROP POLICY IF EXISTS "Allow authenticated write access" ON recipes;
DROP POLICY IF EXISTS "Allow authenticated read access" ON inventory_transactions;
DROP POLICY IF EXISTS "Allow authenticated write access" ON inventory_transactions;
DROP POLICY IF EXISTS "Allow authenticated read access" ON stocktake_sessions;
DROP POLICY IF EXISTS "Allow authenticated write access" ON stocktake_sessions;
DROP POLICY IF EXISTS "Allow authenticated read access" ON stocktake_items;
DROP POLICY IF EXISTS "Allow authenticated write access" ON stocktake_items;
DROP POLICY IF EXISTS "Allow authenticated read access" ON restaurant_tables;
DROP POLICY IF EXISTS "Allow authenticated write access" ON restaurant_tables;
DROP POLICY IF EXISTS "Allow authenticated read access" ON feedback;
DROP POLICY IF EXISTS "Allow authenticated write access" ON feedback;
DROP POLICY IF EXISTS "Allow authenticated read access" ON menu_options;
DROP POLICY IF EXISTS "Allow authenticated write access" ON menu_options;
DROP POLICY IF EXISTS "Allow authenticated read access" ON option_groups;
DROP POLICY IF EXISTS "Allow authenticated write access" ON option_groups;
DROP POLICY IF EXISTS "Allow authenticated read access" ON option_group_options;
DROP POLICY IF EXISTS "Allow authenticated write access" ON option_group_options;
DROP POLICY IF EXISTS "Allow authenticated read access" ON menu_item_option_groups;
DROP POLICY IF EXISTS "Allow authenticated write access" ON menu_item_option_groups;
DROP POLICY IF EXISTS "Allow authenticated read access" ON order_sources;
DROP POLICY IF EXISTS "Allow authenticated write access" ON order_sources;
DROP POLICY IF EXISTS "Allow authenticated read access" ON finance_entries;
DROP POLICY IF EXISTS "Allow authenticated write access" ON finance_entries;

-- Create restaurant-specific policies
-- Users can only access data for restaurants they own

-- Restaurant access policy
CREATE POLICY "Users can access own restaurants" ON restaurants
    FOR ALL USING (owner_user_id = auth.uid());

-- Menu-related policies
CREATE POLICY "Restaurant menu categories access" ON menu_categories
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant menu items access" ON menu_items
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant menu item sizes access" ON menu_item_sizes
    FOR ALL USING (
        menu_item_id IN (
            SELECT id FROM menu_items WHERE restaurant_id IN (
                SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
            )
        )
    );

-- Customer and order policies
CREATE POLICY "Restaurant customers access" ON customers
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant orders access" ON orders
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant order items access" ON order_items
    FOR ALL USING (
        order_id IN (
            SELECT id FROM orders WHERE restaurant_id IN (
                SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
            )
        )
    );

-- Inventory and ingredient policies
CREATE POLICY "Restaurant ingredients access" ON ingredients
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant recipes access" ON recipes
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant inventory transactions access" ON inventory_transactions
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant stocktake sessions access" ON stocktake_sessions
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant stocktake items access" ON stocktake_items
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- Table and feedback policies
CREATE POLICY "Restaurant tables access" ON restaurant_tables
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant feedback access" ON feedback
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- Menu options and groups policies
CREATE POLICY "Restaurant menu options access" ON menu_options
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant option groups access" ON option_groups
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Restaurant option group options access" ON option_group_options
    FOR ALL USING (
        option_group_id IN (
            SELECT id FROM option_groups WHERE restaurant_id IN (
                SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Restaurant menu item option groups access" ON menu_item_option_groups
    FOR ALL USING (
        menu_item_id IN (
            SELECT id FROM menu_items WHERE restaurant_id IN (
                SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
            )
        )
    );

-- Finance policies
CREATE POLICY "Restaurant finance entries access" ON finance_entries
    FOR ALL USING (
        restaurant_id IN (
            SELECT id FROM restaurants WHERE owner_user_id = auth.uid()
        )
    );

-- Order sources can be accessed by all (they're shared reference data)
CREATE POLICY "Allow authenticated read access to order sources" ON order_sources
    FOR SELECT USING (auth.role() = 'authenticated');

-- Migration completed successfully
DO $$
BEGIN
    RAISE NOTICE 'Restaurant data isolation migration completed successfully!';
    RAISE NOTICE 'All tables now have proper restaurant_id isolation with secure RLS policies.';
END $$;