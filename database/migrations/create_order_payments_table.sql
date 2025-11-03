-- Migration: Create order_payments table
-- Description: Create table to track payment records for orders
-- Date: 2024-11-03

-- Create order_payments table
CREATE TABLE IF NOT EXISTS public.order_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'mobile_payment', 'bank_transfer', 'other')),
    payment_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'PARTIALLY_PAID')),
    amount_paid DECIMAL(10,2) NOT NULL CHECK (amount_paid >= 0),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    transaction_id TEXT,
    notes TEXT,
    payment_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign key constraint
    CONSTRAINT fk_order_payments_order_id
        FOREIGN KEY (order_id)
        REFERENCES public.orders(id)
        ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_order_payments_order_id ON public.order_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_payment_method ON public.order_payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_order_payments_payment_status ON public.order_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_order_payments_payment_time ON public.order_payments(payment_time);
CREATE INDEX IF NOT EXISTS idx_order_payments_created_at ON public.order_payments(created_at);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_order_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_order_payments_updated_at
    BEFORE UPDATE ON public.order_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_order_payments_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (adjust based on your authentication requirements)
-- Allow all operations for authenticated users (you may want to refine this)
CREATE POLICY "Allow all operations for authenticated users" ON public.order_payments
    FOR ALL USING (auth.role() = 'authenticated');

-- Grant permissions to authenticated users
GRANT ALL ON public.order_payments TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.order_payments IS 'Payment records for orders';
COMMENT ON COLUMN public.order_payments.id IS 'Unique identifier for the payment record';
COMMENT ON COLUMN public.order_payments.order_id IS 'Foreign key reference to orders table';
COMMENT ON COLUMN public.order_payments.payment_method IS 'Method used for payment (cash, card, etc.)';
COMMENT ON COLUMN public.order_payments.amount IS 'Amount paid in this transaction';
COMMENT ON COLUMN public.order_payments.payment_status IS 'Status of this payment';
COMMENT ON COLUMN public.order_payments.transaction_id IS 'External transaction reference ID';
COMMENT ON COLUMN public.order_payments.notes IS 'Additional notes about the payment';
COMMENT ON COLUMN public.order_payments.payment_time IS 'When the payment was made';
COMMENT ON COLUMN public.order_payments.created_at IS 'When this record was created';
COMMENT ON COLUMN public.order_payments.updated_at IS 'When this record was last updated';