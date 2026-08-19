-- Migration: Merge 3 inventory tables into 2 tables: items and items_size
-- Run this script in the Supabase SQL Editor.

-- 1. Create the new items_size table
CREATE TABLE IF NOT EXISTS items_size (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    variant_id UUID,
    item_name VARCHAR(255) NOT NULL,
    size VARCHAR(50) NOT NULL,
    stock INT DEFAULT 0,
    cost_price DECIMAL(10, 2) DEFAULT 0.00,
    retail_price DECIMAL(10, 2) DEFAULT 0.00,
    barcode VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create indices for fast lookup by item_id, variant_id, size, and barcode
CREATE INDEX IF NOT EXISTS idx_items_size_item_id ON items_size(item_id);
CREATE INDEX IF NOT EXISTS idx_items_size_variant_id ON items_size(variant_id);
CREATE INDEX IF NOT EXISTS idx_items_size_barcode ON items_size(barcode);

-- 3. Enable Row Level Security (RLS) policies for Supabase
ALTER TABLE items_size ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access on items_size" ON items_size FOR SELECT USING (true);
CREATE POLICY "Allow public write access on items_size" ON items_size FOR ALL USING (true);

-- 4. Data Migration: Copy multi-variant & size records into items_size
INSERT INTO items_size (
    id,
    item_id,
    variant_id,
    item_name,
    size,
    stock,
    cost_price,
    retail_price,
    barcode,
    created_at,
    updated_at
)
SELECT 
    ivs.id,
    iv.item_id,
    ivs.variant_id,
    COALESCE(i.name, 'Item'),
    ivs.size,
    COALESCE(ivs.stock, 0),
    COALESCE(ivs.cost_price, 0.00),
    COALESCE(ivs.retail_price, 0.00),
    ivs.barcode,
    ivs.created_at,
    ivs.updated_at
FROM item_variant_sizes ivs
JOIN item_variants iv ON ivs.variant_id = iv.id
JOIN items i ON iv.item_id = i.id
ON CONFLICT (id) DO NOTHING;

-- 5. Data Migration: Copy single items (without variants) into items_size
INSERT INTO items_size (
    item_id,
    variant_id,
    item_name,
    size,
    stock,
    cost_price,
    retail_price,
    barcode,
    created_at
)
SELECT 
    i.id,
    i.id,
    i.name,
    COALESCE(NULLIF(i.size, ''), 'Standard'),
    COALESCE(i.stock, 0),
    COALESCE(i.price, 0.00),
    COALESCE(i.retail_price, 0.00),
    i.sku,
    i.created_at
FROM items i
WHERE NOT EXISTS (
    SELECT 1 FROM items_size sz WHERE sz.item_id = i.id
);
