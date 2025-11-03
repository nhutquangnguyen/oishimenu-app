-- Migration: Create generalized transactions table
-- Description: Create unified table for all financial transactions (orders, expenses, adjustments, etc.)
-- Date: 2024-11-03

-- Create transactions table (generalized from order_payments)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Transaction classification
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('REVENUE', 'EXPENSE', 'ADJUSTMENT', 'TRANSFER', 'FEE')),
    reference_type TEXT CHECK (reference_type IN ('ORDER', 'SUPPLIER', 'EMPLOYEE', 'CUSTOMER', 'SYSTEM', 'MANUAL')),
    reference_id UUID, -- Can link to orders, suppliers, employees, etc.

    -- Payment details (inherited from order_payments structure)
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'mobile_payment', 'bank_transfer', 'other')),
    payment_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'PARTIALLY_PAID')),

    -- Financial details
    amount DECIMAL(12,2) NOT NULL, -- Can be negative for expenses/refunds
    currency TEXT DEFAULT 'VND',

    -- External references
    transaction_id TEXT, -- External payment processor ID
    batch_id UUID, -- For grouping related transactions

    -- Categorization for finance reporting
    category TEXT, -- 'food_sales', 'rent', 'utilities', 'refund', 'wages', etc.
    subcategory TEXT, -- More specific categorization
    description TEXT,
    notes TEXT,

    -- Accounting (for future double-entry bookkeeping)
    account_from TEXT, -- Source account ('cash_register', 'bank_account', 'customer', etc.)
    account_to TEXT, -- Destination account ('revenue', 'expense_food', 'expense_rent', etc.)

    -- Timestamps
    transaction_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for optimal performance
CREATE INDEX IF NOT EXISTS idx_transactions_type_status ON public.transactions(transaction_type, payment_status);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON public.transactions(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_method ON public.transactions(payment_method);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON public.transactions(category, subcategory);
CREATE INDEX IF NOT EXISTS idx_transactions_time ON public.transactions(transaction_time);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_batch ON public.transactions(batch_id) WHERE batch_id IS NOT NULL;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_transactions_updated_at
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_transactions_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Allow all operations for authenticated users" ON public.transactions
    FOR ALL USING (auth.role() = 'authenticated');

-- Grant permissions to authenticated users
GRANT ALL ON public.transactions TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.transactions IS 'Unified table for all financial transactions (revenue, expenses, adjustments, transfers, fees)';
COMMENT ON COLUMN public.transactions.id IS 'Unique identifier for the transaction';
COMMENT ON COLUMN public.transactions.transaction_type IS 'Type of transaction (REVENUE, EXPENSE, ADJUSTMENT, TRANSFER, FEE)';
COMMENT ON COLUMN public.transactions.reference_type IS 'Type of entity this transaction references (ORDER, SUPPLIER, EMPLOYEE, etc.)';
COMMENT ON COLUMN public.transactions.reference_id IS 'Foreign key to the referenced entity';
COMMENT ON COLUMN public.transactions.payment_method IS 'Method used for payment (cash, card, etc.)';
COMMENT ON COLUMN public.transactions.payment_status IS 'Status of this transaction';
COMMENT ON COLUMN public.transactions.amount IS 'Transaction amount (positive for income, negative for expenses)';
COMMENT ON COLUMN public.transactions.currency IS 'Currency code (default VND)';
COMMENT ON COLUMN public.transactions.transaction_id IS 'External transaction reference ID from payment processors';
COMMENT ON COLUMN public.transactions.batch_id IS 'Groups related transactions together';
COMMENT ON COLUMN public.transactions.category IS 'High-level category for reporting';
COMMENT ON COLUMN public.transactions.subcategory IS 'Detailed subcategory for analysis';
COMMENT ON COLUMN public.transactions.description IS 'Human-readable description of the transaction';
COMMENT ON COLUMN public.transactions.account_from IS 'Source account for double-entry bookkeeping';
COMMENT ON COLUMN public.transactions.account_to IS 'Destination account for double-entry bookkeeping';
COMMENT ON COLUMN public.transactions.transaction_time IS 'When the transaction actually occurred';
COMMENT ON COLUMN public.transactions.created_at IS 'When this record was created';
COMMENT ON COLUMN public.transactions.updated_at IS 'When this record was last updated';