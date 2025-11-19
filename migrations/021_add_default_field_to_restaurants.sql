-- Migration 021: Add default field to restaurants table
-- This allows users to mark one restaurant as their default

-- ==================================================================
-- STEP 1: Add default column to restaurants table
-- ==================================================================

DO $$
BEGIN
    -- Check if the default column already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'restaurants' AND column_name = 'is_default'
    ) THEN
        -- Add is_default column with default value false
        ALTER TABLE restaurants ADD COLUMN is_default BOOLEAN DEFAULT FALSE;

        RAISE NOTICE '✅ Added is_default column to restaurants table';
    ELSE
        RAISE NOTICE '⚠️ is_default column already exists in restaurants table';
    END IF;
END $$;

-- ==================================================================
-- STEP 2: Ensure only one restaurant per user can be default
-- ==================================================================

-- Create a unique partial index to ensure only one default restaurant per user
DO $$
BEGIN
    -- Drop the index if it already exists
    DROP INDEX IF EXISTS idx_restaurants_default_per_user;

    -- Create unique partial index - only one TRUE value per owner_user_id
    CREATE UNIQUE INDEX idx_restaurants_default_per_user
    ON restaurants (owner_user_id)
    WHERE is_default = TRUE;

    RAISE NOTICE '✅ Created unique index for default restaurants per user';
EXCEPTION
    WHEN duplicate_table THEN
        RAISE NOTICE '⚠️ Index idx_restaurants_default_per_user already exists';
    WHEN others THEN
        RAISE NOTICE '⚠️ Index creation failed or already exists';
END $$;

-- ==================================================================
-- STEP 3: Set first restaurant as default for existing users
-- ==================================================================

DO $$
DECLARE
    user_record RECORD;
    first_restaurant_record RECORD;
BEGIN
    -- Loop through each user who has restaurants
    FOR user_record IN
        SELECT DISTINCT owner_user_id
        FROM restaurants
        WHERE owner_user_id IS NOT NULL
    LOOP
        -- Check if user already has a default restaurant
        IF NOT EXISTS (
            SELECT 1 FROM restaurants
            WHERE owner_user_id = user_record.owner_user_id
            AND is_default = TRUE
        ) THEN
            -- Get the first restaurant for this user (by creation date)
            SELECT id, name INTO first_restaurant_record
            FROM restaurants
            WHERE owner_user_id = user_record.owner_user_id
            ORDER BY created_at ASC
            LIMIT 1;

            -- Set it as default
            IF first_restaurant_record.id IS NOT NULL THEN
                UPDATE restaurants
                SET is_default = TRUE
                WHERE id = first_restaurant_record.id;

                RAISE NOTICE '✅ Set restaurant "%" (ID: %) as default for user %', first_restaurant_record.name, first_restaurant_record.id, user_record.owner_user_id;
            END IF;
        END IF;
    END LOOP;

    RAISE NOTICE '✅ Completed setting default restaurants for existing users';
END $$;

-- ==================================================================
-- STEP 4: Create function to manage default restaurant setting
-- ==================================================================

-- Create function to set a restaurant as default (and unset others)
DO $$
BEGIN
    -- Drop function if exists (try all possible signatures)
    DROP FUNCTION IF EXISTS set_default_restaurant(INTEGER, INTEGER);
    DROP FUNCTION IF EXISTS set_default_restaurant(TEXT, TEXT);
    DROP FUNCTION IF EXISTS set_default_restaurant(INTEGER, UUID);

    -- Create function to set a restaurant as default (and unset others)
    -- We'll use a more flexible approach that handles different column types
    EXECUTE '
    CREATE OR REPLACE FUNCTION set_default_restaurant(
        restaurant_id TEXT,
        user_id TEXT
    ) RETURNS BOOLEAN AS $func$
    DECLARE
        restaurant_exists BOOLEAN := FALSE;
        update_count INTEGER := 0;
    BEGIN
        -- Check if the restaurant exists and belongs to the user
        -- Try different approaches to handle various data types
        BEGIN
            SELECT EXISTS(
                SELECT 1 FROM restaurants
                WHERE id = restaurant_id::INTEGER
                AND (
                    owner_user_id::TEXT = user_id
                    OR owner_user_id = user_id::UUID
                )
            ) INTO restaurant_exists;
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback: simple string comparison
                SELECT EXISTS(
                    SELECT 1 FROM restaurants
                    WHERE id::TEXT = restaurant_id
                    AND owner_user_id::TEXT = user_id
                ) INTO restaurant_exists;
        END;

        IF NOT restaurant_exists THEN
            RETURN FALSE;
        END IF;

        -- First, unset all defaults for this user
        BEGIN
            UPDATE restaurants
            SET is_default = FALSE
            WHERE (
                owner_user_id::TEXT = user_id
                OR owner_user_id = user_id::UUID
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback approach
                UPDATE restaurants
                SET is_default = FALSE
                WHERE owner_user_id::TEXT = user_id;
        END;

        -- Then set the specified restaurant as default
        BEGIN
            UPDATE restaurants
            SET is_default = TRUE
            WHERE id = restaurant_id::INTEGER AND (
                owner_user_id::TEXT = user_id
                OR owner_user_id = user_id::UUID
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback approach
                UPDATE restaurants
                SET is_default = TRUE
                WHERE id::TEXT = restaurant_id AND owner_user_id::TEXT = user_id;
        END;

        GET DIAGNOSTICS update_count = ROW_COUNT;

        -- Return true if we updated exactly one row
        RETURN update_count = 1;
    END;
    $func$ LANGUAGE plpgsql;
    ';

    RAISE NOTICE '✅ Created set_default_restaurant function';
END $$;

-- ==================================================================
-- VERIFICATION
-- ==================================================================

DO $$
DECLARE
    total_restaurants INTEGER;
    default_restaurants INTEGER;
    users_with_defaults INTEGER;
BEGIN
    -- Count total restaurants
    SELECT COUNT(*) INTO total_restaurants FROM restaurants;

    -- Count default restaurants
    SELECT COUNT(*) INTO default_restaurants FROM restaurants WHERE is_default = TRUE;

    -- Count users with default restaurants
    SELECT COUNT(DISTINCT owner_user_id) INTO users_with_defaults
    FROM restaurants WHERE is_default = TRUE;

    RAISE NOTICE '📊 Migration Summary:';
    RAISE NOTICE '   Total restaurants: %', total_restaurants;
    RAISE NOTICE '   Default restaurants: %', default_restaurants;
    RAISE NOTICE '   Users with defaults: %', users_with_defaults;

    IF default_restaurants > 0 THEN
        RAISE NOTICE '✅ Migration 021 completed successfully';
    ELSE
        RAISE NOTICE '⚠️ No default restaurants found - this may be expected if no restaurants exist';
    END IF;
END $$;