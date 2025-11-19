-- Diagnostic Script: Check data status before finalizing restaurant migration
-- Run this to understand what data needs to be repaired

-- Check 1: Count orphaned records by table
SELECT
    'menu_categories' as table_name,
    COUNT(*) as total_records,
    COUNT(restaurant_id) as with_restaurant_id,
    COUNT(*) - COUNT(restaurant_id) as missing_restaurant_id
FROM menu_categories

UNION ALL

SELECT
    'menu_items' as table_name,
    COUNT(*) as total_records,
    COUNT(restaurant_id) as with_restaurant_id,
    COUNT(*) - COUNT(restaurant_id) as missing_restaurant_id
FROM menu_items

UNION ALL

SELECT
    'customers' as table_name,
    COUNT(*) as total_records,
    COUNT(restaurant_id) as with_restaurant_id,
    COUNT(*) - COUNT(restaurant_id) as missing_restaurant_id
FROM customers

UNION ALL

SELECT
    'orders' as table_name,
    COUNT(*) as total_records,
    COUNT(restaurant_id) as with_restaurant_id,
    COUNT(*) - COUNT(restaurant_id) as missing_restaurant_id
FROM orders;

-- Check 2: Available restaurants and their owners
SELECT
    r.id as restaurant_id,
    r.name as restaurant_name,
    r.slug,
    u.id as owner_id,
    u.full_name as owner_name,
    u.role as owner_role,
    r.created_at
FROM restaurants r
JOIN users u ON u.id = r.owner_user_id
ORDER BY r.created_at;

-- Check 3: Users without restaurants
SELECT
    u.id,
    u.full_name,
    u.role,
    u.created_at,
    CASE
        WHEN r.id IS NULL THEN 'NO RESTAURANT'
        ELSE 'HAS RESTAURANT'
    END as restaurant_status
FROM users u
LEFT JOIN restaurants r ON r.owner_user_id = u.id
ORDER BY u.created_at;

-- Check 4: Sample of orphaned menu_categories (if any)
SELECT
    mc.id,
    mc.name,
    mc.restaurant_id,
    'ORPHANED' as status
FROM menu_categories mc
WHERE mc.restaurant_id IS NULL
LIMIT 5;

-- Check 5: Sample of orphaned menu_items (if any)
SELECT
    mi.id,
    mi.name,
    mi.restaurant_id,
    mi.user_id,
    'ORPHANED' as status
FROM menu_items mi
WHERE mi.restaurant_id IS NULL
LIMIT 5;