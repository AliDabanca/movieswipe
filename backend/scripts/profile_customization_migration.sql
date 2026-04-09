-- ============================================
-- Profile Customization: Cover Photo Presets
-- ============================================

-- Add cover_photo_url to profiles table
-- We store the preset identifier (e.g. 'preset_1' or a hex string) in this column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS cover_photo_url TEXT;

COMMENT ON COLUMN profiles.cover_photo_url IS 'Stores the preset identifier or color code for the profile cover background.';
