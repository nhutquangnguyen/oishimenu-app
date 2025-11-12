-- Migration to safely drop the order_payments table
-- Run this AFTER verifying data migration with verify_data_migration.sql

-- Step 1: Create a backup of order_payments data (optional safety measure)
DO $$
DECLARE
    table_exists BOOLEAN := FALSE;
BEGIN
    -- Check if order_payments table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'order_payments'
    ) INTO table_exists;

    IF table_exists THEN
        -- Create backup table with timestamp
        EXECUTE format('CREATE TABLE order_payments_backup_%s AS SELECT * FROM public.order_payments',
                      to_char(now(), 'YYYY_MM_DD_HH24_MI_SS'));

        RAISE NOTICE '✅ Created backup table: order_payments_backup_%', to_char(now(), 'YYYY_MM_DD_HH24_MI_SS');
    ELSE
        RAISE NOTICE 'ℹ️  order_payments table does not exist - nothing to backup';
    END IF;
END $$;

-- Step 2: Drop the order_payments_view (if it exists)
DO $$
BEGIN
    DROP VIEW IF EXISTS public.order_payments_view CASCADE;
    RAISE NOTICE '✅ Dropped order_payments_view (if it existed)';
END $$;

-- Step 3: Drop all indexes on order_payments table
DO $$
DECLARE
    index_record RECORD;
    table_exists BOOLEAN := FALSE;
BEGIN
    -- Check if order_payments table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'order_payments'
    ) INTO table_exists;

    IF table_exists THEN
        -- Drop all indexes on order_payments table
        FOR index_record IN
            SELECT schemaname, indexname
            FROM pg_indexes
            WHERE schemaname = 'public'
            AND tablename = 'order_payments'
            AND indexname != 'order_payments_pkey'  -- Don't drop primary key index explicitly
        LOOP
            EXECUTE format('DROP INDEX IF EXISTS %I.%I CASCADE',
                         index_record.schemaname, index_record.indexname);
            RAISE NOTICE '✅ Dropped index: %', index_record.indexname;
        END LOOP;
    END IF;
END $$;

-- Step 4: Drop foreign key constraints that reference order_payments
DO $$
DECLARE
    constraint_record RECORD;
    table_exists BOOLEAN := FALSE;
BEGIN
    -- Check if order_payments table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'order_payments'
    ) INTO table_exists;

    IF table_exists THEN
        -- Find and drop foreign key constraints that reference order_payments
        FOR constraint_record IN
            SELECT
                tc.constraint_name,
                tc.table_name,
                tc.table_schema
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
                ON ccu.constraint_name = tc.constraint_name
                AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND ccu.table_name = 'order_payments'
                AND tc.table_schema = 'public'
        LOOP
            EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I CASCADE',
                         constraint_record.table_schema,
                         constraint_record.table_name,
                         constraint_record.constraint_name);
            RAISE NOTICE '✅ Dropped FK constraint: % from table %',
                       constraint_record.constraint_name, constraint_record.table_name;
        END LOOP;
    END IF;
END $$;

-- Step 5: Drop the order_payments table
DO $$
BEGIN
    DROP TABLE IF EXISTS public.order_payments CASCADE;
    RAISE NOTICE '✅ Dropped order_payments table';
END $$;

-- Step 6: Verify cleanup
DO $$
DECLARE
    remaining_objects INTEGER := 0;
    table_record RECORD;
BEGIN
    -- Check for any remaining objects related to order_payments
    SELECT COUNT(*) INTO remaining_objects
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name LIKE '%order_payments%'
    AND table_name NOT LIKE '%backup%';

    IF remaining_objects = 0 THEN
        RAISE NOTICE '✅ Cleanup verification PASSED - No remaining order_payments objects found';
    ELSE
        RAISE NOTICE '⚠️  Found % remaining objects with order_payments in name', remaining_objects;
    END IF;

    -- Show backup tables created
    SELECT COUNT(*) INTO remaining_objects
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name LIKE 'order_payments_backup_%';

    IF remaining_objects > 0 THEN
        RAISE NOTICE 'ℹ️  % backup tables created (these can be dropped manually later if no longer needed)', remaining_objects;

        FOR table_record IN
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name LIKE 'order_payments_backup_%'
            ORDER BY table_name
        LOOP
            RAISE NOTICE '   - %', table_record.table_name;
        END LOOP;
    END IF;
END $$;

-- Step 7: Final success message
DO $$
BEGIN
    RAISE NOTICE '🎉 order_payments table removal completed successfully!';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Update application code to remove PaymentService references';
    RAISE NOTICE '2. Test application functionality';
    RAISE NOTICE '3. Drop backup tables when confident migration is successful';
END $$;