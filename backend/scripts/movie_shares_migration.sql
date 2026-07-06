-- Migration: Direct Movie Sharing and DM Streaks
-- Executed by copying and pasting into Supabase Dashboard SQL Editor

-- 1. Create movie_shares table
CREATE TABLE IF NOT EXISTS movie_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    movie_id INTEGER REFERENCES movies(id) ON DELETE CASCADE NOT NULL,
    reaction VARCHAR(10) DEFAULT NULL, -- Emoji reactions like ❤️, 🍿, 🔥, 👍
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_viewed BOOLEAN DEFAULT false NOT NULL
);

-- 2. Add streak columns to friendships
ALTER TABLE friendships ADD COLUMN IF NOT EXISTS share_streak INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE friendships ADD COLUMN IF NOT EXISTS last_share_date DATE DEFAULT NULL;

-- 3. Enable RLS (Row Level Security) on movie_shares
ALTER TABLE movie_shares ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policy for Select: Users can read shares they sent or received
CREATE POLICY movie_shares_select_policy ON movie_shares
    FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- 5. RLS Policy for Insert: Users can only send shares from their own account
CREATE POLICY movie_shares_insert_policy ON movie_shares
    FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- 6. RLS Policy for Update: Users can update shares they are involved in (e.g. mark viewed, set reaction)
CREATE POLICY movie_shares_update_policy ON movie_shares
    FOR UPDATE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id)
    WITH CHECK (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- 7. RLS Policy for Delete: Cascade on delete handles this, but let's add it for safety
CREATE POLICY movie_shares_delete_policy ON movie_shares
    FOR DELETE
    USING (auth.uid() = sender_id);
