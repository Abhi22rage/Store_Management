-- 0. Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- 1. Create Branches Table
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    location TEXT,
    contact_num varchar(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
-- Seed initial branches required for default system operations
INSERT INTO public.branches (name, location)
VALUES ('Main Store', 'Primary Retail Showroom'),
    ('Warehouse', 'Central Stock Storage') ON CONFLICT (name) DO NOTHING;
-- 2. Create Users Table (for extra user metadata)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    profile_picture_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
-- 2b. Create Profiles Table (extends public.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    role VARCHAR(255) NOT NULL DEFAULT 'Staff' CHECK (role IN ('Owner', 'Manager', 'Staff')),
    selected_branch_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_profile_branch FOREIGN KEY (selected_branch_id) REFERENCES branches(id) ON UPDATE CASCADE
);
-- Enable Row Level Security (RLS) on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
-- 3. Create User Sessions Table (for active session audit logs)
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
-- 4. Create Suppliers Table
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(150),
    address text,
    gstin VARCHAR(15),
    status varchar(50) not null default 'Active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
-- 5. Create Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    subcategories JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
-- 6. Create Items Table
CREATE TABLE public.items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL,
    supplier_id UUID,
    supplier_name VARCHAR(255),
    category_id UUID NOT NULL,
    category_name VARCHAR(255),
    item_name VARCHAR(255) NOT NULL,
    variant_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    variant_name VARCHAR(100),
    image_url TEXT,
    variants_count INTEGER DEFAULT 0,
    purchase_date TIMESTAMPTZ,
    stock_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_items_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
    CONSTRAINT fk_items_category FOREIGN KEY (category_id) REFERENCES categories(id),
    CONSTRAINT fk_items_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);
-- 7. Create Item Sizes/Inventory Table
CREATE TABLE public.item_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL,
    variant_id UUID NOT NULL,
    category_name VARCHAR(255),
    item_name VARCHAR(255),
    variant_name VARCHAR(255),
    size VARCHAR(100) NOT NULL,
    stock INTEGER DEFAULT 0,
    cost_price NUMERIC(12, 2) NOT NULL,
    retail_price NUMERIC(12, 2) NOT NULL,
    barcode VARCHAR(255) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_item_inv_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_inv_variant FOREIGN KEY (variant_id) REFERENCES items(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_inv_category FOREIGN KEY (category_name) REFERENCES categories(name),
    CONSTRAINT uq_item_inv_variant_size UNIQUE (item_id, variant_id, size)
);
-- 8. Create Purchases Table (B2B acquisitions)
CREATE TABLE public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    order_no VARCHAR(100) UNIQUE NOT NULL,
    purchase_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sub_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    due_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    payment_mode VARCHAR(50),
    payment_details TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
    bill_media_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_purchases_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_purchases_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
    CONSTRAINT fk_purchases_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);
