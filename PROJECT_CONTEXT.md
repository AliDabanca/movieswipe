# Project Context: MovieSwipe 🎬

MovieSwipe, kullanıcıların film keşfetmesini sağlayan, "swipe" (kaydırma) mekaniğine sahip, yapay zeka destekli, sosyal ve modern bir mobil uygulamadır. Kullanıcı etkileşimlerine dayalı kişiselleştirilmiş öneriler sunar ve arkadaş çevresiyle film paylaşımı imkânı sağlar.

## 1. Proje Özeti

MovieSwipe, film dünyasını daha eğlenceli ve interaktif bir hale getirmeyi amaçlar. Temel özellikleri:

- **Swipe Keşfi:** Filmleri beğeniye göre sağa/sola kaydırarak değerlendirme (Tinder-style).
- **Kişiselleştirilmiş Akış:** `pgvector` destekli 384 boyutlu vektör tabanlı öneri motoru (Cosine Similarity + HNSW indeksleme).
- **Açıklanabilir AI:** Her film önerisi için "Neden önerildi?" açıklaması.
- **Akıllı Keşif (Smart Discovery):** Doğal dil sorgusuyla anlamsal film arama.
- **İzleme Listesi (Watchlist):** Beğenilen filmlerin takibi, koleksiyonlar ve izleme durumu yönetimi.
- **İzleme İlerleme Göstergesi:** Koleksiyonlardaki izleme tamamlanma yüzdesini animasyonlu grafik olarak sunar.
- **TMDB Entegrasyonu:** Gerçek zamanlı film verileri senkronizasyonu ve Redis önbellekleme.
- **Sosyal DM & Film Paylaşımı:** Arkadaş ekleme, doğrudan mesajlaşma, film DM kartları gönderme, emoji reaksiyonları.
- **Harici Paylaşım:** `share_plus` ile WhatsApp, Instagram, Twitter gibi platformlara bilet kartı paylaşımı.
- **Takip Sistemi:** Kullanıcı takip etme/edilme ve sosyal gösterge paneli.
- **Film DNA & Ruh Hali Aurası:** Kullanıcının kaydırma zevkine dayalı tür dağılım radar grafiği ve haftalık ruh hali analizi.
- **Haftalık Aktivite Grafiği:** Günlük kaydırma istatistiklerini çubuk grafik olarak gösterir.
- **Günlük Seri (Streak):** Günlük kaydırma alışkanlığı takibi, yerel-bulut senkronizasyonu ve öz-iyileştirici çakışma çözümleme.
- **Onboarding:** Yeni kullanıcılar için ruh hali anketi ve tür seçimi (soğuk başlangıç çözümü).

## 2. Teknik Stack

Proje, performans ve ölçeklenebilirlik odaklı modern teknolojilerle inşa edilmiştir:

- **Frontend (Flutter):**
  - **State Management:** `flutter_bloc` (karmaşık iş mantığı), `provider` (hafif state/DI)
  - **Dependency Injection:** `get_it` (Service Locator)
  - **Hata Yönetimi:** `dartz` (Functional programming, Either<Failure, Success>)
  - **UI/UX:** `flutter_card_swiper`, `cached_network_image`, `google_fonts` (Inter)
  - **Persistence:** `shared_preferences` (yerel önbellek)
  - **Auth:** `supabase_flutter`
  - **Paylaşım:** `share_plus`
  - **Modeller:** `equatable` (BLoC state karşılaştırmaları için)
  
- **Backend (FastAPI):**
  - **Dil:** Python 3.10+
  - **Veritabanı:** Supabase (PostgreSQL) + `pgvector` (HNSW indeksleme)
  - **ORM:** SQLAlchemy (Asyncio)
  - **Cache:** Redis
  - **ML/NLP:** `sentence-transformers` (all-MiniLM-L6-v2), `numpy`
  - **Scheduling:** `apscheduler`
  - **External API:** The Movie Database (TMDB)
  - **Validasyon:** Pydantic v2 (tüm request/response modelleri)

## 3. Mimari Yapı

Hem frontend hem de backend tarafında **Clean Architecture** prensipleri uygulanmıştır:

- **Data Layer:** Veri kaynakları (PostgREST API, TMDB API, SharedPreferences), DTO modelleri ve Repository implementasyonları.
- **Domain Layer:** İş mantığı, varlıklar (entities), repository arayüzleri ve use case'ler. Framework bağımsızdır.
- **Presentation Layer:** Kullanıcı arayüzü (Flutter Widget/BLoC) ve API endpointleri (FastAPI Router).

