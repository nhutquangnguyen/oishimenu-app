-- Comprehensive clean slate script for user data isolation
-- This will delete ALL shared data to ensure clean user isolation
-- Run this in your Supabase SQL Editor

-- WARNING: This will permanently delete all application data
-- Make sure you have a backup if needed

-- Delete in order to respect foreign key constraints

-- 1. Delete finance entries (depends on nothing)
DELETE FROM finance_entries;

-- 2. Delete transactions (depends on nothing)
DELETE FROM transactions;

-- 3. Delete inventory transactions (depends on ingredients)
DELETE FROM inventory_transactions;

-- 4. Delete menu options (depends on option_groups and menu_items)
DELETE FROM menu_options;

-- 5. Delete option groups (depends on nothing)
DELETE FROM option_groups;

-- 6. Delete order items (depends on orders and menu_items)
DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders);

-- 7. Delete orders (depends on customers)
DELETE FROM orders;

-- 8. Delete menu items (depends on menu_categories)
DELETE FROM menu_items;

-- 9. Delete menu categories (depends on nothing)
DELETE FROM menu_categories;

-- 10. Delete ingredients (depends on nothing)
DELETE FROM ingredients;

-- 11. Delete customers (depends on nothing)
DELETE FROM customers;