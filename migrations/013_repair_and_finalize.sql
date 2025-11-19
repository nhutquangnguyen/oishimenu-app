-- Migration 013: Repair data and finalize restaurant migration
-- This replaces the previous 013 migration with proper data validation and repair

-- Step 1: Check and repair any missing restaurant_id values
-- First, let's see what data needs fixing

-- Check for orphaned menu_categories
DO $$
DECLARE
    orphaned_count INTEGER;
    default_restaurant_id UUID;
    admin_user_id UUID;
BEGIN
    -- Count orphaned menu_categories
    SELECT COUNT(*) INTO orphaned_count FROM menu_categories WHERE restaurant_id IS NULL;

    IF orphaned_count > 0 THEN
        RAISE NOTICE 'Found % orphaned menu_categories that need repair', orphaned_count;

        -- Try to find an admin user to assign orphaned data to
        SELECT id INTO admin_user_id FROM users WHERE role = 'admin' LIMIT 1;

        -- If no admin user, use the first user
        IF admin_user_id IS NULL THEN
            SELECT id INTO admin_user_id FROM users ORDER BY created_at ASC LIMIT 1;
        END IF;

        IF admin_user_id IS NOT NULL THEN
            -- Find or create a default restaurant for the admin user
            SELECT id INTO default_restaurant_id
            FROM restaurants
            WHERE owner_user_id = admin_user_id
            LIMIT 1;

            -- If no restaurant exists for this user, create one
            IF default_restaurant_id IS NULL THEN
                INSERT INTO restaurants (
                    name, slug, description, country, cuisine_type, price_range,
                    owner_user_id, brand, is_active, created_at, updated_at
                ) VALUES (
                    'Default Restaurant',
                    'default-restaurant-' || EXTRACT(epoch FROM NOW())::INTEGER,
                    'Default restaurant for orphaned data',
                    'VN',
                    'vietnamese',
                    2,
                    admin_user_id,
                    'Default Brand',
                    true,
                    NOW(),
                    NOW()
                ) RETURNING id INTO default_restaurant_id;

                RAISE NOTICE 'Created default restaurant with ID: %', default_restaurant_id;
            END IF;

            -- Update orphaned menu_categories
            UPDATE menu_categories
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;

            RAISE NOTICE 'Updated % orphaned menu_categories', orphaned_count;
        ELSE
            RAISE EXCEPTION 'No users found to assign orphaned data to. Please ensure there is at least one user in the system.';
        END IF;
    ELSE
        RAISE NOTICE 'No orphaned menu_categories found';
    END IF;
END $$;

-- Step 2: Repair menu_items
DO $$
DECLARE
    orphaned_count INTEGER;
    default_restaurant_id UUID;
    admin_user_id UUID;
BEGIN
    SELECT COUNT(*) INTO orphaned_count FROM menu_items WHERE restaurant_id IS NULL;

    IF orphaned_count > 0 THEN
        RAISE NOTICE 'Found % orphaned menu_items that need repair', orphaned_count;

        SELECT id INTO admin_user_id FROM users WHERE role = 'admin' LIMIT 1;
        IF admin_user_id IS NULL THEN
            SELECT id INTO admin_user_id FROM users ORDER BY created_at ASC LIMIT 1;
        END IF;

        SELECT id INTO default_restaurant_id FROM restaurants WHERE owner_user_id = admin_user_id LIMIT 1;

        UPDATE menu_items
        SET restaurant_id = default_restaurant_id
        WHERE restaurant_id IS NULL;

        RAISE NOTICE 'Updated % orphaned menu_items', orphaned_count;
    END IF;
END $$;

-- Step 3: Repair customers
DO $$
DECLARE
    orphaned_count INTEGER;
    default_restaurant_id UUID;
    admin_user_id UUID;
BEGIN
    SELECT COUNT(*) INTO orphaned_count FROM customers WHERE restaurant_id IS NULL;

    IF orphaned_count > 0 THEN
        RAISE NOTICE 'Found % orphaned customers that need repair', orphaned_count;

        SELECT id INTO admin_user_id FROM users WHERE role = 'admin' LIMIT 1;
        IF admin_user_id IS NULL THEN
            SELECT id INTO admin_user_id FROM users ORDER BY created_at ASC LIMIT 1;
        END IF;

        SELECT id INTO default_restaurant_id FROM restaurants WHERE owner_user_id = admin_user_id LIMIT 1;

        UPDATE customers
        SET restaurant_id = default_restaurant_id
        WHERE restaurant_id IS NULL;

        RAISE NOTICE 'Updated % orphaned customers', orphaned_count;
    END IF;
