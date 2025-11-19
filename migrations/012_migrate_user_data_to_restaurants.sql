-- Migration 012: Migrate existing user data to restaurant-based structure
-- This creates a default restaurant for each user and migrates their existing data

-- Step 1: Create default restaurants for existing users
INSERT INTO restaurants (
    name,
    slug,
    description,
    country,
    cuisine_type,
    price_range,
    owner_user_id,
    brand,
    is_active,
    created_at,
    updated_at
)
SELECT
    COALESCE(u.full_name || '''s Restaurant', 'My Restaurant') as name,
    LOWER(REPLACE(COALESCE(u.full_name, 'restaurant'), ' ', '-')) || '-' || SUBSTRING(u.id::text, 1, 8) as slug,
    'Default restaurant created during data migration' as description,
    'VN' as country, -- Default to Vietnam, adjust as needed
    'vietnamese' as cuisine_type, -- Default cuisine type
    2 as price_range, -- Default to medium price range ($$)
    u.id as owner_user_id,
    COALESCE(u.full_name || '''s Brand', 'My Brand') as brand,
    true as is_active,
    u.created_at,
    NOW() as updated_at
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM restaurants r WHERE r.owner_user_id = u.id
);

-- Step 2: Update menu_categories with restaurant_id
UPDATE menu_categories
SET restaurant_id = (
    SELECT r.id
    FROM restaurants r
    WHERE r.owner_user_id = menu_categories.user_id
    LIMIT 1
)
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

-- Step 3: Update menu_items with restaurant_id
UPDATE menu_items
SET restaurant_id = (
    SELECT r.id
    FROM restaurants r
    WHERE r.owner_user_id = menu_items.user_id
    LIMIT 1
)
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

-- Step 4: Update customers with restaurant_id
UPDATE customers
SET restaurant_id = (
    SELECT r.id
    FROM restaurants r
    WHERE r.owner_user_id = customers.user_id
    LIMIT 1
)
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

-- Step 5: Update orders with restaurant_id
UPDATE orders
SET restaurant_id = (
    SELECT r.id
    FROM restaurants r
    WHERE r.owner_user_id = orders.user_id
    LIMIT 1
)
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

-- Step 6: Update ingredients with restaurant_id
UPDATE ingredients
SET restaurant_id = (
    SELECT r.id
    FROM restaurants r
    WHERE r.owner_user_id = ingredients.user_id
    LIMIT 1
)
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;

-- Step 7: Update option_groups with restaurant_id (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'option_groups') THEN
        UPDATE option_groups
        SET restaurant_id = (
            SELECT r.id
            FROM restaurants r
            WHERE r.owner_user_id = option_groups.user_id
            LIMIT 1
        )
        WHERE restaurant_id IS NULL AND user_id IS NOT NULL;
    END IF;
END $$;

-- Step 8: Update menu_options with restaurant_id (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'menu_options') THEN
        UPDATE menu_options
        SET restaurant_id = (
            SELECT r.id
            FROM restaurants r
            WHERE r.owner_user_id = menu_options.user_id
            LIMIT 1
        )
        WHERE restaurant_id IS NULL AND user_id IS NOT NULL;
    END IF;
END $$;

-- Step 9: Update transactions with restaurant_id (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'transactions') THEN
        UPDATE transactions
        SET restaurant_id = (
            SELECT r.id
            FROM restaurants r
            WHERE r.owner_user_id = transactions.user_id
            LIMIT 1
        )
        WHERE restaurant_id IS NULL AND user_id IS NOT NULL;
    END IF;
END $$;

-- Step 10: Update finance_entries with restaurant_id (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        UPDATE finance_entries
        SET restaurant_id = (
            SELECT r.id
            FROM restaurants r
            WHERE r.owner_user_id = finance_entries.user_id
            LIMIT 1
        )
        WHERE restaurant_id IS NULL AND user_id IS NOT NULL;
    END IF;
END $$;

-- Verification: Count records that couldn't be migrated
-- (Should be 0 if migration is successful)
SELECT
    'menu_categories' as table_name,
    COUNT(*) as unmigrated_records
FROM menu_categories
WHERE restaurant_id IS NULL AND user_id IS NOT NULL

UNION ALL

SELECT
    'menu_items' as table_name,
    COUNT(*) as unmigrated_records
FROM menu_items
WHERE restaurant_id IS NULL AND user_id IS NOT NULL

UNION ALL

SELECT
    'customers' as table_name,
    COUNT(*) as unmigrated_records
FROM customers
WHERE restaurant_id IS NULL AND user_id IS NOT NULL

UNION ALL

SELECT
    'orders' as table_name,
    COUNT(*) as unmigrated_records
FROM orders
WHERE restaurant_id IS NULL AND user_id IS NOT NULL

UNION ALL

SELECT
    'ingredients' as table_name,
    COUNT(*) as unmigrated_records
FROM ingredients
WHERE restaurant_id IS NULL AND user_id IS NOT NULL;