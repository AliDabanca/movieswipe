-- ============================================
-- FIX: Profiles Table RLS Policies
-- ============================================
-- Run in Supabase Dashboard → SQL Editor
-- 
-- Problem: "new row violates row-level security 
--           policy for table profiles"
-- Root cause: INSERT policy missing or broken
-- ============================================

-- Step 1: Drop ALL existing policies to start clean
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;
DROP POLICY IF EXISTS "Enable update for users based on id" ON profiles;

-- Step 2: Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Step 3: Recreate all policies
-- SELECT: Anyone can read profiles (for displaying usernames)
CREATE POLICY "Profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

-- INSERT: Authenticated users can create their OWN profile only
CREATE POLICY "Users can create their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their OWN profile only
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Step 4: Verify policies
SELECT policyname, cmd, permissive, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles';
