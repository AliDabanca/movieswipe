-- Supabase RPC: get_unseen_movies
-- Kullanıcının daha önce swipe etmediği filmleri döndürür
-- DB tarafında filtreleme yaparak Python'a sadece gösterilecek filmleri gönderir
--
-- Kullanım: SELECT * FROM get_unseen_movies('user-uuid-here', 200);
-- Supabase Dashboard > SQL Editor'den çalıştırın

CREATE OR REPLACE FUNCTION get_unseen_movies(
    p_user_id UUID,
    p_limit INT DEFAULT 200
)
RETURNS SETOF movies
LANGUAGE sql
STABLE
AS $$
    SELECT m.*
    FROM movies m
    WHERE m.id NOT IN (
        SELECT us.movie_id
        FROM user_swipes us
        WHERE us.user_id = p_user_id
    )
    ORDER BY m.vote_average DESC NULLS LAST
    LIMIT p_limit;
$$;


-- Supabase RPC: get_user_genre_stats
-- Kullanıcının tür bazında like/pass istatistiklerini döndürür
-- Backend'de genre profili oluşturmak için kullanılır
--
-- Kullanım: SELECT * FROM get_user_genre_stats('user-uuid-here');

CREATE OR REPLACE FUNCTION get_user_genre_stats(
    p_user_id UUID
)
RETURNS TABLE(
    genre TEXT,
    like_count BIGINT,
    pass_count BIGINT,
    total_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        m.genre,
        COUNT(*) FILTER (WHERE us.is_like = true) AS like_count,
        COUNT(*) FILTER (WHERE us.is_like = false) AS pass_count,
        COUNT(*) AS total_count
    FROM user_swipes us
    JOIN movies m ON m.id = us.movie_id
    WHERE us.user_id = p_user_id
    GROUP BY m.genre
    ORDER BY total_count DESC;
$$;
