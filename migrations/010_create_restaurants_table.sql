-- Migration 010: Create restaurants table
-- This implements the restaurant-level data organization

-- Create restaurants table
CREATE TABLE restaurants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    cover_image_url TEXT,

    -- Contact Information
    phone TEXT,
    email TEXT,
    website TEXT,
    country TEXT NOT NULL, -- ISO 2-letter country code (US, VN, etc.)

    -- Business Details
    cuisine_type TEXT, -- vietnamese, italian, chinese, etc.
    price_range INTEGER CHECK (price_range >= 1 AND price_range <= 4), -- 1=$ to 4=$$$$

    -- Ownership & Status
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    brand TEXT,
    is_active BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_restaurant_slug UNIQUE(slug),
    CONSTRAINT unique_restaurant_name_per_owner UNIQUE(owner_user_id, name)
);

-- Indexes for performance
CREATE INDEX idx_restaurants_owner ON restaurants(owner_user_id);
CREATE INDEX idx_restaurants_slug ON restaurants(slug);
CREATE INDEX idx_restaurants_active ON restaurants(is_active);
CREATE INDEX idx_restaurants_cuisine ON restaurants(cuisine_type);
CREATE INDEX idx_restaurants_country ON restaurants(country);

-- Row Level Security for restaurants
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see restaurants they own
CREATE POLICY "Users can view own restaurants" ON restaurants
    FOR SELECT USING (auth.uid() = owner_user_id);

-- Policy: Users can insert restaurants they own
CREATE POLICY "Users can insert own restaurants" ON restaurants
    FOR INSERT WITH CHECK (auth.uid() = owner_user_id);

-- Policy: Users can update restaurants they own
CREATE POLICY "Users can update own restaurants" ON restaurants
    FOR UPDATE USING (auth.uid() = owner_user_id);

-- Policy: Users can delete restaurants they own
CREATE POLICY "Users can delete own restaurants" ON restaurants
    FOR DELETE USING (auth.uid() = owner_user_id);