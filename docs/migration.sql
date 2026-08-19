-- =============================================================================
-- Unified Database Migration Script — Smart Dukan POS & Inventory Management
-- Dialect: PostgreSQL (Supabase Compatible)
-- =============================================================================

-- 0. Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Create Branches Table
-- (Created first as it is referenced by almost all core data tables)
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed initial branches required for default system operations
INSERT INTO public.branches (name, location)
VALUES 
    ('Main Store', 'Primary Retail Showroom'),
    ('Warehouse', 'Central Stock Storage')
ON CONFLICT (name) DO NOTHING;

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

-- Enable Row Level Security (RLS) on users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2b. Create Profiles Table (extends public.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'staff' CHECK (role IN ('owner', 'manager', 'staff')),
    selected_branch VARCHAR(100) DEFAULT 'Main Store' REFERENCES public.branches(name) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS) on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Create User Sessions Table (for active session audit logs)
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_agent TEXT NOT NULL DEFAULT 'Flutter App',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    subcategories JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed initial category catalog structure
INSERT INTO public.categories (name, subcategories)
VALUES 
    ('Men', '["Shirts", "Jeans", "T-Shirts", "Suits", "Trousers"]'::jsonb),
    ('Women', '["Dresses", "Tops", "Skirts", "Ethnic Wear", "Sarees"]'::jsonb),
    ('Kids', '["T-Shirts", "Frocks", "Shorts", "Infant Wear"]'::jsonb),
    ('Accessories', '["Belts", "Wallets", "Bags", "Sunglasses"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

-- 5. Create Inventory/Products Table
CREATE TABLE IF NOT EXISTS public.inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    retail_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (retail_price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    color VARCHAR(50),
    size VARCHAR(20),
    image_url TEXT,
    branch VARCHAR(100) NOT NULL DEFAULT 'Main Store' REFERENCES public.branches(name) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Create Suppliers Table
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(150),
    gstin VARCHAR(15),
    address TEXT,
    branch VARCHAR(100) NOT NULL DEFAULT 'Main Store' REFERENCES public.branches(name) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Create Purchases Table (B2B acquisitions)
CREATE TABLE IF NOT EXISTS public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_number VARCHAR(50) NOT NULL UNIQUE,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    items JSONB NOT NULL, -- Array of items: [{"itemId": "...", "quantity": 10, "costPrice": 150.00}]
    sub_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (sub_total >= 0),
    discount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (grand_total >= 0),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash',
    status VARCHAR(20) NOT NULL DEFAULT 'Received',
    branch VARCHAR(100) NOT NULL DEFAULT 'Main Store' REFERENCES public.branches(name) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Create Sales Table (Retail/POS checkouts)
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    customer_name VARCHAR(100) NOT NULL DEFAULT 'Walk-in Customer',
    customer_phone VARCHAR(20),
    items JSONB NOT NULL, -- Array of items: [{"itemId": "...", "quantity": 2, "price": 450.00, "totalAmount": 900.00}]
    sub_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (sub_total >= 0),
    discount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (grand_total >= 0),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash',
    branch VARCHAR(100) NOT NULL DEFAULT 'Main Store' REFERENCES public.branches(name) ON UPDATE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- ⚡ Performance Optimizing Indexes
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON public.user_sessions(user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_inventory_branch_cat ON public.inventory(branch, category);
CREATE INDEX IF NOT EXISTS idx_suppliers_branch ON public.suppliers(branch);
CREATE INDEX IF NOT EXISTS idx_purchases_branch ON public.purchases(branch);
CREATE INDEX IF NOT EXISTS idx_sales_branch ON public.sales(branch);

-- =============================================================================
-- 🔐 Row Level Security (RLS) Access Policies
-- =============================================================================

-- Profiles Policies
CREATE POLICY "Allow public read access to profiles" 
    ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Users Policies
CREATE POLICY "Allow public read access to users" 
    ON public.users FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own user record" 
    ON public.users FOR UPDATE USING (auth.uid() = id);

-- Branches Policies
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to branches" ON public.branches;
CREATE POLICY "Allow public read access to branches" 
    ON public.branches FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public insert branches" ON public.branches;
CREATE POLICY "Allow public insert branches" 
    ON public.branches FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public update branches" ON public.branches;
CREATE POLICY "Allow public update branches" 
    ON public.branches FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public delete branches" ON public.branches;
CREATE POLICY "Allow public delete branches" 
    ON public.branches FOR DELETE USING (true);

-- Categories Policies
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to categories" 
    ON public.categories FOR SELECT USING (true);
CREATE POLICY "Allow public insert categories" 
    ON public.categories FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update categories" 
    ON public.categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete categories" 
    ON public.categories FOR DELETE USING (true);

-- Inventory Policies
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to inventory" 
    ON public.inventory FOR SELECT USING (true);
CREATE POLICY "Allow public insert inventory" 
    ON public.inventory FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update inventory" 
    ON public.inventory FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete inventory" 
    ON public.inventory FOR DELETE USING (true);

-- Suppliers Policies
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to suppliers" 
    ON public.suppliers FOR SELECT USING (true);
CREATE POLICY "Allow public insert suppliers" 
    ON public.suppliers FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update suppliers" 
    ON public.suppliers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete suppliers" 
    ON public.suppliers FOR DELETE USING (true);

-- Purchases Policies
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to purchases" 
    ON public.purchases FOR SELECT USING (true);
CREATE POLICY "Allow public insert purchases" 
    ON public.purchases FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update purchases" 
    ON public.purchases FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete purchases" 
    ON public.purchases FOR DELETE USING (true);

-- Sales Policies
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to sales" 
    ON public.sales FOR SELECT USING (true);
CREATE POLICY "Allow public insert sales" 
    ON public.sales FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update sales" 
    ON public.sales FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete sales" 
    ON public.sales FOR DELETE USING (true);

-- User Sessions Policies
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to user_sessions" 
    ON public.user_sessions FOR SELECT USING (true);
CREATE POLICY "Allow public insert user_sessions" 
    ON public.user_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update user_sessions" 
    ON public.user_sessions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow public delete user_sessions" 
    ON public.user_sessions FOR DELETE USING (true);

-- =============================================================================
-- ⚙️ Supabase Auth Profile Synchronization Trigger
-- =============================================================================

-- Create the trigger function to insert profile records on auth.users inserts
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into users metadata table first (foreign key dependency)
    INSERT INTO public.users (id, name, email, phone)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'name', 'New User'),
        new.email,
        new.raw_user_meta_data->>'phone'
    );

    -- Insert into profiles
    INSERT INTO public.profiles (id, role, selected_branch)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'role', 'staff'),
        'Main Store'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind the trigger function to the auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
