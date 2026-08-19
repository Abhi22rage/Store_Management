-- Migration: Add purchase_date, stock_updated_at, category_name, and supplier_name to items table
-- Run this script in the Supabase SQL Editor.

-- 1. Add missing metadata columns to items table (excluding price columns which are stored in items_size)
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS purchase_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS stock_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS category_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS supplier_name VARCHAR(150);

-- 2. Backfill stock_updated_at and purchase_date for existing items
UPDATE items 
SET 
  stock_updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP),
  purchase_date = COALESCE(created_at, CURRENT_TIMESTAMP)
WHERE stock_updated_at IS NULL OR purchase_date IS NULL;

-- 3. Backfill category_name from categories table
UPDATE items i
SET category_name = c.name
FROM categories c
WHERE i.category_id = c.id
  AND (i.category_name IS NULL OR i.category_name = '');

-- 4. Backfill supplier_name from suppliers table
UPDATE items i
SET supplier_name = s.name
FROM suppliers s
WHERE i.supplier_id = s.id
  AND (i.supplier_name IS NULL OR i.supplier_name = '');

-- 5. Create index for fast date sorting and supplier/category queries
CREATE INDEX IF NOT EXISTS idx_items_purchase_date ON items(purchase_date);
CREATE INDEX IF NOT EXISTS idx_items_stock_updated_at ON items(stock_updated_at);
CREATE INDEX IF NOT EXISTS idx_items_supplier_id ON items(supplier_id);
