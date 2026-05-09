-- =============================================
-- Custom Collections: Supabase Migration
-- =============================================
-- Run this SQL in the Supabase SQL Editor (Dashboard > SQL Editor)

-- 1. user_collections table
CREATE TABLE IF NOT EXISTS user_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    description TEXT CHECK (char_length(description) <= 500),
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast user lookup
CREATE INDEX IF NOT EXISTS idx_user_collections_user_id ON user_collections(user_id);

-- 2. collection_movies junction table
CREATE TABLE IF NOT EXISTS collection_movies (
    collection_id UUID NOT NULL REFERENCES user_collections(id) ON DELETE CASCADE,
    movie_id BIGINT NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (collection_id, movie_id)
);

-- Index for fast collection lookup
CREATE INDEX IF NOT EXISTS idx_collection_movies_collection_id ON collection_movies(collection_id);

-- 3. RLS Policies
ALTER TABLE user_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_movies ENABLE ROW LEVEL SECURITY;

-- user_collections: users can CRUD their own, read public ones
CREATE POLICY "Users can view own collections"
    ON user_collections FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view public collections"
    ON user_collections FOR SELECT
    USING (is_public = TRUE);

CREATE POLICY "Users can create own collections"
    ON user_collections FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own collections"
    ON user_collections FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own collections"
    ON user_collections FOR DELETE
    USING (auth.uid() = user_id);

-- collection_movies: users can CRUD movies in their own collections
CREATE POLICY "Users can view movies in own collections"
    ON collection_movies FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_collections
            WHERE user_collections.id = collection_movies.collection_id
            AND user_collections.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can view movies in public collections"
    ON collection_movies FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_collections
            WHERE user_collections.id = collection_movies.collection_id
            AND user_collections.is_public = TRUE
        )
    );

CREATE POLICY "Users can add movies to own collections"
    ON collection_movies FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_collections
            WHERE user_collections.id = collection_movies.collection_id
            AND user_collections.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can remove movies from own collections"
    ON collection_movies FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM user_collections
            WHERE user_collections.id = collection_movies.collection_id
            AND user_collections.user_id = auth.uid()
        )
    );

-- 4. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_collection_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_collection_updated_at
    BEFORE UPDATE ON user_collections
    FOR EACH ROW
    EXECUTE FUNCTION update_collection_updated_at();

-- Service role bypass for backend API calls
CREATE POLICY "Service role full access to user_collections"
    ON user_collections FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access to collection_movies"
    ON collection_movies FOR ALL
    USING (auth.role() = 'service_role');