END $$;

-- Step 4: Repair orders
DO $$
DECLARE
    orphaned_count INTEGER;
    default_restaurant_id UUID;
    admin_user_id UUID;
BEGIN
    SELECT COUNT(*) INTO orphaned_count FROM orders WHERE restaurant_id IS NULL;

    IF orphaned_count > 0 THEN
        RAISE NOTICE 'Found % orphaned orders that need repair', orphaned_count;

        SELECT id INTO admin_user_id FROM users WHERE role = 'admin' LIMIT 1;
        IF admin_user_id IS NULL THEN
            SELECT id INTO admin_user_id FROM users ORDER BY created_at ASC LIMIT 1;
        END IF;

        SELECT id INTO default_restaurant_id FROM restaurants WHERE owner_user_id = admin_user_id LIMIT 1;

        UPDATE orders
        SET restaurant_id = default_restaurant_id
        WHERE restaurant_id IS NULL;

        RAISE NOTICE 'Updated % orphaned orders', orphaned_count;
    END IF;
END $$;

-- Step 5: Repair ingredients (if table exists)
DO $$
DECLARE
    orphaned_count INTEGER;
    default_restaurant_id UUID;
    admin_user_id UUID;
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ingredients') THEN
        SELECT COUNT(*) INTO orphaned_count FROM ingredients WHERE restaurant_id IS NULL;

        IF orphaned_count > 0 THEN
            RAISE NOTICE 'Found % orphaned ingredients that need repair', orphaned_count;

            SELECT id INTO admin_user_id FROM users WHERE role = 'admin' LIMIT 1;
            IF admin_user_id IS NULL THEN
                SELECT id INTO admin_user_id FROM users ORDER BY created_at ASC LIMIT 1;
            END IF;

            SELECT id INTO default_restaurant_id FROM restaurants WHERE owner_user_id = admin_user_id LIMIT 1;

            UPDATE ingredients
            SET restaurant_id = default_restaurant_id
            WHERE restaurant_id IS NULL;

            RAISE NOTICE 'Updated % orphaned ingredients', orphaned_count;
        END IF;
    END IF;
END $$;

-- Step 6: Verification - check all tables have proper restaurant_id values
DO $$
DECLARE
    null_categories INTEGER;
    null_items INTEGER;
    null_customers INTEGER;
    null_orders INTEGER;
    null_ingredients INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_categories FROM menu_categories WHERE restaurant_id IS NULL;
    SELECT COUNT(*) INTO null_items FROM menu_items WHERE restaurant_id IS NULL;
    SELECT COUNT(*) INTO null_customers FROM customers WHERE restaurant_id IS NULL;
    SELECT COUNT(*) INTO null_orders FROM orders WHERE restaurant_id IS NULL;

    -- Check ingredients only if table exists
    null_ingredients := 0;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ingredients') THEN
        SELECT COUNT(*) INTO null_ingredients FROM ingredients WHERE restaurant_id IS NULL;
    END IF;

    RAISE NOTICE 'Verification Results:';
    RAISE NOTICE 'Menu categories with NULL restaurant_id: %', null_categories;
    RAISE NOTICE 'Menu items with NULL restaurant_id: %', null_items;
    RAISE NOTICE 'Customers with NULL restaurant_id: %', null_customers;
    RAISE NOTICE 'Orders with NULL restaurant_id: %', null_orders;
    RAISE NOTICE 'Ingredients with NULL restaurant_id: %', null_ingredients;

    IF null_categories + null_items + null_customers + null_orders + null_ingredients > 0 THEN
        RAISE EXCEPTION 'Data repair incomplete. Found % total records with NULL restaurant_id',
                        null_categories + null_items + null_customers + null_orders + null_ingredients;
    ELSE
        RAISE NOTICE 'All data successfully repaired. Ready to make restaurant_id NOT NULL.';
    END IF;
END $$;