-- 9. Create Purchases items Table
CREATE TABLE public.purchased_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_no VARCHAR(100),
    item_id UUID NOT NULL,
    item_name VARCHAR(255),
    size VARCHAR(100),
    quantity INTEGER NOT NULL DEFAULT 0,
    cost_price NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_purchased_items_item FOREIGN KEY (item_id) REFERENCES item_inventory(id) ON DELETE CASCADE,
    CONSTRAINT fk_purchased_items_invoice FOREIGN KEY (order_no) REFERENCES purchases(order_no) ON DELETE CASCADE
);
-- 10. Create Sales Table (Retail/POS checkouts)
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL,
    user_id UUID NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    total_items INTEGER NOT NULL DEFAULT 0,
    sub_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (sub_total >= 0),
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (grand_total >= 0),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash' CHECK (payment_method IN ('Cash', 'UPI', 'Card')),
    payment_status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (
        payment_status IN ('PENDING', 'PAID', 'PARTIALLY PAID', 'REFUNDED')
    ),
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    due_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT fk_sales_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_sales_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
);
-- 11. Create Sales Items Table
CREATE TABLE public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(50) NOT NULL,
    item_id UUID NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT fk_sale_items_invoice FOREIGN KEY (invoice_number) REFERENCES sales(invoice_number),
    CONSTRAINT fk_sale_items_item FOREIGN KEY (item_id) REFERENCES item_inventory(id)
);
-- 12. App settings Table
CREATE TABLE public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL,
    store_name VARCHAR(150) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    gstin VARCHAR(15),
    low_stock_threshold INT NOT NULL DEFAULT 5,
    low_stock_alert BOOLEAN NOT NULL DEFAULT TRUE,
    sgst_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    cgst_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    igst_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    tax_inclusive BOOLEAN NOT NULL DEFAULT TRUE,
    currency_symbol VARCHAR(10) NOT NULL DEFAULT '₹',
    date_format VARCHAR(30) NOT NULL DEFAULT 'DD-MM-YYYY',
    pin_lock_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    receipt_tagline VARCHAR(255),
    receipt_header TEXT,
    receipt_footer TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_app_settings_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    CONSTRAINT uq_app_settings_branch UNIQUE (branch_id),
    CONSTRAINT chk_low_stock_threshold CHECK (low_stock_threshold >= 0),
    CONSTRAINT chk_sgst_percent CHECK (
        sgst_percent >= 0
        AND sgst_percent <= 50
    ),
    CONSTRAINT chk_cgst_percent CHECK (
        cgst_percent >= 0
        AND cgst_percent <= 50
    ),
    CONSTRAINT chk_igst_percent CHECK (
        igst_percent >= 0
        AND igst_percent <= 50
    )
);
-- =============================================================================
-- ⚡ Performance Optimizing Indexes
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_item_inventory_branch_cat ON public.items(branch_id, category_id);
CREATE INDEX IF NOT EXISTS idx_purchases_branch ON public.purchases(branch_id);
CREATE INDEX IF NOT EXISTS idx_sales_branch ON public.sales(branch_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(id);
CREATE INDEX IF NOT EXISTS idx_sale_items_item_id ON sale_items(item_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_invoice_no ON sale_items(invoice_number);
CREATE INDEX IF NOT EXISTS idx_purchased_items_purchase_id ON purchased_items(id);
CREATE INDEX IF NOT EXISTS idx_purchased_items_item_id ON purchased_items(item_id);
CREATE INDEX IF NOT EXISTS idx_purchased_items_order_no ON purchased_items(order_no);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_items_branch_id ON items(branch_id);
CREATE INDEX IF NOT EXISTS idx_items_category_id ON items(category_id);
CREATE INDEX IF NOT EXISTS idx_items_supplier_id ON items(supplier_id);
CREATE INDEX IF NOT EXISTS idx_item_inventory_item_id ON item_inventory(item_id);
CREATE INDEX IF NOT EXISTS idx_item_inventory_variant_id ON item_inventory(variant_id);
CREATE INDEX IF NOT EXISTS idx_item_inventory_size ON item_inventory(size);
CREATE INDEX IF NOT EXISTS idx_purchased_items_item_id ON purchased_items(item_id);
CREATE INDEX IF NOT EXISTS idx_purchased_items_order_no ON purchased_items(order_no);
-- =============================================================================
-- 🔐 Row Level Security (RLS) Access Policies
-- =============================================================================
-- function to find user roles
CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS TEXT LANGUAGE SQL SECURITY DEFINER STABLE
SET search_path = public AS $$
SELECT role::TEXT
FROM public.profiles
WHERE id = auth.uid()
LIMIT 1;
$$;
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchased_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
-- Profiles Policies
CREATE POLICY "Allow users to read their own profile" ON public.profiles FOR
SELECT USING (auth.uid() = id);
CREATE POLICY "Allow users to update their own profile" ON public.profiles FOR
UPDATE USING (auth.uid() = id);
REVOKE
UPDATE ON public.profiles
FROM authenticated;
GRANT UPDATE (selected_branch_id) ON public.profiles TO authenticated;
-- Users Policies
CREATE POLICY "Allow users to read their own user record" ON public.users FOR
SELECT USING (auth.uid() = id);
CREATE POLICY "Allow users to update their own user record" ON public.users FOR
UPDATE USING (auth.uid() = id);
REVOKE
UPDATE ON public.users
FROM authenticated;
GRANT UPDATE (name, phone, profile_picture_url) ON public.users TO authenticated;
-- Branches Policies
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "branches_select_authenticated" ON public.branches FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "branches_insert_management" ON public.branches FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "branches_update_management" ON public.branches FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "branches_delete_management" ON public.branches FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- Categories Policies
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_select_authenticated" ON public.categories FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "categories_insert_management" ON public.categories FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "categories_update_management" ON public.categories FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "categories_delete_management" ON public.categories FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
--Items Policies
CREATE POLICY "items_select_authenticated" ON public.items FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "items_insert_management" ON public.items FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "items_update_management" ON public.items FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "items_delete_management" ON public.items FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- Item Inventory Policies
CREATE POLICY "item_inventory_select_authenticated" ON public.item_inventory FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "item_inventory_insert_management" ON public.item_inventory FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "item_inventory_update_management" ON public.item_inventory FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "item_inventory_delete_management" ON public.item_inventory FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- Suppliers Policies
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "suppliers_select_authenticated" ON public.suppliers FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "suppliers_insert_management" ON public.suppliers FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "suppliers_update_management" ON public.suppliers FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "suppliers_delete_management" ON public.suppliers FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- Purchases Policies
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purchases_select_authenticated" ON public.purchases FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "purchases_insert_management" ON public.purchases FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "purchases_update_management" ON public.purchases FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "purchases_delete_management" ON public.purchases FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- Sales Policies
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to sales" ON public.sales FOR
SELECT USING (true);
CREATE POLICY "Allow public insert sales" ON public.sales FOR
INSERT WITH CHECK (true);
CREATE POLICY "Allow public update sales" ON public.sales FOR
UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete sales" ON public.sales FOR DELETE USING (true);
-- User Sessions Policies
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to user_sessions" ON public.user_sessions FOR
SELECT USING (true);
CREATE POLICY "Allow public insert user_sessions" ON public.user_sessions FOR
INSERT WITH CHECK (true);
CREATE POLICY "Allow public update user_sessions" ON public.user_sessions FOR
UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete user_sessions" ON public.user_sessions FOR DELETE USING (true);
-- App Settings Policies
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_settings_select_authenticated" ON public.app_settings FOR
SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "app_settings_insert_management" ON public.app_settings FOR
INSERT WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "app_settings_update_management" ON public.app_settings FOR
UPDATE USING (
        public.current_user_role() IN ('Owner', 'Manager')
    ) WITH CHECK (
        public.current_user_role() IN ('Owner', 'Manager')
    );
CREATE POLICY "app_settings_delete_management" ON public.app_settings FOR DELETE USING (
    public.current_user_role() IN ('Owner', 'Manager')
);
-- =============================================================================
-- ⚙️ Supabase Auth Profile Synchronization Trigger
-- =============================================================================
-- Create the trigger function to insert profile records on auth.users inserts
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$ BEGIN
INSERT INTO public.users (id, name, email, phone)
VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'name', 'New User'),
        new.email,
        new.raw_user_meta_data->>'phone'
    );
