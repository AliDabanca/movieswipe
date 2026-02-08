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
