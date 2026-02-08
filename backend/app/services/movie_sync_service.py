"""Movie sync service for fetching and syncing movies from TMDB to database."""

from typing import Dict, List
from app.data.services.tmdb_service import TMDBService
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.data.repositories.movie_repository_impl import MovieRepositoryImpl


class MovieSyncService:
    """Service for syncing movies from TMDB to Supabase."""
    
    def __init__(self):
        self.tmdb = TMDBService()
        self.supabase_ds = SupabaseDataSource()
        self.repo = MovieRepositoryImpl()
    
    async def sync_movies(self, categories: List[str] = None, pages_per_category: int = 2) -> Dict:
        """
        Sync movies from TMDB to database.
        
        Args:
            categories: List of categories to sync (popular, now_playing, upcoming)
            pages_per_category: Number of pages to fetch per category
            
        Returns:
            Sync statistics
        """
        if categories is None:
            categories = ["popular", "now_playing", "upcoming"]
        
        stats = {
            "total_fetched": 0,
            "new_movies": 0,
            "existing_movies": 0,
            "errors": 0,
            "categories": {}
        }
        
        for category in categories:
            print(f"\n📡 Syncing {category} movies...")
            category_stats = await self._sync_category(category, pages_per_category)
            
            stats["total_fetched"] += category_stats["fetched"]
            stats["new_movies"] += category_stats["new"]
            stats["existing_movies"] += category_stats["existing"]
            stats["errors"] += category_stats["errors"]
            stats["categories"][category] = category_stats
            
            print(f"✅ {category}: {category_stats['new']} new, {category_stats['existing']} existing")
        
        print(f"\n🎬 SYNC COMPLETE: {stats['new_movies']} new movies added!")
        return stats
    
    async def _sync_category(self, category: str, pages: int) -> Dict:
        """Sync a specific category of movies."""
        stats = {"fetched": 0, "new": 0, "existing": 0, "errors": 0}
        
        for page in range(1, pages + 1):
            try:
                # Fetch movies from TMDB
                if category == "popular":
                    movies = await self.tmdb.get_popular_movies(page)
                elif category == "now_playing":
                    movies = await self.tmdb.get_now_playing(page)
                elif category == "upcoming":
                    movies = await self.tmdb.get_upcoming(page)
                else:
                    continue
                
                stats["fetched"] += len(movies)
                
                # Save to database (with duplicate handling)
                for tmdb_movie in movies:
                    try:
                        movie_id = tmdb_movie["id"]
                        
                        # Filter out unwanted languages (Hindi, Chinese, Japanese, Korean)
                        original_language = tmdb_movie.get("original_language", "")
                        if original_language in ["hi", "zh", "ja", "ko", "cn", "tw"]:
                            print(f"⏭️  Skipping {original_language} movie: {tmdb_movie.get('title')}")
                            continue
                        
                        # Check if exists (will raise NotFoundError if not)
                        try:
                            self.supabase_ds.get_movie_by_id(movie_id)
                            # If we get here, movie exists
                            stats["existing"] += 1
                        except Exception:
                            # Movie doesn't exist, add it
                            movie_dict = {
                                "id": movie_id,
                                "name": tmdb_movie["title"],
                                "genre": self.repo._extract_genre(tmdb_movie),
                                "poster_path": tmdb_movie.get("poster_path")
                            }
                            self.supabase_ds.save_movie(movie_dict)
                            stats["new"] += 1
                    
                    except Exception as e:
                        stats["errors"] += 1
                        print(f"⚠️  Error processing movie {tmdb_movie.get('id')}: {e}")
                        
            except Exception as e:
                print(f"❌ Error fetching {category} page {page}: {e}")
                stats["errors"] += 1
        
        return stats
    
    async def close(self):
        """Close connections."""
        await self.tmdb.close()


# Global instance
movie_sync_service = MovieSyncService()