INSERT INTO public.profiles (id, role, selected_branch_id)
VALUES (new.id, 'Staff', 'Main Store');
RETURN NEW;
END;
$$;
-- Bind the trigger function to the auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER
INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
-- Trigger function to check roles of users
CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS TEXT LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public AS $$
SELECT role
FROM public.profiles
WHERE id = auth.uid();
$$;
-- Trigger to decrement stock on the staff member's sale.
CREATE OR REPLACE FUNCTION public.decrement_stock_on_sale() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE current_stock INTEGER;
BEGIN
SELECT stock INTO current_stock
FROM public.item_inventory
WHERE id = NEW.item_id FOR
UPDATE;
-- locks the row so two simultaneous sales can't both oversell it
IF current_stock IS NULL THEN RAISE EXCEPTION 'No inventory row found for item_id %',
NEW.item_id;
END IF;
IF current_stock < NEW.quantity THEN RAISE EXCEPTION 'Insufficient stock for item_id % (have %, need %)',
NEW.item_id,
current_stock,
NEW.quantity;
END IF;
UPDATE public.item_inventory
SET stock = stock - NEW.quantity,
    updated_at = NOW()
WHERE id = NEW.item_id;
RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_decrement_stock_on_sale ON public.sale_items;
CREATE TRIGGER trg_decrement_stock_on_sale
AFTER
INSERT ON public.sale_items FOR EACH ROW EXECUTE FUNCTION public.decrement_stock_on_sale();
-- Trigger to increment stock on purchase
CREATE OR REPLACE FUNCTION public.increment_stock_on_purchase() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$ BEGIN
UPDATE public.item_inventory
SET stock = stock + NEW.quantity,
    updated_at = NOW()
WHERE id = NEW.item_id;
IF NOT FOUND THEN RAISE EXCEPTION 'No inventory row found for item_id %',
NEW.item_id;
END IF;
RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_increment_stock_on_purchase ON public.purchased_items;
CREATE TRIGGER trg_increment_stock_on_purchase
AFTER
INSERT ON public.purchased_items FOR EACH ROW EXECUTE FUNCTION public.increment_stock_on_purchase();