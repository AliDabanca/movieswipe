-- ============================================
-- Profile Enhancements Migration
-- ============================================

-- Step 1: Add new columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS pinned_movie_ids INTEGER[] DEFAULT '{}';

-- Step 2: Update RLS (already enabled, but ensure update is possible)
-- (Existing policies from supabase_profiles_migration.sql should cover this)
