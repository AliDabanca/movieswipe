-- ============================================
-- Supabase Security Fixes Migration
-- ============================================
-- Bu scripti Supabase Dashboard > SQL Editor'de çalıştırın.
-- ============================================

-- 1. Tablolarda RLS (Row Level Security) Etkinleştirme
ALTER TABLE movies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_swipes ENABLE ROW LEVEL SECURITY;

-- 2. 'movies' Tablosu İçin Politikalar (Policies)
DROP POLICY IF EXISTS "Movies are viewable by everyone" ON movies;
CREATE POLICY "Movies are viewable by everyone" 
ON movies FOR SELECT 
USING (true);

-- 3. 'user_swipes' Tablosu İçin Politikalar (Policies)
-- Temizlik: Mevcut kuralları önce siliyoruz ki hata vermesin
DROP POLICY IF EXISTS "Users can view their own swipes" ON user_swipes;
DROP POLICY IF EXISTS "Users can insert their own swipes" ON user_swipes;
DROP POLICY IF EXISTS "Users can update their own swipes" ON user_swipes;

-- Kullanıcılar sadece kendi swipe'larını görebilir
CREATE POLICY "Users can view their own swipes" 
ON user_swipes FOR SELECT 
USING (auth.uid() = user_id);

-- Kullanıcılar sadece kendi swipe'larını ekleyebilir
CREATE POLICY "Users can insert their own swipes" 
ON user_swipes FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Kullanıcılar sadece kendi swipe'larını güncelleyebilir
CREATE POLICY "Users can update their own swipes" 
ON user_swipes FOR UPDATE 
USING (auth.uid() = user_id);

-- 4. Fonksiyon Güvenliği (Search Path Fix) - En Robust Yöntem (DO Bloğu)
-- 'IF EXISTS' desteklenmeyebileceği için tüm fonksiyonları DO bloğu içinde güncelliyoruz.

DO $$ 
BEGIN
    -- Temel Fonksiyonlar
    BEGIN ALTER FUNCTION get_unseen_movies(UUID, INT) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION get_user_stats(UUID) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION check_username_available(TEXT) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Vektör ve Öneri Fonksiyonları
    BEGIN ALTER FUNCTION match_movies(vector(384), INT, INT) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION match_movies_for_user(vector(384), INT, UUID) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION update_user_taste_vector(UUID) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION get_user_genre_stats(UUID) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Yardımcı Fonksiyonlar
    BEGIN ALTER FUNCTION increment_like_count() SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION get_email_from_username(TEXT) SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER FUNCTION update_modified_column() SET search_path = public; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ============================================
-- UYGULAMA TAMAMLANDI
-- ============================================
