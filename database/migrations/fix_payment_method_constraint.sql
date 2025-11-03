-- Migration: Fix payment method constraint mismatch
-- Description: Update orders table payment_method constraint to match application enum values
-- Date: 2024-11-03

-- Drop existing constraint
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;

-- Add new constraint with correct payment method values
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IN ('none', 'cash', 'card', 'mobilePayment', 'bankTransfer', 'other') OR payment_method IS NULL);

-- Note: The constraint allows NULL values to maintain backward compatibility with existing records