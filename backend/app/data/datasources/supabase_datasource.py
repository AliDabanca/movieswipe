"""Supabase datasource for movie persistence with retry mechanism."""

import time
import functools
from typing import List, Dict, Any, Callable, TypeVar
from app.core.supabase import supabase
from app.core.errors import ServerError, NotFoundError
from app.core.logger import logger

T = TypeVar("T")


def with_retry(max_retries: int = 3, base_delay: float = 0.5):
    """Decorator: retry on connection/timeout errors with exponential backoff.
    
    Only retries on network-level failures (timeout, connection reset).
    Does NOT retry on client errors (4xx) or data errors.
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> T:
            last_exception = None
            for attempt in range(1, max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    error_str = str(e).lower()
                    # Only retry on network/timeout/protocol errors
                    is_retryable = any(kw in error_str for kw in [
                        "timeout", "timed out", "connection",
                        "522", "503", "502", "reset",
                        "network", "eof", "broken pipe",
                        "protocol", "disconnected", "terminated"
                    ])
                    if not is_retryable or attempt == max_retries:
                        raise
                    
                    delay = base_delay * (2 ** (attempt - 1))
                    logger.warning(
                        f"⚡ Retry {attempt}/{max_retries} for {func.__name__} "
                        f"after {delay:.1f}s (error: {e})"
                    )
                    time.sleep(delay)
                    last_exception = e
            raise last_exception  # Should never reach here
        return wrapper
    return decorator


class SupabaseDataSource:
    """Data source for Supabase database operations with automatic retry."""
    
    def __init__(self):
        """Reusing the global Supabase client."""
        self.client = supabase
    
    @with_retry()
    def get_movies(self, limit: int = 20) -> List[Dict[str, Any]]:
        """Fetch movies from Supabase."""
        try:
            response = self.client.table("movies").select("*").limit(limit).execute()
            return response.data
        except Exception as e:
            logger.error(f"Supabase fetch error: {str(e)}", exc_info=True)
            raise ServerError("Failed to fetch movies")
    
    def save_movie(self, movie_data: Dict[str, Any]) -> Dict[str, Any]:
        """Save a single movie to Supabase."""
        try:
            # Use upsert to avoid duplicates (on conflict update)
            response = self.client.table("movies").upsert(
                movie_data,
                on_conflict="id"
            ).execute()
            
            logger.info(f"Successfully saved movie: {movie_data.get('id')}")
            return response.data[0]
        except Exception as e:
            logger.error(f"Supabase save error for movie {movie_data.get('id')}: {str(e)}", exc_info=True)
            raise ServerError("Failed to save movie")
    
    @with_retry()
    def save_movies_batch(self, movies_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Save multiple movies to Supabase in batch."""
        try:
            response = self.client.table("movies").upsert(
                movies_data,
                on_conflict="id"
            ).execute()
            
            return response.data
        except Exception as e:
            logger.error(f"Supabase batch save error (size: {len(movies_data)}): {str(e)}", exc_info=True)
            raise ServerError("Failed to save movies")
    
    def get_movie_by_id(self, movie_id: int) -> Dict[str, Any]:
        """Get a single movie by ID."""
        try:
            response = self.client.table("movies").select("*").eq("id", movie_id).execute()
            
            if not response.data:
                raise NotFoundError(f"Movie with ID {movie_id} not found")
            
            return response.data[0]
        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"Supabase fetch error by ID {movie_id}: {str(e)}", exc_info=True)
            raise ServerError("Failed to fetch movie details")
            
    @with_retry()
    def get_movies_by_ids(self, movie_ids: List[int]) -> List[Dict[str, Any]]:
        """
        Get multiple movies by their IDs. 
        Uses chunking to avoid oversized requests/URL limits.
        """
        if not movie_ids:
            return []
            
        # Chunk size to avoid 'RemoteProtocolError' or URL length limits (PostgREST/Supabase)
        CHUNK_SIZE = 50
        all_movies = []
        
        try:
            for i in range(0, len(movie_ids), CHUNK_SIZE):
                chunk = movie_ids[i:i + CHUNK_SIZE]
                response = self.client.table("movies").select("*").in_("id", chunk).execute()
                all_movies.extend(response.data)
            
            return all_movies
        except Exception as e:
            logger.error(f"Supabase batch fetch error (total ids: {len(movie_ids)}): {str(e)}", exc_info=True)
            raise ServerError("Failed to fetch movies")
    
    @with_retry()
    def save_swipe(self, user_id: str, movie_id: int, is_like: bool, rating: int | None = None) -> Dict[str, Any]:
        """Save a user swipe to the database."""
        try:
            swipe_data = {
                "user_id": user_id,
                "movie_id": movie_id,
                "is_like": is_like
            }
            if is_like and rating is not None:
                swipe_data["rating"] = rating
            
            # Use upsert to update if exists, insert if not
            response = self.client.table("user_swipes")\
                .upsert(swipe_data, on_conflict="user_id,movie_id")\
                .execute()
            
            logger.info(f"Saved swipe for user {user_id} on movie {movie_id} (like: {is_like}, rating: {rating})")
            return response.data[0]
        except Exception as e:
            logger.error(f"Supabase swipe save error: {str(e)}", exc_info=True)
            raise ServerError("Failed to save swipe")

    def delete_swipe(self, user_id: str, movie_id: int) -> None:
        """Delete a swipe record (unlike/unpass)."""
        try:
            self.client.table("user_swipes")\
                .delete()\
                .eq("user_id", user_id)\
                .eq("movie_id", movie_id)\
                .execute()
            logger.info(f"Deleted swipe for user {user_id} on movie {movie_id}")
        except Exception as e:
            logger.error(f"Supabase swipe deletion error: {str(e)}", exc_info=True)
            raise ServerError("Failed to delete swipe")
    
    def update_watch_status(self, user_id: str, movie_id: int, watch_status: str | None) -> None:
        """Update the watch status for a user's swipe record."""
        try:
            self.client.table("user_swipes")\
                .update({"watch_status": watch_status})\
                .eq("user_id", user_id)\
                .eq("movie_id", movie_id)\
                .execute()
            logger.info(f"Updated watch status for user {user_id} on movie {movie_id} to '{watch_status}'")
        except Exception as e:
            logger.error(f"Supabase watch status update error: {str(e)}", exc_info=True)
            raise ServerError("Failed to update watch status")
    
    def get_user_swipes(self, user_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all swipes for a user."""
        try:
            response = self.client.table("user_swipes").select("*").eq("user_id", user_id).order("swiped_at", desc=True).limit(limit).execute()
            return response.data
        except Exception as e:
            logger.error(f"Supabase swipe fetch error for user {user_id}: {str(e)}", exc_info=True)
            raise ServerError("Failed to fetch swipes")
    
    def get_user_liked_movie_ids(self, user_id: str) -> List[int]:
        """Get IDs of movies the user liked."""
        try:
            response = self.client.table("user_swipes").select("movie_id").eq("user_id", user_id).eq("is_like", True).execute()
            return [swipe["movie_id"] for swipe in response.data]
        except Exception as e:
            logger.error(f"Supabase liked movies fetch error: {str(e)}")
            raise ServerError("Failed to fetch liked movies")
    
    @with_retry()
    def get_user_swiped_movie_ids(self, user_id: str) -> List[int]:
        """Get IDs of all movies the user has swiped."""
        try:
            response = self.client.table("user_swipes").select("movie_id").eq("user_id", user_id).execute()
            return [swipe["movie_id"] for swipe in response.data]
        except Exception as e:
            logger.error(f"Supabase swiped movies fetch error: {str(e)}")
            raise ServerError("Failed to fetch swiped movies")

    @with_retry()
    def get_unseen_movies(self, user_id: str, limit: int = 200) -> List[Dict[str, Any]]:
        """Get movies the user hasn't swiped yet."""
        try:
            # Try Supabase RPC first
            response = self.client.rpc(
                "get_unseen_movies",
                {"p_user_id": user_id, "p_limit": limit}
            ).execute()
            return response.data
        except Exception as rpc_error:
            logger.warning(f"RPC fallback triggered (get_unseen_movies) for user {user_id}: {rpc_error}")
            try:
                # Use a reasonable limit for fallback
                all_movies = self.get_movies(limit=500)
                swiped_ids = set(self.get_user_swiped_movie_ids(user_id))
                unseen = [m for m in all_movies if m["id"] not in swiped_ids]
                unseen.sort(key=lambda m: m.get("vote_average") or 0, reverse=True)
                return unseen[:limit]
            except Exception as e:
                logger.error(f"Critical fallback failure for unseen movies (user {user_id}): {str(e)}", exc_info=True)
                raise ServerError("Failed to get unseen movies")

    @with_retry()
    def get_user_genre_stats(self, user_id: str) -> List[Dict[str, Any]]:
        """Get user's genre-level like/pass statistics."""
        try:
            # Try Supabase RPC first
            response = self.client.rpc(
                "get_user_genre_stats",
                {"p_user_id": user_id}
            ).execute()
            return response.data
        except Exception as rpc_error:
            logger.warning(f"RPC fallback triggered (get_user_genre_stats) for user {user_id}: {rpc_error}")
            try:
                swipes = self.get_user_swipes(user_id, limit=500)
                if not swipes:
                    return []
                
                movie_ids = [s["movie_id"] for s in swipes]
                movies = self.get_movies_by_ids(movie_ids)
                movie_map = {m["id"]: m for m in movies}
                
                genre_stats = {}
                for swipe in swipes:
                    movie = movie_map.get(swipe["movie_id"])
                    if not movie:
                        continue
                    genre = movie.get("genre", "General")
                    if genre not in genre_stats:
                        genre_stats[genre] = {"genre": genre, "like_count": 0, "pass_count": 0, "total_count": 0}
                    genre_stats[genre]["total_count"] += 1
                    if swipe.get("is_like"):
                        genre_stats[genre]["like_count"] += 1
                    else:
                        genre_stats[genre]["pass_count"] += 1
                
                return list(genre_stats.values())
            except Exception as e:
                logger.error(f"Critical fallback failure for genre stats (user {user_id}): {str(e)}", exc_info=True)
                raise ServerError("Failed to get genre stats")

    @with_retry()
    def get_user_stats_rpc(self, user_id: str) -> Dict[str, int]:
        """Get global swipe statistics using RPC for accuracy."""
        try:
            response = self.client.rpc(
                "get_user_stats",
                {"p_user_id": user_id}
            ).execute()
            
            # PostgREST returns a list of objects for TABLE returns
            if response.data and isinstance(response.data, list):
                return response.data[0]
            return {"total_swipes": 0, "total_likes": 0, "total_passes": 0}
        except Exception as e:
            logger.error(f"Supabase stats RPC error for user {user_id}: {str(e)}")
            # Fallback to 0s to prevent crash
            return {"total_swipes": 0, "total_likes": 0, "total_passes": 0}

    def get_similar_movies(self, movie_id: int, limit: int = 3) -> List[Dict[str, Any]]:
        """Get similar movies using pgvector cosine similarity."""
        try:
            movie = self.client.table("movies").select("embedding").eq("id", movie_id).single().execute()
            
            if not movie.data or not movie.data.get("embedding"):
                source = self.client.table("movies").select("genre").eq("id", movie_id).single().execute()
                if source.data:
                    genre = source.data.get("genre", "")
                    response = self.client.table("movies") \
                        .select("id, name, genre, poster_path, overview, release_date, vote_average") \
                        .eq("genre", genre) \
                        .neq("id", movie_id) \
                        .order("vote_average", desc=True) \
                        .limit(limit) \
                        .execute()
                    return response.data if response.data else []
                return []
            
            embedding = movie.data["embedding"]
            response = self.client.rpc("match_movies", {
                "query_embedding": embedding,
                "match_count": limit,
                "exclude_id": movie_id,
            }).execute()
            
            return response.data if response.data else []
            
        except Exception as e:
            logger.warning(f"Vector search failed for movie {movie_id}, using genre fallback: {str(e)}")
            try:
                source = self.client.table("movies").select("genre").eq("id", movie_id).single().execute()
                if source.data:
                    genre = source.data.get("genre", "")
                    response = self.client.table("movies") \
                        .select("id, name, genre, poster_path, overview, release_date, vote_average") \
                        .eq("genre", genre) \
                        .neq("id", movie_id) \
                        .order("vote_average", desc=True) \
                        .limit(limit) \
                        .execute()
                    return response.data if response.data else []
            except Exception:
                pass
            return []

    def update_movie_embedding(self, movie_id: int, embedding: list) -> bool:
        """Update a movie's embedding vector."""
        try:
            self.client.table("movies") \
                .update({"embedding": embedding}) \
                .eq("id", movie_id) \
                .execute()
            return True
        except Exception as e:
            logger.error(f"Critical failure updating embedding for movie {movie_id}: {str(e)}", exc_info=True)
            return False

    # ── Taste Vector Operations ──────────────────────────────

    def get_user_taste_profile(self, user_id: str) -> Dict[str, Any]:
        """Fetch taste_vector and like_count_since_update from profiles."""
        try:
            response = self.client.table("profiles") \
                .select("taste_vector, like_count_since_update") \
                .eq("id", user_id) \
                .single() \
                .execute()
            return response.data if response.data else {}
        except Exception as e:
            logger.warning(f"Failed to fetch taste profile for user {user_id}: {str(e)}")
            return {}

    @with_retry()
    def call_update_taste_vector_rpc(self, user_id: str) -> Dict[str, Any]:
        """Call the update_user_taste_vector RPC to recompute the user's semantic fingerprint."""
        try:
            response = self.client.rpc(
                "update_user_taste_vector",
                {"user_id_param": user_id}
            ).execute()
            
            # PostgREST RPC results can be a direct object or a list with one object
            data = response.data
            if isinstance(data, list) and len(data) > 0:
                data = data[0]
            
            if not data or not data.get("success"):
                logger.warning(f"⚠️ RPC for user {user_id} returned failure or no data: {data}")
                return data if data else {"success": False, "status_message": "No data returned from RPC"}

            logger.info(f"🧠 Taste vector RPC success for user {user_id}: {data}")
            return data
        except Exception as e:
            logger.error(f"❌ Failed to call update_user_taste_vector RPC for user {user_id}: {str(e)}", exc_info=True)
            # We don't necessarily want to crash the whole request if the vector update fails
            # but we should signal it clearly.
            return {"success": False, "status_message": str(e)}

    @with_retry()
    def get_semantic_recommendations(
        self, taste_vector: list, user_id: str, limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Get semantically similar movies using the user's taste vector."""
        try:
            response = self.client.rpc(
                "match_movies_for_user",
                {
                    "query_embedding": taste_vector,
                    "match_count": limit,
                    "user_id_param": user_id,
                }
            ).execute()
            return response.data if response.data else []
        except Exception as e:
            logger.warning(f"Semantic recommendations RPC failed for user {user_id}: {str(e)}")
            return []

    @with_retry()
    def update_profile(self, user_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update user profile metadata."""
        try:
            response = self.client.table("profiles") \
                .update(update_data) \
                .eq("id", user_id) \
                .execute()
            
            if not response.data:
                raise NotFoundError(f"Profile for user {user_id} not found")
                
            return response.data[0]
        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"Supabase profile update error for user {user_id}: {str(e)}", exc_info=True)
            raise ServerError("Failed to update profile")
