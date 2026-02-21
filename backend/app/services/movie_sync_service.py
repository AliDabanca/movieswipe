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
    
    async def sync_movies(self, categories: List[str] = None, pages_per_category: int = 3) -> Dict:
        """
        Sync movies from TMDB to database.
        
        Args:
            categories: List of categories to sync
            pages_per_category: Number of pages to fetch per category
            
        Returns:
            Sync statistics
        """
        if categories is None:
            categories = ["popular", "now_playing", "upcoming", "top_rated", "trending"]
        
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
                movies = await self._fetch_category(category, page)
                if movies is None:
                    continue
                
                stats["fetched"] += len(movies)
                
                # Prepare batch for upsert
                movies_to_save = []
                for tmdb_movie in movies:
                    try:
                        # Filter out unwanted languages (Hindi, Chinese, Japanese, Korean)
                        original_language = tmdb_movie.get("original_language", "")
                        if original_language in ["hi", "zh", "ja", "ko", "cn", "tw"]:
                            continue
                        
                        movie_dict = {
                            "id": tmdb_movie["id"],
                            "name": tmdb_movie.get("title", tmdb_movie.get("name", "Unknown")),
                            "genre": self.repo._extract_genre(tmdb_movie),
                            "poster_path": tmdb_movie.get("poster_path"),
                            "overview": tmdb_movie.get("overview"),
                            "release_date": tmdb_movie.get("release_date"),
                            "vote_average": tmdb_movie.get("vote_average", 0),
                        }
                        movies_to_save.append(movie_dict)
                    
                    except Exception as e:
                        stats["errors"] += 1
                        print(f"⚠️  Error processing movie {tmdb_movie.get('id')}: {e}")
                
                # Batch upsert for better performance
                if movies_to_save:
                    try:
                        # Check which exist already
                        existing_ids = set()
                        try:
                            movie_ids = [m["id"] for m in movies_to_save]
                            existing_movies = self.supabase_ds.get_movies_by_ids(movie_ids)
                            existing_ids = {m["id"] for m in existing_movies}
                        except Exception:
                            pass
                        
                        new_movies = [m for m in movies_to_save if m["id"] not in existing_ids]
                        stats["existing"] += len(movies_to_save) - len(new_movies)
                        
                        if new_movies:
                            self.supabase_ds.save_movies_batch(new_movies)
                            stats["new"] += len(new_movies)
                    except Exception as e:
                        # Fallback: save one by one
                        for movie_dict in movies_to_save:
                            try:
                                self.supabase_ds.save_movie(movie_dict)
                                stats["new"] += 1
                            except Exception:
                                stats["existing"] += 1
                        
            except Exception as e:
                print(f"❌ Error fetching {category} page {page}: {e}")
                stats["errors"] += 1
        
        return stats
    
    async def _fetch_category(self, category: str, page: int):
        """Fetch movies from a specific TMDB category."""
        fetch_map = {
            "popular": self.tmdb.get_popular_movies,
            "now_playing": self.tmdb.get_now_playing,
            "upcoming": self.tmdb.get_upcoming,
            "top_rated": self.tmdb.get_top_rated,
            "trending": self.tmdb.get_trending,
        }
        
        fetch_func = fetch_map.get(category)
        if fetch_func is None:
            print(f"⚠️  Unknown category: {category}")
            return None
        
        return await fetch_func(page)
    
    async def close(self):
        """Close connections."""
        await self.tmdb.close()


# Global instance
movie_sync_service = MovieSyncService()
