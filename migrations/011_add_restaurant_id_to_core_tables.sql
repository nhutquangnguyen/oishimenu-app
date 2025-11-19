-- Migration 011: Add restaurant_id to core business tables
-- This migrates from user-level to restaurant-level data organization

-- Add restaurant_id to menu_categories
ALTER TABLE menu_categories ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX idx_menu_categories_restaurant ON menu_categories(restaurant_id);

-- Add restaurant_id to menu_items
ALTER TABLE menu_items ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX idx_menu_items_restaurant ON menu_items(restaurant_id);

-- Add restaurant_id to customers
ALTER TABLE customers ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX idx_customers_restaurant ON customers(restaurant_id);

-- Add restaurant_id to orders
ALTER TABLE orders ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX idx_orders_restaurant ON orders(restaurant_id);

-- Add restaurant_id to ingredients
ALTER TABLE ingredients ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
CREATE INDEX idx_ingredients_restaurant ON ingredients(restaurant_id);

-- Add restaurant_id to option_groups (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'option_groups') THEN
        ALTER TABLE option_groups ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_option_groups_restaurant ON option_groups(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to menu_options (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'menu_options') THEN
        ALTER TABLE menu_options ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_menu_options_restaurant ON menu_options(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to transactions
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'transactions') THEN
        ALTER TABLE transactions ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_transactions_restaurant ON transactions(restaurant_id);
    END IF;
END $$;

-- Add restaurant_id to finance_entries (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'finance_entries') THEN
        ALTER TABLE finance_entries ADD COLUMN restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE;
        CREATE INDEX idx_finance_entries_restaurant ON finance_entries(restaurant_id);
    END IF;
END $$;