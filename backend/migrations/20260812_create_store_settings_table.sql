-- Migration: Create store_settings table to persist store configuration, tax rules, regional & hardware settings
-- Run this script in the Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS store_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID UNIQUE REFERENCES branches(id) ON DELETE CASCADE,
    
    -- 1. Store Details
    store_name VARCHAR(255) DEFAULT 'Smart Store',
    store_address TEXT DEFAULT 'Main Road, Sample City',
    store_phone VARCHAR(50) DEFAULT '+91 9876543210',
    store_gstin VARCHAR(50) DEFAULT '27AAAAA0000A1Z5',
    receipt_tagline TEXT DEFAULT 'Thank you for shopping with us!',
    
    -- 2. Tax & Inventory Rules
    low_stock_threshold DECIMAL(10, 2) DEFAULT 10.0,
    low_stock_alert_enabled BOOLEAN DEFAULT true,
    sgst_percent DECIMAL(5, 2) DEFAULT 0.0,
    cgst_percent DECIMAL(5, 2) DEFAULT 0.0,
    igst_percent DECIMAL(5, 2) DEFAULT 0.0,
    tax_inclusive BOOLEAN DEFAULT false,
    
    -- 3. Currency & Localization
    currency_symbol VARCHAR(10) DEFAULT '₹',
    currency_position VARCHAR(20) DEFAULT 'before',
    date_format VARCHAR(20) DEFAULT 'DD/MM/YYYY',
    
    -- 4. Security
    pin_lock_enabled BOOLEAN DEFAULT false,
    session_timeout_minutes INT DEFAULT 30,
    
    -- 5. Hardware & Printer Configuration
    printer_paper_size VARCHAR(20) DEFAULT '58mm',
    auto_print_receipt BOOLEAN DEFAULT false,
    receipt_header VARCHAR(255) DEFAULT 'SMART STORE POS',
    receipt_footer VARCHAR(255) DEFAULT 'Visit Again!',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Trigger for auto-updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_store_settings_modtime()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_store_settings_modtime ON store_settings;
CREATE TRIGGER trg_update_store_settings_modtime 
BEFORE UPDATE ON store_settings 
FOR EACH ROW EXECUTE PROCEDURE update_store_settings_modtime();

-- RLS Security Policies for Supabase
ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users full access to store_settings" ON store_settings;
CREATE POLICY "Allow authenticated users full access to store_settings"
ON store_settings
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
