-- Migration: Relational Schema for Multi-Variant & Multi-Size Inventory Items
-- Dialect: PostgreSQL (Supabase)

-- 1. Create table for item color variants
CREATE TABLE IF NOT EXISTS item_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    color VARCHAR(100) NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create table for size matrix stock, prices, and barcodes
CREATE TABLE IF NOT EXISTS item_variant_sizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id UUID NOT NULL REFERENCES item_variants(id) ON DELETE CASCADE,
    size VARCHAR(50) NOT NULL,
    stock INT DEFAULT 0,
    cost_price DECIMAL(10, 2) DEFAULT 0.00,
    retail_price DECIMAL(10, 2) DEFAULT 0.00,
    barcode VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create Indexes for High Performance Queries & Barcode Searching
CREATE INDEX IF NOT EXISTS idx_item_variants_item_id ON item_variants(item_id);
CREATE INDEX IF NOT EXISTS idx_item_variant_sizes_variant_id ON item_variant_sizes(variant_id);
CREATE INDEX IF NOT EXISTS idx_item_variant_sizes_barcode ON item_variant_sizes(barcode);

-- 4. Enable Row Level Security (RLS) policies for Supabase
ALTER TABLE item_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_variant_sizes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on item_variants" ON item_variants FOR SELECT USING (true);
CREATE POLICY "Allow public write access on item_variants" ON item_variants FOR ALL USING (true);

CREATE POLICY "Allow public read access on item_variant_sizes" ON item_variant_sizes FOR SELECT USING (true);
CREATE POLICY "Allow public write access on item_variant_sizes" ON item_variant_sizes FOR ALL USING (true);

-- 5. Data Migration: Copy existing JSON matrix data into relational tables
DO $$
DECLARE
    item_rec RECORD;
    var_elem JSONB;
    size_elem JSONB;
    new_variant_id UUID;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'items' AND column_name = 'variants'
    ) THEN
        FOR item_rec IN SELECT id, variants FROM items WHERE has_variants = true AND variants IS NOT NULL AND jsonb_array_length(variants) > 0 LOOP
            FOR var_elem IN SELECT * FROM jsonb_array_elements(item_rec.variants) LOOP
                INSERT INTO item_variants (item_id, color, image_url)
                VALUES (
                    item_rec.id, 
                    COALESCE(var_elem->>'color', var_elem->>'name', 'Default'), 
                    COALESCE(var_elem->>'image_url', var_elem->>'imageUrl', '')
                )
                RETURNING id INTO new_variant_id;

                IF var_elem->'sizes' IS NOT NULL THEN
                    FOR size_elem IN SELECT * FROM jsonb_array_elements(var_elem->'sizes') LOOP
                        INSERT INTO item_variant_sizes (variant_id, size, stock, cost_price, retail_price, barcode)
                        VALUES (
                            new_variant_id,
                            COALESCE(size_elem->>'size', ''),
                            COALESCE((size_elem->>'stock')::INT, 0),
                            COALESCE((size_elem->>'cost_price')::DECIMAL, (size_elem->>'costPrice')::DECIMAL, 0.00),
                            COALESCE((size_elem->>'retail_price')::DECIMAL, (size_elem->>'retailPrice')::DECIMAL, 0.00),
                            COALESCE(size_elem->>'barcode', '')
                        );
                    END LOOP;
                END IF;
            END LOOP;
        END LOOP;
    END IF;
END $$;
