-- ============================================================
-- Fix: Rename 'message' to 'status_message' in update_user_taste_vector
-- to avoid postgrest-py (Pydantic) validation conflicts.
-- ============================================================

-- Must drop the function first because return type (table columns) is changing
DROP FUNCTION IF EXISTS update_user_taste_vector(UUID);

CREATE OR REPLACE FUNCTION update_user_taste_vector(user_id_param UUID)
RETURNS TABLE(success boolean, status_message text, liked_count int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  avg_vec vector(384);
  normalized_vec vector(384);
  v_liked_count int;
  vec_norm double precision;
BEGIN
  -- Count liked movies that have embeddings
  SELECT COUNT(*)
  INTO v_liked_count
  FROM user_swipes us
  JOIN movies m ON m.id = us.movie_id
  WHERE us.user_id = user_id_param
    AND us.is_like = true
    AND m.embedding IS NOT NULL;

  IF v_liked_count = 0 THEN
    success := false;
    status_message := 'No liked movies with embeddings found';
    liked_count := 0;
    RETURN NEXT;
    RETURN;
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

  success := true;
  status_message := 'Taste vector updated';
  liked_count := v_liked_count;
  RETURN NEXT;
END;
$$;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
