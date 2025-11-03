-- Migration: Remove payment_method column from orders table
-- Description: Migrate to using order_payments table for payment tracking
-- Date: 2024-11-03

-- Step 1: Drop the payment method constraint first
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;

-- Step 2: Remove the payment_method column from orders table
ALTER TABLE public.orders DROP COLUMN IF EXISTS payment_method;

-- Note: payment_status column is kept as it represents the overall payment status
-- while individual payments are tracked in order_payments table