## 4. Klasör Haritası

### Frontend (`/lib`)
- `/core`: Temalar, DI kurulumu, ortam yapılandırması, global provider'lar (Auth, User, LikedMovies), hata modelleri.
- `/features`: Özellik tabanlı modüller (her biri `data/domain/presentation` katmanlarına sahip):
  - `/auth`: Giriş, kayıt, Supabase Auth entegrasyonu.
  - `/movies`: Kaydırma akışı, film detayları, arama, akıllı keşif, koleksiyonlar, izleme durumu, ilerleme göstergesi.
  - `/social`: Sosyal gösterge paneli, DM mesajlaşma, film kartı paylaşımı, emoji reaksiyonları, arkadaş profili.
  - `/users`: Profil sayfası (DNA grafiği, ruh hali aurası, aktivite grafiği, streak kartı, avatar/kapak özelleştirme), hakkında sayfası.
  - `/onboarding`: İlk kullanım ruh hali anketi ve tür seçimi.
  - `/navigation`: Ana navigasyon yapısı ve routing.

### Backend (`/backend/app`)
- `/core`: Güvenlik (JWT middleware), veritabanı bağlantısı (Supabase client + retry patch), ortam ayarları (Pydantic Settings).
- `/data`: Pydantic veri modelleri ve request/response şemaları.
- `/domain`: Temel iş nesneleri ve varlık tanımları.
- `/services`: İş mantığı servisleri:
  - `recommendation_service.py`: Semantik öneri motoru (43KB, çok faktörlü puanlama + Explainable AI)
  - `embedding_service.py`: NLP vektörleştirme (Sentence-Transformers)
  - `social_service.py`: Takip, bildirim, sosyal etkileşim
  - `dm_service.py`: Doğrudan mesajlaşma
  - `collection_service.py`: Koleksiyon yönetimi
  - `movie_sync_service.py`: TMDB senkronizasyonu
  - `notification_service.py`: Bildirim servisi
  - `scheduler_service.py`: Zamanlayıcı (APScheduler)
- `/presentation/api/routes`: API endpoint'leri (`movies`, `recommendations`, `social`, `dm`, `collections`, `users`, `search`, `sync`, `notifications`).

## 5. Kritik Akışlar

Geliştiricilerin bilmesi gereken ana dosyalar:

- **Auth İşlemleri:**
  - Frontend: `lib/features/auth/presentation/pages/login_page.dart`
  - Backend: Supabase Auth + JWT middleware (`backend/app/core/security.py`)

- **Film Kaydırma & Kayıt:**
  - UI: `lib/features/movies/presentation/pages/swipe_page.dart`
  - State: `lib/features/movies/presentation/bloc/movies_bloc.dart`
  - API: `backend/app/presentation/api/routes/movies.py`

- **Öneri Motoru:**
  - API: `backend/app/presentation/api/routes/recommendations.py`
  - Logic: `backend/app/services/recommendation_service.py` (Vektör benzerlik araması + çok faktörlü puanlama)
  - Embeddings: `backend/app/services/embedding_service.py`

- **Sosyal / DM:**
  - UI: `lib/features/social/presentation/pages/movie_dm_page.dart`
  - API: `backend/app/presentation/api/routes/dm.py`, `social.py`
  - Logic: `backend/app/services/dm_service.py`, `social_service.py`

- **Profil Analytics:**
  - Genre DNA: `lib/features/users/presentation/widgets/genre_dna_chart.dart`
  - Mood Aura: `lib/features/users/presentation/widgets/current_mood_aura.dart`
  - Activity: `lib/features/users/presentation/widgets/daily_activity_chart.dart`
  - Streak: `lib/features/users/presentation/widgets/streak_card.dart`

- **Veri Senkronizasyonu:**
  - TMDB Sync: `backend/app/presentation/api/routes/sync.py`
  - Service: `backend/app/services/movie_sync_service.py`

- **Bağlantı Dayanıklılığı:**
  - Supabase Client + Retry: `backend/app/core/supabase.py`

## 6. Gelecek Planı (Planlananlar)
- **Push Bildirimler:** Firebase entegrasyonu ile anlık bildirimler.
- **Çevrimdışı Mod:** Hive/SQLite ile yerel önbellekleme desteği.
- **CI/CD:** GitHub Actions üzerinden otomatik test ve dağıtım.
- **Group Swipe Rooms:** Ortak kaydırma odaları.

---
*Not: Bu belge projenin güncel durumunu yansıtır (Haziran 2026). Büyük mimari değişikliklerde güncellenmelidir.*
