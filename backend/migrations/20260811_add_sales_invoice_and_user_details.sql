-- Migration: Add invoice_number and user_name to sales table
-- Run this script in the Supabase SQL Editor.

-- 1. Add missing columns to sales table
ALTER TABLE sales 
ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(100),
ADD COLUMN IF NOT EXISTS user_name VARCHAR(150);

-- 2. Backfill invoice_number for existing sales rows that have NULL or empty invoice_number
UPDATE sales 
SET invoice_number = 'INV-' || UPPER(SUBSTRING(id::text FROM 1 FOR 8))
WHERE invoice_number IS NULL OR invoice_number = '';

-- 3. Create index for fast invoice search & user lookup
CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON sales(invoice_number);
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);

-- 4. Update create_sale_with_items stored procedure to support invoice_number and user_name
CREATE OR REPLACE FUNCTION create_sale_with_items(
    p_branch_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_invoice_number VARCHAR DEFAULT NULL,
    p_user_name VARCHAR DEFAULT NULL,
    p_customer_name VARCHAR DEFAULT 'Walk-in Customer',
    p_customer_phone VARCHAR DEFAULT '',
    p_total_amount DECIMAL DEFAULT 0,
    p_discount DECIMAL DEFAULT 0,
    p_final_amount DECIMAL DEFAULT 0,
    p_payment_method VARCHAR DEFAULT 'Cash',
    p_items JSONB DEFAULT '[]'::jsonb
) RETURNS UUID AS $$
DECLARE
    new_sale_id UUID;
    item_record RECORD;
    final_inv_no VARCHAR;
BEGIN
    -- Generate invoice_number fallback if null
    IF p_invoice_number IS NULL OR TRIM(p_invoice_number) = '' THEN
        final_inv_no := 'INV-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 8));
    ELSE
        final_inv_no := p_invoice_number;
    END IF;

    INSERT INTO sales (
        branch_id, user_id, invoice_number, user_name, customer_name, customer_phone,
        total_amount, discount, final_amount, payment_method
    ) VALUES (
        p_branch_id, p_user_id, final_inv_no, p_user_name, p_customer_name, p_customer_phone,
        p_total_amount, p_discount, p_final_amount, p_payment_method
    ) RETURNING id INTO new_sale_id;

    FOR item_record IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        IF item_record.value->>'item_id' IS NOT NULL THEN
            INSERT INTO sale_items (
                sale_id, item_id, quantity, unit_price, subtotal
            ) VALUES (
                new_sale_id,
                (item_record.value->>'item_id')::UUID,
                COALESCE((item_record.value->>'quantity')::INT, 1),
                COALESCE((item_record.value->>'unit_price')::DECIMAL, 0),
                COALESCE((item_record.value->>'subtotal')::DECIMAL, 0)
            );

            UPDATE items 
            SET stock = GREATEST(0, stock - COALESCE((item_record.value->>'quantity')::INT, 1))
            WHERE id = (item_record.value->>'item_id')::UUID;
        END IF;
    END LOOP;

    RETURN new_sale_id;
END;
$$ LANGUAGE plpgsql;
