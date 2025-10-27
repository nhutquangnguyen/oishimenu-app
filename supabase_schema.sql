-- OishiMenu Restaurant Management System
-- Supabase PostgreSQL Schema
-- Execute this in your Supabase SQL Editor

-- Enable UUID extension for better ID handling
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable Row Level Security for all tables
-- You can customize these policies based on your authentication needs

-- Users table for authentication (enhanced with Supabase auth)
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'staff' CHECK (role IN ('admin', 'manager', 'staff')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu Categories table
CREATE TABLE public.menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu Items table
CREATE TABLE public.menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID REFERENCES public.menu_categories(id),
    user_id UUID REFERENCES public.users(id) NOT NULL,
    cost_price DECIMAL(10,2),
    available_status BOOLEAN DEFAULT true,
    availability_schedule JSONB, -- JSON for scheduling availability
    photos TEXT[], -- Array of photo URLs
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu Item Sizes table
CREATE TABLE public.menu_item_sizes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    is_default BOOLEAN DEFAULT false
);

-- Customers table
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders table
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES public.customers(id),
    subtotal DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    discount DECIMAL(10,2) DEFAULT 0,
    tax DECIMAL(10,2) DEFAULT 0,
    service_charge DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    order_type TEXT NOT NULL CHECK (order_type IN ('DINE_IN', 'TAKEAWAY', 'DELIVERY')),
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'DELIVERED', 'CANCELLED')),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'digital_wallet', 'bank_transfer')),
    payment_status TEXT NOT NULL CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    table_number TEXT,
    platform TEXT DEFAULT 'direct',
    assigned_staff_id UUID REFERENCES public.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items table
CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    menu_item_id UUID REFERENCES public.menu_items(id) NOT NULL,
    menu_item_name TEXT NOT NULL,
    base_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    selected_size TEXT,
    subtotal DECIMAL(10,2) NOT NULL,
    notes TEXT,
    selected_options JSONB -- Store selected menu options as JSON
);

-- Ingredients table for inventory
CREATE TABLE public.ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    unit TEXT NOT NULL,
    current_quantity DECIMAL(10,3) DEFAULT 0,
    minimum_threshold DECIMAL(10,3) DEFAULT 0,
    cost_per_unit DECIMAL(10,2) DEFAULT 0,
    supplier TEXT,
    category TEXT,
    expiry_date DATE,
    last_restocked TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recipes table
CREATE TABLE public.recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE CASCADE NOT NULL,
    ingredient_id UUID REFERENCES public.ingredients(id) NOT NULL,
    quantity DECIMAL(10,3) NOT NULL,
    unit TEXT NOT NULL,
    notes TEXT
);

-- Inventory Transactions table
CREATE TABLE public.inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ingredient_id UUID REFERENCES public.ingredients(id) NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('PURCHASE', 'USAGE', 'WASTE', 'ADJUSTMENT')),
    quantity DECIMAL(10,3) NOT NULL,
    unit TEXT NOT NULL,
    cost DECIMAL(10,2) DEFAULT 0,
    reason TEXT,
    related_order_id UUID REFERENCES public.orders(id),
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stocktake Sessions table
CREATE TABLE public.stocktake_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('full', 'partial', 'cycle')),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'in_progress', 'completed', 'cancelled')),
    location TEXT,
    total_items INTEGER DEFAULT 0,
    counted_items INTEGER DEFAULT 0,
    variance_count INTEGER DEFAULT 0,
    total_variance_value DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_by UUID REFERENCES public.users(id)
);

-- Stocktake Items table
CREATE TABLE public.stocktake_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.stocktake_sessions(id) ON DELETE CASCADE NOT NULL,
    ingredient_id UUID REFERENCES public.ingredients(id) NOT NULL,
    ingredient_name TEXT NOT NULL,
    unit TEXT NOT NULL,
    expected_quantity DECIMAL(10,3) NOT NULL,
    counted_quantity DECIMAL(10,3),
    variance DECIMAL(10,3),
    variance_value DECIMAL(10,2),
    notes TEXT,
    counted_at TIMESTAMPTZ,
    counted_by UUID REFERENCES public.users(id)
);

-- Tables for dine-in management
CREATE TABLE public.restaurant_tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    seats INTEGER NOT NULL,
    status TEXT DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'OCCUPIED', 'RESERVED', 'CLEANING', 'OUT_OF_ORDER')),
    location TEXT,
    description TEXT,
    current_order_id UUID REFERENCES public.orders(id),
    reserved_by TEXT,
    reserved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feedback table
