-- Migration: Fix payment method constraint with data migration
-- Description: Update existing data and fix payment_method constraint to match application enum values
-- Date: 2024-11-03

-- Step 1: First, let's see what payment method values currently exist
-- (This is for information only - comment out if not needed)
-- SELECT DISTINCT payment_method, COUNT(*)
-- FROM public.orders
-- WHERE payment_method IS NOT NULL
-- GROUP BY payment_method;

-- Step 2: Update existing payment method values to match new enum
-- Map old values to new values
UPDATE public.orders
SET payment_method = CASE
    WHEN payment_method = 'digital_wallet' THEN 'mobilePayment'
    WHEN payment_method = 'bank_transfer' THEN 'bankTransfer'
    WHEN payment_method = 'cash' THEN 'cash'
    WHEN payment_method = 'card' THEN 'card'
    WHEN payment_method = '' THEN 'none'
    WHEN payment_method IS NULL THEN 'none'
    ELSE 'cash'  -- Default fallback for any unexpected values
END
WHERE payment_method IS NOT NULL OR payment_method = '';

-- Step 3: Handle any NULL values
UPDATE public.orders
SET payment_method = 'none'
WHERE payment_method IS NULL;

-- Step 4: Drop existing constraint
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;

-- Step 5: Add new constraint with correct payment method values
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN ('none', 'cash', 'card', 'mobilePayment', 'bankTransfer', 'other'));

-- Step 6: Verify the constraint works by checking all rows comply
-- (This will fail if any rows still violate the constraint)
-- SELECT COUNT(*) FROM public.orders
-- WHERE payment_method NOT IN ('none', 'cash', 'card', 'mobilePayment', 'bankTransfer', 'other');