-- Step 7: Now safely make restaurant_id NOT NULL for core tables
DO $$
BEGIN
    RAISE NOTICE 'Making restaurant_id columns NOT NULL...';

    -- Make restaurant_id NOT NULL for menu_categories
    ALTER TABLE menu_categories ALTER COLUMN restaurant_id SET NOT NULL;
    RAISE NOTICE 'menu_categories.restaurant_id is now NOT NULL';

    -- Make restaurant_id NOT NULL for menu_items
    ALTER TABLE menu_items ALTER COLUMN restaurant_id SET NOT NULL;
    RAISE NOTICE 'menu_items.restaurant_id is now NOT NULL';

    -- Make restaurant_id NOT NULL for customers
    ALTER TABLE customers ALTER COLUMN restaurant_id SET NOT NULL;
    RAISE NOTICE 'customers.restaurant_id is now NOT NULL';

    -- Make restaurant_id NOT NULL for orders
    ALTER TABLE orders ALTER COLUMN restaurant_id SET NOT NULL;
    RAISE NOTICE 'orders.restaurant_id is now NOT NULL';

    -- Make restaurant_id NOT NULL for ingredients (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ingredients') THEN
        ALTER TABLE ingredients ALTER COLUMN restaurant_id SET NOT NULL;
        RAISE NOTICE 'ingredients.restaurant_id is now NOT NULL';
    END IF;
END $$;

-- Step 8: Drop old RLS policies and remove user_id columns
DO $$
BEGIN
    RAISE NOTICE 'Dropping old user_id-based RLS policies...';

    -- Drop existing policies for menu_categories
    DROP POLICY IF EXISTS "Users can view own menu categories" ON menu_categories;
    DROP POLICY IF EXISTS "Users can insert own menu categories" ON menu_categories;
    DROP POLICY IF EXISTS "Users can update own menu categories" ON menu_categories;
    DROP POLICY IF EXISTS "Users can delete own menu categories" ON menu_categories;
    RAISE NOTICE 'Dropped old policies for menu_categories';

    -- Drop existing policies for menu_items
    DROP POLICY IF EXISTS "Users can view own menu items" ON menu_items;
    DROP POLICY IF EXISTS "Users can insert own menu items" ON menu_items;
    DROP POLICY IF EXISTS "Users can update own menu items" ON menu_items;
    DROP POLICY IF EXISTS "Users can delete own menu items" ON menu_items;
    RAISE NOTICE 'Dropped old policies for menu_items';

    -- Drop existing policies for customers
    DROP POLICY IF EXISTS "Users can view own customers" ON customers;
    DROP POLICY IF EXISTS "Users can insert own customers" ON customers;
    DROP POLICY IF EXISTS "Users can update own customers" ON customers;
    DROP POLICY IF EXISTS "Users can delete own customers" ON customers;
    RAISE NOTICE 'Dropped old policies for customers';

    -- Drop existing policies for orders
    DROP POLICY IF EXISTS "Users can view own orders" ON orders;
    DROP POLICY IF EXISTS "Users can insert own orders" ON orders;
    DROP POLICY IF EXISTS "Users can update own orders" ON orders;
    DROP POLICY IF EXISTS "Users can delete own orders" ON orders;
    RAISE NOTICE 'Dropped old policies for orders';

    -- Drop existing policies for ingredients (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ingredients') THEN
        DROP POLICY IF EXISTS "Users can view own ingredients" ON ingredients;
        DROP POLICY IF EXISTS "Users can insert own ingredients" ON ingredients;
        DROP POLICY IF EXISTS "Users can update own ingredients" ON ingredients;
        DROP POLICY IF EXISTS "Users can delete own ingredients" ON ingredients;
        RAISE NOTICE 'Dropped old policies for ingredients';
    END IF;

    -- Drop existing policies for option_groups (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'option_groups') THEN
        DROP POLICY IF EXISTS "Users can view own option groups" ON option_groups;
        DROP POLICY IF EXISTS "Users can insert own option groups" ON option_groups;
        DROP POLICY IF EXISTS "Users can update own option groups" ON option_groups;
        DROP POLICY IF EXISTS "Users can delete own option groups" ON option_groups;
        RAISE NOTICE 'Dropped old policies for option_groups';
    END IF;

    -- Drop existing policies for menu_options (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'menu_options') THEN
        DROP POLICY IF EXISTS "Users can view own menu options" ON menu_options;
        DROP POLICY IF EXISTS "Users can insert own menu options" ON menu_options;
        DROP POLICY IF EXISTS "Users can update own menu options" ON menu_options;
        DROP POLICY IF EXISTS "Users can delete own menu options" ON menu_options;
        RAISE NOTICE 'Dropped old policies for menu_options';
    END IF;

    -- Drop existing policies for transactions (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'transactions') THEN
        DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
        DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;
        DROP POLICY IF EXISTS "Users can update own transactions" ON transactions;
        DROP POLICY IF EXISTS "Users can delete own transactions" ON transactions;
        RAISE NOTICE 'Dropped old policies for transactions';
    END IF;

    -- Drop existing policies for finance_entries (if exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        DROP POLICY IF EXISTS "Users can view own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can insert own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can update own finance entries" ON finance_entries;
        DROP POLICY IF EXISTS "Users can delete own finance entries" ON finance_entries;
        RAISE NOTICE 'Dropped old policies for finance_entries';
    END IF;

    RAISE NOTICE 'Removing user_id columns...';

    -- Remove user_id from menu_categories
    ALTER TABLE menu_categories DROP COLUMN IF EXISTS user_id;
    RAISE NOTICE 'Dropped user_id from menu_categories';

    -- Remove user_id from menu_items
    ALTER TABLE menu_items DROP COLUMN IF EXISTS user_id;
    RAISE NOTICE 'Dropped user_id from menu_items';

    -- Remove user_id from customers
    ALTER TABLE customers DROP COLUMN IF EXISTS user_id;
    RAISE NOTICE 'Dropped user_id from customers';

    -- Remove user_id from orders
    ALTER TABLE orders DROP COLUMN IF EXISTS user_id;
    RAISE NOTICE 'Dropped user_id from orders';

    -- Remove user_id from ingredients
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ingredients') THEN
        ALTER TABLE ingredients DROP COLUMN IF EXISTS user_id;
        RAISE NOTICE 'Dropped user_id from ingredients';
    END IF;

    -- Remove user_id from other tables if they exist
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'option_groups') THEN
        ALTER TABLE option_groups DROP COLUMN IF EXISTS user_id;
        RAISE NOTICE 'Dropped user_id from option_groups';
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'menu_options') THEN
        ALTER TABLE menu_options DROP COLUMN IF EXISTS user_id;
        RAISE NOTICE 'Dropped user_id from menu_options';
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'transactions') THEN
        ALTER TABLE transactions DROP COLUMN IF EXISTS user_id;
        RAISE NOTICE 'Dropped user_id from transactions';
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        ALTER TABLE finance_entries DROP COLUMN IF EXISTS user_id;
        RAISE NOTICE 'Dropped user_id from finance_entries';
    END IF;

    RAISE NOTICE 'Migration 013 completed successfully! Restaurant-level architecture is now fully active.';
