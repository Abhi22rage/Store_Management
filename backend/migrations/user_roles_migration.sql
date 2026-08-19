-- Migration: Add User Roles (Owner, Manager, Staff) & Auto-Sync Trigger
-- Dialect: PostgreSQL (Supabase)

-- 1. Drop existing constraint if present and add flexible case-insensitive check
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'Staff';

ALTER TABLE public.users 
ADD CONSTRAINT users_role_check 
CHECK (role IS NULL OR LOWER(role) IN ('owner', 'manager', 'staff'));

-- 2. Create function to automatically sync user profile and title-case role on Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    raw_role TEXT;
    normalized_role TEXT;
BEGIN
    raw_role := COALESCE(NEW.raw_user_meta_data->>'role', 'Staff');
    normalized_role := INITCAP(LOWER(raw_role));

    INSERT INTO public.users (id, name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.email,
        normalized_role
    )
    ON CONFLICT (id) DO UPDATE 
    SET 
        role = EXCLUDED.role,
        name = COALESCE(EXCLUDED.name, public.users.name),
        updated_at = CURRENT_TIMESTAMP;
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create Trigger to execute function on new Supabase Auth Signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Sync existing auth users to public.users table (normalizing case)
INSERT INTO public.users (id, name, email, role)
SELECT 
    id,
    COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)),
    email,
    INITCAP(LOWER(COALESCE(raw_user_meta_data->>'role', 'Owner')))
FROM auth.users
ON CONFLICT (id) DO UPDATE 
SET role = EXCLUDED.role;
