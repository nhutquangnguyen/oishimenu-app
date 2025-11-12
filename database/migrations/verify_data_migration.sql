-- Verification script to ensure all order_payments data is migrated to transactions table
-- Run this before dropping the order_payments table

-- Check if order_payments table exists and count records
DO $$
DECLARE
    order_payments_count INTEGER := 0;
    transactions_order_count INTEGER := 0;
    table_exists BOOLEAN := FALSE;
    record RECORD;
BEGIN
    -- Check if order_payments table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'order_payments'
    ) INTO table_exists;

    IF table_exists THEN
        -- Count records in order_payments
        SELECT COUNT(*) INTO order_payments_count FROM public.order_payments;

        -- Count order-related transactions (should match or exceed order_payments count)
        SELECT COUNT(*) INTO transactions_order_count
        FROM public.transactions
        WHERE transaction_type = 'REVENUE'
        AND reference_type = 'ORDER';

        -- Display results
        RAISE NOTICE 'Order Payments Table: % records found', order_payments_count;
        RAISE NOTICE 'Order Transactions: % records found', transactions_order_count;

        IF transactions_order_count >= order_payments_count THEN
            RAISE NOTICE '✅ Migration verification PASSED - All order payments appear to be migrated';
        ELSE
            RAISE NOTICE '❌ Migration verification FAILED - Missing order payment transactions';
            RAISE NOTICE 'Expected at least % transactions, but found %', order_payments_count, transactions_order_count;
        END IF;

        -- Show sample comparison
        RAISE NOTICE '--- Sample Data Comparison ---';

        -- Show first 5 order_payments records
        RAISE NOTICE 'Sample order_payments:';
        FOR record IN
            SELECT order_id, payment_method, amount_paid, payment_status, created_at
            FROM public.order_payments
            ORDER BY created_at DESC
            LIMIT 5
        LOOP
            RAISE NOTICE 'Order: %, Method: %, Amount: %, Status: %, Created: %',
                record.order_id, record.payment_method, record.amount_paid, record.payment_status, record.created_at;
        END LOOP;

        -- Show corresponding transactions
        RAISE NOTICE 'Sample order transactions:';
        FOR record IN
            SELECT reference_id, payment_method, amount, payment_status, created_at
            FROM public.transactions
            WHERE transaction_type = 'REVENUE' AND reference_type = 'ORDER'
            ORDER BY created_at DESC
            LIMIT 5
        LOOP
            RAISE NOTICE 'Order: %, Method: %, Amount: %, Status: %, Created: %',
                record.reference_id, record.payment_method, record.amount, record.payment_status, record.created_at;
        END LOOP;

    ELSE
        RAISE NOTICE 'ℹ️  order_payments table does not exist - likely already migrated or never created';

        -- Still show order transactions count
        SELECT COUNT(*) INTO transactions_order_count
        FROM public.transactions
        WHERE transaction_type = 'REVENUE'
        AND reference_type = 'ORDER';

        RAISE NOTICE 'Order Transactions: % records found', transactions_order_count;
    END IF;

END $$;

-- Additional verification: Check for orphaned data
-- Orders with payments in order_payments but not in transactions
DO $$
DECLARE
    table_exists BOOLEAN := FALSE;
    orphaned_count INTEGER := 0;
    record RECORD;
BEGIN
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'order_payments'
    ) INTO table_exists;

    IF table_exists THEN
        SELECT COUNT(DISTINCT op.order_id) INTO orphaned_count
        FROM public.order_payments op
        LEFT JOIN public.transactions t ON (
            t.reference_id = op.order_id
            AND t.transaction_type = 'REVENUE'
            AND t.reference_type = 'ORDER'
        )
        WHERE t.id IS NULL;

        IF orphaned_count > 0 THEN
            RAISE NOTICE '❌ Found % orders with payments in order_payments but not in transactions', orphaned_count;

            -- Show the orphaned orders
            FOR record IN
                SELECT DISTINCT op.order_id
                FROM public.order_payments op
                LEFT JOIN public.transactions t ON (
                    t.reference_id = op.order_id
                    AND t.transaction_type = 'REVENUE'
                    AND t.reference_type = 'ORDER'
                )
                WHERE t.id IS NULL
                LIMIT 10
            LOOP
                RAISE NOTICE 'Orphaned order: %', record.order_id;
            END LOOP;
        ELSE
            RAISE NOTICE '✅ No orphaned order payments found';
        END IF;
    END IF;
END $$;