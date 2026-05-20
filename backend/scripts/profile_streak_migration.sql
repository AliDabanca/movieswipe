-- ============================================
-- Profile Streak Migration
-- ============================================
-- Run this in your Supabase Dashboard -> SQL Editor
-- ============================================

-- Step 1: Add streak columns to the profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS current_streak INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS best_streak INTEGER DEFAULT 0;

-- Step 2: Comment on columns for documentation
COMMENT ON COLUMN profiles.current_streak IS 'The user''s current consecutive daily swipe streak.';
COMMENT ON COLUMN profiles.best_streak IS 'The user''s all-time highest daily swipe streak.';
