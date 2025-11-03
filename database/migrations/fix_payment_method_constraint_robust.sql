-- Migration: Fix payment method constraint (robust version)
-- Description: Safely update payment_method constraint with comprehensive data handling
-- Date: 2024-11-03

-- Step 1: Check current payment method values (uncomment to see what exists)
-- SELECT DISTINCT payment_method, COUNT(*)
-- FROM public.orders
-- GROUP BY payment_method
-- ORDER BY payment_method;

-- Step 2: Drop existing constraint first (if it exists)
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;

-- Step 3: Update ALL rows to ensure compliance, including NULL and empty values
UPDATE public.orders
SET payment_method = CASE
    -- Handle old values that need mapping
    WHEN payment_method = 'digital_wallet' THEN 'mobilePayment'
    WHEN payment_method = 'bank_transfer' THEN 'bankTransfer'
    -- Handle standard values
    WHEN payment_method = 'cash' THEN 'cash'
    WHEN payment_method = 'card' THEN 'card'
    WHEN payment_method = 'mobilePayment' THEN 'mobilePayment'
    WHEN payment_method = 'bankTransfer' THEN 'bankTransfer'
    WHEN payment_method = 'other' THEN 'other'
    WHEN payment_method = 'none' THEN 'none'
    -- Handle edge cases
    WHEN payment_method = '' OR payment_method IS NULL THEN 'none'
    -- Any other unexpected values default to cash
    ELSE 'cash'
END;

-- Step 4: Ensure no NULL values remain
UPDATE public.orders
SET payment_method = 'none'
WHERE payment_method IS NULL;

-- Step 5: Add new constraint that matches application enum exactly
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN ('none', 'cash', 'card', 'mobilePayment', 'bankTransfer', 'other'));

-- Step 6: Verify all rows comply (uncomment to check)
-- SELECT payment_method, COUNT(*) as count
-- FROM public.orders
-- WHERE payment_method NOT IN ('none', 'cash', 'card', 'mobilePayment', 'bankTransfer', 'other')
-- GROUP BY payment_method;