-- Migration: Add invoice_number, item_name, and final_amount to sale_items table
-- Run this script in the Supabase SQL Editor.

-- 1. Add missing columns to sale_items table
ALTER TABLE sale_items 
ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(100),
ADD COLUMN IF NOT EXISTS item_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS final_amount NUMERIC;

-- 2. Allow item_id in sale_items to be NULL (for custom line items not in inventory)
ALTER TABLE sale_items ALTER COLUMN item_id DROP NOT NULL;

-- 3. Create indices for fast lookup by invoice_number and sale_id
CREATE INDEX IF NOT EXISTS idx_sale_items_invoice_number ON sale_items(invoice_number);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_item_id ON sale_items(item_id);

-- 4. Backfill existing sale_items rows with data from sales and items tables
UPDATE sale_items si
SET 
  invoice_number = s.invoice_number,
  final_amount = s.final_amount
FROM sales s
WHERE si.sale_id = s.id
  AND (si.invoice_number IS NULL OR si.final_amount IS NULL);

UPDATE sale_items si
SET item_name = i.name
FROM items i
WHERE si.item_id = i.id
  AND (si.item_name IS NULL OR si.item_name = '');

UPDATE sale_items
SET item_name = 'Sale Item'
WHERE item_name IS NULL OR item_name = '';

-- 5. Update create_sale_with_items stored procedure to populate all sale_items fields
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
    v_item_id UUID;
    v_raw_id TEXT;
    v_item_name VARCHAR;
BEGIN
    -- Generate invoice_number fallback if null
    IF p_invoice_number IS NULL OR TRIM(p_invoice_number) = '' THEN
        final_inv_no := 'INV-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 8));
    ELSE
        final_inv_no := p_invoice_number;
    END IF;

    -- Insert into sales table
    INSERT INTO sales (
        branch_id, user_id, invoice_number, user_name, customer_name, customer_phone,
        total_amount, discount, final_amount, payment_method
    ) VALUES (
        p_branch_id, p_user_id, final_inv_no, p_user_name, p_customer_name, p_customer_phone,
        p_total_amount, p_discount, p_final_amount, p_payment_method
    ) RETURNING id INTO new_sale_id;

    -- Iterate and insert each line item into sale_items
    FOR item_record IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_raw_id := item_record.value->>'item_id';
        v_item_id := CASE 
            WHEN v_raw_id IS NOT NULL AND v_raw_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            THEN v_raw_id::UUID 
            ELSE NULL 
        END;

        v_item_name := COALESCE(
            item_record.value->>'item_name', 
            item_record.value->>'name', 
            'Sale Item'
        );

        INSERT INTO sale_items (
            sale_id,
            invoice_number,
            item_id,
            item_name,
            quantity,
            unit_price,
            subtotal,
            final_amount
        ) VALUES (
            new_sale_id,
            final_inv_no,
            v_item_id,
            v_item_name,
            COALESCE((item_record.value->>'quantity')::INT, 1),
            COALESCE((item_record.value->>'unit_price')::DECIMAL, 0),
            COALESCE((item_record.value->>'subtotal')::DECIMAL, 0),
            p_final_amount
        );

        -- Deduct inventory stock if item_id is valid UUID
        IF v_item_id IS NOT NULL THEN
            UPDATE items 
            SET stock = GREATEST(0, stock - COALESCE((item_record.value->>'quantity')::INT, 1))
            WHERE id = v_item_id;
        END IF;
    END LOOP;

    RETURN new_sale_id;
END;
$$ LANGUAGE plpgsql;
