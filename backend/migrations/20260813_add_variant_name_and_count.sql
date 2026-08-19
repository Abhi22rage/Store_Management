-- Migration: Add variant_name to items_size table with DEFAULT NULL, and variants_count to items table
-- Run this script in the Supabase SQL Editor.

-- 1. Add variant_name column to items_size table with DEFAULT NULL (if not exists)
ALTER TABLE items_size 
ADD COLUMN IF NOT EXISTS variant_name VARCHAR(100) DEFAULT NULL;

-- 2. Set default of variant_name column to NULL
ALTER TABLE items_size 
ALTER COLUMN variant_name SET DEFAULT NULL;

-- 3. Update EXISTING rows in items_size where variant_name is 'Default' or empty to NULL
UPDATE items_size 
SET variant_name = NULL 
WHERE variant_name = 'Default' OR TRIM(variant_name) = '';

-- 4. Copy color from master items table if variant_name is NULL and items.color exists
UPDATE items_size sz
SET variant_name = NULLIF(TRIM(i.color), '')
FROM items i
WHERE sz.item_id = i.id 
  AND sz.variant_name IS NULL 
  AND i.color IS NOT NULL 
  AND TRIM(i.color) != '';

-- 5. Add variants_count column to items table
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS variants_count INT DEFAULT 1;

-- 6. Backfill variants_count for existing items
UPDATE items i
SET variants_count = COALESCE((
    SELECT COUNT(DISTINCT COALESCE(variant_id, id)) 
    FROM items_size sz 
    WHERE sz.item_id = i.id
), 1);
