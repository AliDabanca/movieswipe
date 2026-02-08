"""TMDB API Service for fetching movie data."""

import httpx
from typing import List, Dict, Any
from app.core.config import settings
from app.core.errors import ServerError


class TMDBService:
    """Service for interacting with The Movie Database API."""
    
    BASE_URL = "https://api.themoviedb.org/3"
    IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w500"
    
    def __init__(self):
        self.api_key = settings.tmdb_api_key
        self.client = httpx.AsyncClient()
    
    async def close(self):
        """Close HTTP client."""
        await self.client.aclose()
    
    async def get_popular_movies(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch popular movies from TMDB.
        
        Args:
            page: Page number for pagination
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/movie/popular"
            params = {
                "api_key": self.api_key,
                "language": "en-US",
                "page": page
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("results", [])
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB API error: {str(e)}")
    
    def get_poster_url(self, poster_path: str | None) -> str | None:
        """
        Get full poster URL from TMDB poster path.
        
        Args:
            poster_path: TMDB poster path (e.g., "/abc123.jpg")
            
        Returns:
            Full poster URL or None
        """
        if not poster_path:
            return None
        return f"{self.IMAGE_BASE_URL}{poster_path}"
    
    async def search_movies(self, query: str, page: int = 1) -> List[Dict[str, Any]]:
        """
        Search for movies by title.
        
        Args:
            query: Search query
            page: Page number
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/search/movie"
            params = {
                "api_key": self.api_key,
                "language": "en-US",
                "query": query,
                "page": page
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("results", [])
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB search error: {str(e)}")
    
    async def get_now_playing(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch movies currently in theaters.
        
        Args:
            page: Page number for pagination
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/movie/now_playing"
            params = {
                "api_key": self.api_key,
                "language": "en-US",
                "page": page
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("results", [])
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB now playing error: {str(e)}")
    
    async def get_upcoming(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch upcoming movies.
        
        Args:
            page: Page number for pagination
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/movie/upcoming"
            params = {
                "api_key": self.api_key,
                "language": "en-US",
                "page": page
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("results", [])
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB upcoming error: {str(e)}")

    async def get_movie_details(self, movie_id: int) -> Dict[str, Any]:
        """
        Fetch details for a specific movie.
        
        Args:
            movie_id: TMDB Movie ID
            
        Returns:
            Movie data dictionary
        """
        try:
            url = f"{self.BASE_URL}/movie/{movie_id}"
            params = {
                "api_key": self.api_key,
                "language": "en-US"
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            # Check if 404
            if hasattr(e, "response") and e.response.status_code == 404:
                raise ServerError(f"Movie {movie_id} not found in TMDB")
            raise ServerError(f"TMDB details error: {str(e)}")
