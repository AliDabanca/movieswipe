-- ============================================
-- Profiles Table Migration
-- ============================================
-- Run in Supabase Dashboard → SQL Editor
-- ============================================

-- Step 1: Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),

    -- Username: 3-20 chars, alphanumeric only
    CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9]{3,20}$')
);

-- Step 2: Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read any profile (for displaying usernames)
CREATE POLICY "Profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can create their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Step 3: Function to check if username is available
CREATE OR REPLACE FUNCTION check_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT NOT EXISTS (
        SELECT 1 FROM profiles WHERE username = p_username
    );
$$;
