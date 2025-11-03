-- Migration: Migrate existing order_payments to transactions table
-- Description: Move existing payment data to the new generalized transactions table
-- Date: 2024-11-03

-- Migrate existing order_payments to transactions table
INSERT INTO public.transactions (
    id,
    transaction_type,
    reference_type,
    reference_id,
    payment_method,
    payment_status,
    amount,
    currency,
    transaction_id,
    category,
    subcategory,
    description,
    notes,
    account_from,
    account_to,
    transaction_time,
    created_at,
    updated_at
)
SELECT
    op.id,
    'REVENUE' as transaction_type,
    'ORDER' as reference_type,
    op.order_id as reference_id,
    op.payment_method,
    op.payment_status,
    op.amount_paid as amount,
    'VND' as currency,
    op.transaction_id,
    'food_sales' as category,
    'order_payment' as subcategory,
    CONCAT('Payment for order ', o.order_number) as description,
    op.notes,
    CASE op.payment_method
        WHEN 'cash' THEN 'customer_cash'
        WHEN 'card' THEN 'customer_card'
        WHEN 'mobile_payment' THEN 'customer_mobile'
        WHEN 'bank_transfer' THEN 'customer_bank'
        ELSE 'customer_other'
    END as account_from,
    'revenue_food_sales' as account_to,
    COALESCE(op.payment_time, op.created_at) as transaction_time,
    op.created_at,
    op.updated_at
FROM public.order_payments op
LEFT JOIN public.orders o ON op.order_id = o.id
WHERE NOT EXISTS (
    -- Avoid duplicates if migration is run multiple times
    SELECT 1 FROM public.transactions t
    WHERE t.id = op.id
);

-- Create a view for backward compatibility with order_payments
CREATE OR REPLACE VIEW public.order_payments_view AS
SELECT
    t.id,
    t.reference_id as order_id,
    t.payment_method,
    t.payment_status,
    t.amount as amount_paid,
    t.amount as total_amount, -- For backward compatibility, may need adjustment
    t.transaction_id,
    t.notes,
    t.transaction_time as payment_time,
    t.created_at,
    t.updated_at
FROM public.transactions t
WHERE t.transaction_type = 'REVENUE'
  AND t.reference_type = 'ORDER'
  AND t.reference_id IS NOT NULL;

-- Add comment
COMMENT ON VIEW public.order_payments_view IS 'Backward compatibility view for existing order_payments usage';

-- Grant permissions on the view
GRANT SELECT ON public.order_payments_view TO authenticated;