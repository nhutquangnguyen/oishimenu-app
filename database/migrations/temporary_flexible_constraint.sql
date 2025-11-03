-- Migration: Temporary flexible payment method constraint
-- Description: Allow both old and new payment method values during transition
-- Date: 2024-11-03

-- Step 1: Drop existing constraint
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;

-- Step 2: Add flexible constraint that allows both old and new values
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN (
        -- New enum values (from application) - matching actual enum values
        'none', 'cash', 'card', 'mobile_payment', 'bank_transfer', 'other',
        -- Old enum values (for backward compatibility)
        'mobilePayment', 'bankTransfer', 'digital_wallet'
    ) OR payment_method IS NULL);

-- This allows the application to work immediately while you can gradually
-- migrate data in the background if needed