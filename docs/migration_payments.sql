-- =============================================================================
-- Migration: Payment Transactions & Merchant UPI Account Settings
-- =============================================================================

-- 1. Extend app_settings with Merchant UPI & Settlement Details
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS merchant_upi_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS upi_display_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS default_payment_method VARCHAR(50) DEFAULT 'Cash',
ADD COLUMN IF NOT EXISTS gateway_provider VARCHAR(50) DEFAULT 'UPI_DIRECT',
ADD COLUMN IF NOT EXISTS gateway_status VARCHAR(50) DEFAULT 'ACTIVE',
ADD COLUMN IF NOT EXISTS account_holder_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS account_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(20),
ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) DEFAULT 'Current';

-- 2. Create Payment Transactions Table
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(50) NOT NULL,
    transaction_ref_id VARCHAR(100) UNIQUE NOT NULL,
    payment_provider VARCHAR(50) NOT NULL DEFAULT 'UPI',
    payment_method VARCHAR(30) NOT NULL DEFAULT 'UPI',
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    payment_status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (
        payment_status IN ('PENDING', 'PROCESSING', 'PAID', 'FAILED', 'CANCELLED')
    ),
    gateway_txn_id VARCHAR(100),
    upi_id VARCHAR(255),
    customer_vpa VARCHAR(255),
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ
);

-- 3. Indexes for fast lookup and reporting
CREATE INDEX IF NOT EXISTS idx_payment_txns_invoice ON public.payment_transactions(invoice_number);
CREATE INDEX IF NOT EXISTS idx_payment_txns_ref ON public.payment_transactions(transaction_ref_id);
CREATE INDEX IF NOT EXISTS idx_payment_txns_status ON public.payment_transactions(payment_status);
CREATE INDEX IF NOT EXISTS idx_payment_txns_created ON public.payment_transactions(created_at DESC);

-- 4. Enable Row Level Security
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read payment_transactions" 
ON public.payment_transactions FOR SELECT 
USING (auth.role() = 'authenticated' OR true);

CREATE POLICY "Allow authenticated insert payment_transactions" 
ON public.payment_transactions FOR INSERT 
WITH CHECK (auth.role() = 'authenticated' OR true);

CREATE POLICY "Allow authenticated update payment_transactions" 
ON public.payment_transactions FOR UPDATE 
USING (auth.role() = 'authenticated' OR true)
WITH CHECK (auth.role() = 'authenticated' OR true);
