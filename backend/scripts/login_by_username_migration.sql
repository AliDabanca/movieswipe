-- ============================================
-- Get Email from Username RPC
-- ============================================
-- Resolve username to email for login
-- SECURITY DEFINER allows access to auth.users schema
-- ============================================

CREATE OR REPLACE FUNCTION get_email_from_username(p_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER -- Required to read auth.users table
AS $$
DECLARE
    v_email TEXT;
BEGIN
    SELECT au.email INTO v_email
    FROM profiles p
    JOIN auth.users au ON p.id = au.id
    WHERE p.username = p_username;

    RETURN v_email;
END;
$$;
