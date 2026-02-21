-- ============================================
-- pgvector Similarity Search Migration
-- ============================================
-- Run in Supabase Dashboard → SQL Editor
-- Prerequisite: Enable "vector" extension first
-- (Database → Extensions → search "vector" → Enable)
-- ============================================

-- Step 1: Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Step 2: Add embedding column to movies table
ALTER TABLE movies ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Step 3: Add extra detail columns
ALTER TABLE movies ADD COLUMN IF NOT EXISTS backdrop_path TEXT;
ALTER TABLE movies ADD COLUMN IF NOT EXISTS runtime INTEGER;
ALTER TABLE movies ADD COLUMN IF NOT EXISTS tagline TEXT;
ALTER TABLE movies ADD COLUMN IF NOT EXISTS director TEXT;

-- Step 4: Similarity search function
CREATE OR REPLACE FUNCTION match_movies(
    query_embedding vector(384),
    match_count INT DEFAULT 3,
    exclude_id INT DEFAULT 0
) RETURNS TABLE (
    id BIGINT,
    name TEXT,
    genre TEXT,
    poster_path TEXT,
    overview TEXT,
    release_date TEXT,
    vote_average DOUBLE PRECISION,
    similarity DOUBLE PRECISION
)
LANGUAGE sql STABLE AS $$
    SELECT 
        m.id,
        m.name,
        m.genre,
        m.poster_path,
        m.overview,
        m.release_date,
        m.vote_average,
        1 - (m.embedding <=> query_embedding) AS similarity
    FROM movies m
    WHERE m.id != exclude_id 
      AND m.embedding IS NOT NULL
    ORDER BY m.embedding <=> query_embedding
    LIMIT match_count;
$$;

-- Step 5: Index for fast cosine similarity search
-- Note: IVFFlat index requires at least 100 rows with embeddings
-- Run this AFTER generating embeddings with generate_embeddings.py
-- CREATE INDEX IF NOT EXISTS movies_embedding_idx 
-- ON movies USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