END $$;

-- Step 9: Create new restaurant-based RLS policies
DO $$
BEGIN
    RAISE NOTICE 'Creating new restaurant-based RLS policies...';

    -- Policies for menu_categories
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

    -- Policies for menu_items
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

    -- Policies for customers
    CREATE POLICY "Users can view restaurant customers" ON customers
        FOR SELECT USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = customers.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can insert restaurant customers" ON customers
        FOR INSERT WITH CHECK (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = customers.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can update restaurant customers" ON customers
        FOR UPDATE USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = customers.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can delete restaurant customers" ON customers
        FOR DELETE USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = customers.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    -- Policies for orders
    CREATE POLICY "Users can view restaurant orders" ON orders
        FOR SELECT USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = orders.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can insert restaurant orders" ON orders
        FOR INSERT WITH CHECK (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = orders.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can update restaurant orders" ON orders
        FOR UPDATE USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = orders.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    CREATE POLICY "Users can delete restaurant orders" ON orders
        FOR DELETE USING (
            EXISTS (
                SELECT 1 FROM restaurants r
                WHERE r.id = orders.restaurant_id
                AND r.owner_user_id = auth.uid()
            )
        );

    RAISE NOTICE 'Created restaurant-based RLS policies for all core tables';
    RAISE NOTICE 'Restaurant migration completed successfully! Your app now supports multi-restaurant architecture.';
END $$;