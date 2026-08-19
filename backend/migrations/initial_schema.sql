-- Description: Create initial tables for Smart Dukan application
-- Dialect: PostgreSQL

-- Enable UUID extension if needed (not strictly required for gen_random_uuid() in PG 13+)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. branches
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    contact_phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. users
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'Staff' CHECK (role IN ('Owner', 'Manager', 'Staff')),
    profile_picture_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. suppliers
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    gstin VARCHAR(50),
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    parent_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. items
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100) UNIQUE,
    stock INT DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL,
    retail_price DECIMAL(10, 2) NOT NULL,
    image_url TEXT,
    color VARCHAR(50),
    size VARCHAR(50),
    has_variants BOOLEAN DEFAULT false,
    variants JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. purchases
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    invoice_no VARCHAR(100),
    total_amount DECIMAL(12, 2) NOT NULL,
    payment_mode VARCHAR(50),
    payment_details TEXT,
    status VARCHAR(50),
    purchase_date TIMESTAMP NOT NULL,
    bill_media_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. purchase_items
CREATE TABLE purchase_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL
);

-- 8. sales
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(50),
    total_amount DECIMAL(12, 2) NOT NULL,
    discount DECIMAL(10, 2) DEFAULT 0,
    final_amount DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50),
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. sale_items
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL
);

-- Create simple trigger for updated_at (PostgreSQL specific)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_branches_modtime BEFORE UPDATE ON branches FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_users_modtime BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_suppliers_modtime BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_categories_modtime BEFORE UPDATE ON categories FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_items_modtime BEFORE UPDATE ON items FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_purchases_modtime BEFORE UPDATE ON purchases FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_sales_modtime BEFORE UPDATE ON sales FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- RPC Functions for Transactions
CREATE OR REPLACE FUNCTION create_sale_with_items(
    p_branch_id UUID,
    p_user_id UUID,
    p_customer_name VARCHAR,
    p_customer_phone VARCHAR,
    p_total_amount DECIMAL,
    p_discount DECIMAL,
    p_final_amount DECIMAL,
    p_payment_method VARCHAR,
    p_items JSONB
) RETURNS UUID AS $$
DECLARE
    new_sale_id UUID;
    item_record RECORD;
BEGIN
    INSERT INTO sales (
        branch_id, user_id, customer_name, customer_phone,
        total_amount, discount, final_amount, payment_method
    ) VALUES (
        p_branch_id, p_user_id, p_customer_name, p_customer_phone,
        p_total_amount, p_discount, p_final_amount, p_payment_method
    ) RETURNING id INTO new_sale_id;

    FOR item_record IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO sale_items (
            sale_id, item_id, quantity, unit_price, subtotal
        ) VALUES (
            new_sale_id,
            (item_record.value->>'item_id')::UUID,
            (item_record.value->>'quantity')::INT,
            (item_record.value->>'unit_price')::DECIMAL,
            (item_record.value->>'subtotal')::DECIMAL
        );

        UPDATE items 
        SET stock = stock - (item_record.value->>'quantity')::INT
        WHERE id = (item_record.value->>'item_id')::UUID;
    END LOOP;

    RETURN new_sale_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_purchase_with_items(
    p_branch_id UUID,
    p_supplier_id UUID,
    p_user_id UUID,
    p_invoice_no VARCHAR,
    p_total_amount DECIMAL,
    p_payment_mode VARCHAR,
    p_payment_details TEXT,
    p_status VARCHAR,
    p_purchase_date TIMESTAMP,
    p_bill_media_url TEXT,
    p_items JSONB
) RETURNS UUID AS $$
DECLARE
    new_purchase_id UUID;
    item_record RECORD;
BEGIN
    INSERT INTO purchases (
        branch_id, supplier_id, user_id, invoice_no, total_amount,
        payment_mode, payment_details, status, purchase_date, bill_media_url
    ) VALUES (
        p_branch_id, p_supplier_id, p_user_id, p_invoice_no, p_total_amount,
        p_payment_mode, p_payment_details, p_status, p_purchase_date, p_bill_media_url
    ) RETURNING id INTO new_purchase_id;

    FOR item_record IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO purchase_items (
            purchase_id, item_id, quantity, unit_price, subtotal
        ) VALUES (
            new_purchase_id,
            (item_record.value->>'item_id')::UUID,
            (item_record.value->>'quantity')::INT,
            (item_record.value->>'unit_price')::DECIMAL,
            (item_record.value->>'subtotal')::DECIMAL
        );

        UPDATE items 
        SET stock = stock + (item_record.value->>'quantity')::INT
        WHERE id = (item_record.value->>'item_id')::UUID;
    END LOOP;

    RETURN new_purchase_id;
END;
$$ LANGUAGE plpgsql;

