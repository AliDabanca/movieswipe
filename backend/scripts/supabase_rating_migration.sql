-- Migration script for 5-Star Rating System
-- Run this in the Supabase SQL Editor

-- 1. Add the rating column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'user_swipes' AND COLUMN_NAME = 'rating') THEN
        ALTER TABLE user_swipes ADD COLUMN rating INTEGER CHECK (rating >= 1 AND rating <= 5);
    END IF;
END $$;

-- 2. Reload the schema cache for PostgREST
-- This is CRITICAL for Supabase to see the new column immediately
NOTIFY pgrst, 'reload schema';

-- Verification
-- SELECT * FROM user_swipes LIMIT 1;
