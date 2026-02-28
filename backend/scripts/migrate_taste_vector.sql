-- ============================================================
-- Migration: User Taste Vector (Super Vector)
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add taste_vector and like counter to profiles
-- ============================================================
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS taste_vector vector(384),
ADD COLUMN IF NOT EXISTS like_count_since_update int DEFAULT 0;

-- 2. RPC: update_user_taste_vector
--    Averages all liked movie embeddings into a single 384-dim
--    normalized vector and stores it in profiles.taste_vector.
--
--    Normalization strategy: pgvector does NOT support vector/scalar
--    division. We unnest → divide each element → re-aggregate.
-- ============================================================
CREATE OR REPLACE FUNCTION update_user_taste_vector(user_id_param UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  avg_vec vector(384);
  normalized_vec vector(384);
  liked_count int;
  vec_norm double precision;
BEGIN
  -- Count liked movies that have embeddings
  SELECT COUNT(*)
  INTO liked_count
  FROM user_swipes us
  JOIN movies m ON m.id = us.movie_id
  WHERE us.user_id = user_id_param
    AND us.is_like = true
    AND m.embedding IS NOT NULL;

  IF liked_count = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No liked movies with embeddings found',
      'liked_count', 0
    );
  END IF;

  -- Compute element-wise average of liked movie embeddings
  SELECT AVG(m.embedding::vector(384))::vector(384)
  INTO avg_vec
  FROM user_swipes us
  JOIN movies m ON m.id = us.movie_id
  WHERE us.user_id = user_id_param
    AND us.is_like = true
    AND m.embedding IS NOT NULL;

  -- Compute L2 norm using pgvector-native function
  vec_norm := vector_norm(avg_vec);

  -- L2-normalize: unnest → divide each element → re-aggregate
  -- pgvector has no vector/scalar division operator, so we
  -- decompose to float[], scale, and cast back.
  IF vec_norm > 0 THEN
    SELECT array_agg(val / vec_norm)::real[]::vector(384)
    INTO normalized_vec
    FROM unnest(avg_vec::real[]) AS val;
  ELSE
    normalized_vec := avg_vec;
  END IF;

  -- Upsert into profiles
  UPDATE profiles
  SET taste_vector = normalized_vec,
      like_count_since_update = 0
  WHERE id = user_id_param;

  -- If no profile row exists, insert one
  IF NOT FOUND THEN
    INSERT INTO profiles (id, taste_vector, like_count_since_update)
    VALUES (user_id_param, normalized_vec, 0)
    ON CONFLICT (id) DO UPDATE
    SET taste_vector = EXCLUDED.taste_vector,
        like_count_since_update = 0;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Taste vector updated',
    'liked_count', liked_count
  );
END;
$$;


-- 3. RPC: match_movies_for_user
--    Semantic search using the user's taste_vector.
--    Excludes already-swiped movies.
-- ============================================================
CREATE OR REPLACE FUNCTION match_movies_for_user(
  query_embedding vector(384),
  match_count int,
  user_id_param UUID
)
RETURNS TABLE (
  id int,
  name text,
  genre text,
  poster_path text,
  overview text,
  release_date text,
  vote_average float,
  similarity float
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.name,
    m.genre,
    m.poster_path,
    m.overview,
    m.release_date,
    m.vote_average::float,
    (1 - (m.embedding <=> query_embedding))::float AS similarity
  FROM movies m
  WHERE m.embedding IS NOT NULL
    AND m.id NOT IN (
      SELECT us.movie_id FROM user_swipes us WHERE us.user_id = user_id_param
    )
  ORDER BY m.embedding <=> query_embedding ASC
  LIMIT match_count;
END;
$$;


-- 4. Trigger: auto-increment like_count_since_update on new likes
-- ============================================================
CREATE OR REPLACE FUNCTION increment_like_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.is_like = true THEN
    UPDATE profiles
    SET like_count_since_update = COALESCE(like_count_since_update, 0) + 1
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any, then create
DROP TRIGGER IF EXISTS trg_increment_like_count ON user_swipes;
CREATE TRIGGER trg_increment_like_count
  AFTER INSERT ON user_swipes
  FOR EACH ROW
  EXECUTE FUNCTION increment_like_count();


-- 5. Grant execute permissions for the RPC functions
-- ============================================================
GRANT EXECUTE ON FUNCTION update_user_taste_vector(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION match_movies_for_user(vector(384), int, UUID) TO authenticated;
