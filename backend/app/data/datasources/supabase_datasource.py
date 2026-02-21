"""Supabase datasource for movie persistence."""

from supabase import create_client, Client
from typing import List, Dict, Any
from app.core.config import settings
from app.core.errors import ServerError, NotFoundError


class SupabaseDataSource:
    """Data source for Supabase database operations."""
    
    def __init__(self):
        """Initialize Supabase client."""
        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
    
    def get_movies(self, limit: int = 20) -> List[Dict[str, Any]]:
        """
        Fetch movies from Supabase.
        
        Args:
            limit: Maximum number of movies to fetch
            
        Returns:
            List of movie dictionaries
        """
        try:
            response = self.client.table("movies").select("*").limit(limit).execute()
            return response.data
        except Exception as e:
            raise ServerError(f"Supabase fetch error: {str(e)}")
    
    def save_movie(self, movie_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Save a single movie to Supabase.
        
        Args:
            movie_data: Movie data dictionary
            
        Returns:
            Saved movie data
        """
        try:
            # Use upsert to avoid duplicates (on conflict update)
            response = self.client.table("movies").upsert(
                movie_data,
                on_conflict="id"
            ).execute()
            
            if not response.data:
                raise ServerError("Failed to save movie")
            
            return response.data[0]
        except Exception as e:
            raise ServerError(f"Supabase save error: {str(e)}")
    
    def save_movies_batch(self, movies_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Save multiple movies to Supabase in batch.
        
        Args:
            movies_data: List of movie data dictionaries
            
        Returns:
            List of saved movie data
        """
        try:
            response = self.client.table("movies").upsert(
                movies_data,
                on_conflict="id"
            ).execute()
            
            return response.data
        except Exception as e:
            raise ServerError(f"Supabase batch save error: {str(e)}")
    
    def get_movie_by_id(self, movie_id: int) -> Dict[str, Any]:
        """
        Get a single movie by ID.
        
        Args:
            movie_id: Movie ID
            
        Returns:
            Movie data dictionary
        """
        try:
            response = self.client.table("movies").select("*").eq("id", movie_id).execute()
            
            if not response.data:
                raise NotFoundError(f"Movie with ID {movie_id} not found")
            
            return response.data[0]
        except NotFoundError:
            raise
        except Exception as e:
            raise ServerError(f"Supabase fetch error: {str(e)}")
            
    def get_movies_by_ids(self, movie_ids: List[int]) -> List[Dict[str, Any]]:
        """
        Get multiple movies by their IDs.
        
        Args:
            movie_ids: List of Movie IDs
            
        Returns:
            List of movie data dictionaries
        """
        if not movie_ids:
            return []
            
        try:
            response = self.client.table("movies").select("*").in_("id", movie_ids).execute()
            return response.data
        except Exception as e:
            raise ServerError(f"Supabase batch fetch error: {str(e)}")
    
    def save_swipe(self, user_id: str, movie_id: int, is_like: bool) -> Dict[str, Any]:
        """
        Save a user swipe to the database.
        Uses upsert to handle duplicate swipes gracefully.
        
        Args:
            user_id: User ID
            movie_id: Movie ID
            is_like: Whether the user liked the movie
            
        Returns:
            Saved swipe data
        """
        try:
            swipe_data = {
                "user_id": user_id,
                "movie_id": movie_id,
                "is_like": is_like
            }
            
            # Use upsert to update if exists, insert if not
            response = self.client.table("user_swipes")\
                .upsert(swipe_data, on_conflict="user_id,movie_id")\
                .execute()
            
            if not response.data:
                raise ServerError("Failed to save swipe")
            
            return response.data[0]
        except Exception as e:
            raise ServerError(f"Supabase swipe save error: {str(e)}")
    
    def get_user_swipes(self, user_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get all swipes for a user.
        
        Args:
            user_id: User ID
            limit: Maximum number of swipes to fetch
            
        Returns:
            List of swipe dictionaries
        """
        try:
            response = self.client.table("user_swipes").select("*").eq("user_id", user_id).order("swiped_at", desc=True).limit(limit).execute()
            return response.data
        except Exception as e:
            raise ServerError(f"Supabase swipe fetch error: {str(e)}")
    
    def get_user_liked_movie_ids(self, user_id: str) -> List[int]:
        """
        Get IDs of movies the user liked.
        
        Args:
            user_id: User ID
            
        Returns:
            List of movie IDs
        """
        try:
            response = self.client.table("user_swipes").select("movie_id").eq("user_id", user_id).eq("is_like", True).execute()
            return [swipe["movie_id"] for swipe in response.data]
        except Exception as e:
            raise ServerError(f"Supabase liked movies fetch error: {str(e)}")
    
    def get_user_swiped_movie_ids(self, user_id: str) -> List[int]:
        """
        Get IDs of all movies the user has swiped (liked or passed).
        
        Args:
            user_id: User ID
            
        Returns:
            List of movie IDs
        """
        try:
            response = self.client.table("user_swipes").select("movie_id").eq("user_id", user_id).execute()
            return [swipe["movie_id"] for swipe in response.data]
        except Exception as e:
            raise ServerError(f"Supabase swiped movies fetch error: {str(e)}")

    def get_unseen_movies(self, user_id: str, limit: int = 200) -> List[Dict[str, Any]]:
        """
        Get movies the user hasn't swiped yet.
        Uses Supabase RPC if available, falls back to Python-side filtering.
        
        Args:
            user_id: User ID
            limit: Maximum number of movies to return
            
        Returns:
            List of unseen movie dictionaries
        """
        try:
            # Try Supabase RPC first (fastest)
            response = self.client.rpc(
                "get_unseen_movies",
                {"p_user_id": user_id, "p_limit": limit}
            ).execute()
            return response.data
        except Exception as rpc_error:
            # Fallback: Python-side filtering
            print(f"⚠️  RPC fallback (get_unseen_movies): {rpc_error}")
            try:
                all_movies = self.get_movies(limit=10000)
                swiped_ids = set(self.get_user_swiped_movie_ids(user_id))
                unseen = [m for m in all_movies if m["id"] not in swiped_ids]
                # Sort by vote_average descending
                unseen.sort(key=lambda m: m.get("vote_average") or 0, reverse=True)
                return unseen[:limit]
            except Exception as e:
                raise ServerError(f"Failed to get unseen movies: {str(e)}")

    def get_user_genre_stats(self, user_id: str) -> List[Dict[str, Any]]:
        """
        Get user's genre-level like/pass statistics.
        Uses Supabase RPC if available, falls back to Python-side computation.
        
        Args:
            user_id: User ID
            
        Returns:
            List of dicts with genre, like_count, pass_count, total_count
        """
        try:
            # Try Supabase RPC first
            response = self.client.rpc(
                "get_user_genre_stats",
                {"p_user_id": user_id}
            ).execute()
            return response.data
        except Exception as rpc_error:
            # Fallback: Python-side computation
            print(f"⚠️  RPC fallback (get_user_genre_stats): {rpc_error}")
            try:
                swipes = self.get_user_swipes(user_id, limit=10000)
                if not swipes:
                    return []
                
                # Get movie details for genres
                movie_ids = [s["movie_id"] for s in swipes]
                movies = self.get_movies_by_ids(movie_ids)
                movie_map = {m["id"]: m for m in movies}
                
                # Compute genre stats
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
                raise ServerError(f"Failed to get genre stats: {str(e)}")

    def get_similar_movies(self, movie_id: int, limit: int = 3) -> List[Dict[str, Any]]:
        """Get similar movies using pgvector cosine similarity.
        
        Args:
            movie_id: Source movie ID
            limit: Number of similar movies to return
            
        Returns:
            List of similar movie dicts ordered by similarity
        """
        try:
            # First get the source movie's embedding
            movie = self.client.table("movies").select("embedding").eq("id", movie_id).single().execute()
            
            if not movie.data or not movie.data.get("embedding"):
                # Fallback: return movies with same genre
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
            
            # Use RPC to find similar movies via vector search
            embedding = movie.data["embedding"]
            response = self.client.rpc("match_movies", {
                "query_embedding": embedding,
                "match_count": limit,
                "exclude_id": movie_id,
            }).execute()
            
            return response.data if response.data else []
            
        except Exception as e:
            print(f"⚠️  Vector search failed, using genre fallback: {e}")
            # Fallback: same genre, highest rated
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
        """Update a movie's embedding vector.
        
        Args:
            movie_id: Movie ID
            embedding: List of floats (384-dim vector)
            
        Returns:
            True if successful
        """
        try:
            self.client.table("movies") \
                .update({"embedding": embedding}) \
                .eq("id", movie_id) \
                .execute()
            return True
        except Exception as e:
            print(f"⚠️  Failed to update embedding for movie {movie_id}: {e}")
            return False