CREATE TABLE public.feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES public.customers(id),
    customer_name TEXT NOT NULL,
    order_id UUID REFERENCES public.orders(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    category TEXT CHECK (category IN ('service', 'product', 'delivery', 'other')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'published', 'hidden')),
    response TEXT,
    responded_by UUID REFERENCES public.users(id),
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu Options tables (for customizable items)
CREATE TABLE public.menu_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL DEFAULT 0,
    description TEXT,
    category TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Option Groups (like Size, Sweetness, Toppings)
CREATE TABLE public.option_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    min_selection INTEGER DEFAULT 0,
    max_selection INTEGER DEFAULT 1,
    is_required BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction table: Option Groups to Menu Options
CREATE TABLE public.option_group_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    option_group_id UUID REFERENCES public.option_groups(id) ON DELETE CASCADE NOT NULL,
    option_id UUID REFERENCES public.menu_options(id) ON DELETE CASCADE NOT NULL,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction table: Menu Items to Option Groups
CREATE TABLE public.menu_item_option_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE CASCADE NOT NULL,
    option_group_id UUID REFERENCES public.option_groups(id) ON DELETE CASCADE NOT NULL,
    is_required BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Sources table
CREATE TABLE public.order_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    icon_path TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('dine_in', 'takeaway', 'delivery')),
    commission_rate DECIMAL(5,2) DEFAULT 0,
    requires_commission_input BOOLEAN DEFAULT false,
    commission_input_type TEXT DEFAULT 'after_fee' CHECK (commission_input_type IN ('before_fee', 'after_fee')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Finance Entries table
CREATE TABLE public.finance_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_menu_items_category_id ON public.menu_items(category_id);
CREATE INDEX idx_menu_items_user_id ON public.menu_items(user_id);
CREATE INDEX idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_created_at ON public.orders(created_at);
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_menu_item_id ON public.order_items(menu_item_id);
CREATE INDEX idx_inventory_transactions_ingredient_id ON public.inventory_transactions(ingredient_id);
CREATE INDEX idx_recipes_menu_item_id ON public.recipes(menu_item_id);
CREATE INDEX idx_recipes_ingredient_id ON public.recipes(ingredient_id);
CREATE INDEX idx_finance_entries_user_id ON public.finance_entries(user_id);
CREATE INDEX idx_finance_entries_created_at ON public.finance_entries(created_at);
CREATE INDEX idx_finance_entries_type ON public.finance_entries(type);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at fields
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_menu_categories_updated_at BEFORE UPDATE ON public.menu_categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON public.menu_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ingredients_updated_at BEFORE UPDATE ON public.ingredients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_restaurant_tables_updated_at BEFORE UPDATE ON public.restaurant_tables FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_menu_options_updated_at BEFORE UPDATE ON public.menu_options FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_option_groups_updated_at BEFORE UPDATE ON public.option_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_order_sources_updated_at BEFORE UPDATE ON public.order_sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_finance_entries_updated_at BEFORE UPDATE ON public.finance_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS) for all tables
-- You can customize these policies based on your needs
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_sizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stocktake_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stocktake_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.option_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.option_group_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_option_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_entries ENABLE ROW LEVEL SECURITY;

-- Create policies (adjust these based on your authentication requirements)
-- These are basic policies - you should customize them for your needs

-- Allow authenticated users to read all data
CREATE POLICY "Allow authenticated read access" ON public.users FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.menu_categories FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.menu_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.menu_item_sizes FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.customers FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.ingredients FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.recipes FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.inventory_transactions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.stocktake_sessions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.stocktake_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.restaurant_tables FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.feedback FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.menu_options FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.option_groups FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.option_group_options FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.menu_item_option_groups FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.order_sources FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated read access" ON public.finance_entries FOR SELECT USING (auth.role() = 'authenticated');

-- Allow authenticated users to insert/update/delete (you may want to restrict this further)
CREATE POLICY "Allow authenticated write access" ON public.menu_categories FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.menu_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.menu_item_sizes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.customers FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.ingredients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.recipes FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.inventory_transactions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.stocktake_sessions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.stocktake_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.restaurant_tables FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.feedback FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.menu_options FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.option_groups FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.option_group_options FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.menu_item_option_groups FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.order_sources FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write access" ON public.finance_entries FOR ALL USING (auth.role() = 'authenticated');

-- Insert sample data
-- Sample menu categories
INSERT INTO public.menu_categories (name, display_order) VALUES
    ('Appetizers', 1),
    ('Main Course', 2),
    ('Desserts', 3),
    ('Beverages', 4),
    ('Vietnamese Specials', 5);

-- Sample order sources
INSERT INTO public.order_sources (name, icon_path, type, commission_rate, requires_commission_input) VALUES
    ('On site', 'dine_in', 'dine_in', 0, false),
    ('Takeaway', 'takeaway', 'takeaway', 0, false),
    ('Shopee', 'shopee', 'delivery', 29, true),
    ('Grab food', 'grab', 'delivery', 25, true);