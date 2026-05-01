"""Movie sync service for fetching and syncing movies from TMDB to database."""

from typing import Dict, List
from app.data.services.tmdb_service import TMDBService
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.data.repositories.movie_repository_impl import MovieRepositoryImpl
from app.core.logger import logger


class MovieSyncService:
    """Service for syncing movies from TMDB to Supabase."""
    
    def __init__(self):
        self.tmdb = TMDBService()
        self.supabase_ds = SupabaseDataSource()
        self.repo = MovieRepositoryImpl()
    
    async def sync_movies(self, categories: List[str] = None, pages_per_category: int = 3) -> Dict:
        """
        Sync movies from TMDB to database in parallel with rate limiting.
        """
        import asyncio
        if categories is None:
            categories = ["popular", "now_playing", "upcoming", "top_rated", "trending"]
        
        semaphore = asyncio.Semaphore(10)
        
        async def sync_with_semaphore(cat):
            async with semaphore:
                return await self._sync_category(cat, pages_per_category)

        logger.info(f"Starting parallel sync for categories: {', '.join(categories)}...")
        tasks = [sync_with_semaphore(cat) for cat in categories]
        results = await asyncio.gather(*tasks)
        
        stats = {
            "total_fetched": 0,
            "new_movies": 0,
            "existing_movies": 0,
            "embeddings_generated": 0,
            "errors": 0,
            "categories": {}
        }
        
        for category, cat_stats in zip(categories, results):
            stats["total_fetched"] += cat_stats["fetched"]
            stats["new_movies"] += cat_stats["new"]
            stats["existing_movies"] += cat_stats["existing"]
            stats["embeddings_generated"] += cat_stats.get("embeddings", 0)
            stats["errors"] += cat_stats["errors"]
            stats["categories"][category] = cat_stats
            
        logger.info(
            f"SYNC COMPLETE: {stats['new_movies']} new movies added, "
            f"{stats['embeddings_generated']} embeddings generated!"
        )
        return stats
    
    async def _sync_category(self, category: str, pages: int) -> Dict:
        """Sync a specific category of movies in parallel pages."""
        import asyncio
        stats = {"fetched": 0, "new": 0, "existing": 0, "embeddings": 0, "errors": 0}
        
        async def sync_page(p):
            try:
                movies = await self._fetch_category(category, p)
                return movies if movies else []
            except Exception as e:
                logger.error(f"Error fetching {category} page {p}: {e}", exc_info=True)
                return []

        tasks = [sync_page(p) for p in range(1, pages + 1)]
        pages_results = await asyncio.gather(*tasks)
        
        for movies in pages_results:
            if not movies:
                continue
                
            stats["fetched"] += len(movies)
            movies_to_save = []
            
            for tmdb_movie in movies:
                try:
                    original_language = tmdb_movie.get("original_language", "")
                    if original_language in ["hi", "zh", "ja", "ko", "cn", "tw"]:
                        continue
                    
                    # Skip movies without a poster
                    if not tmdb_movie.get("poster_path"):
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
                    logger.warning(f"Error processing movie {tmdb_movie.get('id')}: {e}")
            
            if movies_to_save:
                try:
                    movie_ids = [m["id"] for m in movies_to_save]
                    existing_movies = self.supabase_ds.get_movies_by_ids(movie_ids)
                    existing_ids = {m["id"] for m in existing_movies}
                    
                    new_movies = [m for m in movies_to_save if m["id"] not in existing_ids]
                    stats["existing"] += len(movies_to_save) - len(new_movies)
                    
                    if new_movies:
                        self.supabase_ds.save_movies_batch(new_movies)
                        stats["new"] += len(new_movies)
                        
                        # Generate embeddings for newly saved movies
                        stats["embeddings"] += await self._generate_embeddings_for_movies(new_movies)
                except Exception:
                    # Fallback: save one by one
                    for movie_dict in movies_to_save:
                        try:
                            self.supabase_ds.save_movie(movie_dict)
                            stats["new"] += 1
                            stats["embeddings"] += await self._generate_embeddings_for_movies([movie_dict])
                        except Exception:
                            stats["existing"] += 1
                            
        return stats

    async def _generate_embeddings_for_movies(self, movies: List[Dict]) -> int:
        """Generate and store embeddings for a list of movie dicts.

        Runs in a thread pool to avoid blocking the async event loop,
        since sentence-transformers model.encode() is CPU-bound.

        Returns the number of successfully embedded movies.
        """
        import asyncio

        def _sync_generate():
            try:
                from app.services.embedding_service import embedding_service

                embeddings = embedding_service.embed_movies(movies)
                success = 0
                for movie, embedding in zip(movies, embeddings):
                    if self.supabase_ds.update_movie_embedding(movie["id"], embedding):
                        success += 1
                logger.info(f"Generated embeddings for {success}/{len(movies)} movies")
                return success
            except Exception as e:
                logger.error(f"Embedding generation failed: {e}", exc_info=True)
                return 0

        return await asyncio.to_thread(_sync_generate)
    
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
            logger.warning(f"Unknown category: {category}")
            return None
        
        return await fetch_func(page)
    
    async def close(self):
        """Close connections."""
        await self.tmdb.close()


# Global instance
movie_sync_service = MovieSyncService()
