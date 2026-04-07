# Project Context: MovieSwipe 🎬

MovieSwipe, kullanıcıların film keşfetmesini sağlayan, "swipe" (kaydırma) mekaniğine sahip modern bir mobil uygulamadır. Kullanıcı etkileşimlerine dayalı kişiselleştirilmiş öneriler sunar.

## 1. Proje Özeti
MovieSwipe, film dünyasını daha eğlenceli ve interaktif bir hale getirmeyi amaçlar. Temel özellikleri şunlardır:
- **Swipe Keşfi:** Filmleri beğeniye göre sağa/sola kaydırarak değerlendirme.
- **Kişiselleştirilmiş Akış:** `pgvector` destekli vektör tabanlı öneri motoru.
- **İzleme Listesi (Watchlist):** Beğenilen filmlerin takibi ve yönetimi.
- **TMDB Entegrasyonu:** Gerçek zamanlı film verileri ve senkronizasyonu.

## 2. Teknik Stack
Proje, performans ve ölçeklenebilirlik odaklı modern teknolojilerle inşa edilmiştir:

- **Frontend (Flutter):**
  - **State Management:** `flutter_bloc`
  - **Dependency Injection:** `get_it`
  - **Hata Yönetimi:** `dartz` (Functional programming)
  - **UI/UX:** `flutter_card_swiper`, `cached_network_image`.
  
- **Backend (FastAPI):**
  - **Dil:** Python 3.10+
  - **Veritabanı:** Supabase (PostgreSQL) + `pgvector`
  - **ORM:** SQLAlchemy (Asyncio)
  - **Cache:** Redis
  - **External API:** The Movie Database (TMDB)

## 3. Mimari Yapı
Hem frontend hem de backend tarafında **Clean Architecture** prensipleri uygulanmıştır:

- **Data Layer:** Veri kaynakları (API, DB) ve DTO modelleri.
- **Domain Layer:** İş mantığı, entitiler ve repository arayüzleri (Framework bağımsız).
- **Presentation Layer:** Kullanıcı arayüzü (Flutter) ve API endpointleri (FastAPI).

## 4. Klasör Haritası

### Frontend (`/lib`)
- `/core`: Temalar, DI kurulumu ve ortak yardımcı sınıflar.
- `/features`: Özellik tabanlı modüller:
  - `/auth`: Giriş, kayıt ve kullanıcı doğrulama işlemleri.
  - `/movies`: Kaydırma akışı, film detayları ve arama.
  - `/users`: Profil yönetimi ve kullanıcı ayarları.
  - `/navigation`: Ana navigasyon yapısı ve routing.

### Backend (`/backend/app`)
- `/core`: Güvenlik (JWT), veritabanı bağlantısı ve global ayarlar.
- `/data`: Veritabanı modelleri ve repository implementasyonları.
- `/domain`: Temel iş nesneleri ve mantığı.
- `/presentation/api/routes`: Tüm API endpoint tanımlamaları.

## 5. Kritik Akışlar
Geliştiricilerin bilmesi gereken ana dosyalar:

- **Auth İşlemleri:**
  - Frontend: `lib/features/auth/presentation/pages/login_page.dart`
  - Backend: Supabase Auth entegrasyonu ve JWT middleware.
- **Film Kaydırma & Kayıt:**
  - UI: `lib/features/movies/presentation/pages/swipe_page.dart`
  - API: `backend/app/presentation/api/routes/movies.py`
- **Öneri Motoru:**
  - Logic: `backend/app/presentation/api/routes/recommendations.py` (Vektör benzerlik araması).
- **Veri Senkronizasyonu:**
  - Task: `backend/app/presentation/api/routes/sync.py` (TMDB -> Database).

## 6. Gelecek Planı (Eksikler & Planlananlar)
- **Sosyal Özellikler:** Arkadaş takibi ve swipe paylaşımı henüz geliştirme aşamasında.
- **Push Bildirimler:** Yeni öneriler için Firebase/Supabase entegrasyonu planlanıyor.
- **Çevrimdışı Mod:** SQLite veya Hive ile yerel önbellekleme desteği eklenecek.
- **Yorum & Puanlama:** Detaylı film inceleme sistemi plan dahilinde.
- **CI/CD:** GitHub Actions üzerinden otomatik test ve dağıtım süreçleri.

---
*Not: Bu belge projenin güncel durumunu yansıtır. Büyük mimari değişikliklerde güncellenmelidir.*
