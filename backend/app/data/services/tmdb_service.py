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

    async def get_top_rated(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch top rated movies from TMDB.
        
        Args:
            page: Page number for pagination
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/movie/top_rated"
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
            raise ServerError(f"TMDB top rated error: {str(e)}")

    async def get_trending(self, page: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch trending movies this week from TMDB.
        
        Args:
            page: Page number for pagination
            
        Returns:
            List of movie data dictionaries
        """
        try:
            url = f"{self.BASE_URL}/trending/movie/week"
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
            raise ServerError(f"TMDB trending error: {str(e)}")

    async def get_movie_details(self, movie_id: int, language: str = "en-US") -> Dict[str, Any]:
        """
        Fetch details for a specific movie with credits.
        
        Args:
            movie_id: TMDB Movie ID
            language: Language code for localization
            
        Returns:
            Movie data dictionary with credits
        """
        try:
            url = f"{self.BASE_URL}/movie/{movie_id}"
            params = {
                "api_key": self.api_key,
                "language": language,
                "append_to_response": "credits"
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            if hasattr(e, "response") and e.response.status_code == 404:
                raise ServerError(f"Movie {movie_id} not found in TMDB")
            print(f"❌ TMDB API connection error for movie {movie_id}: {str(e)}")
            raise ServerError(f"TMDB details error: {str(e)}")

    async def get_movie_details_enriched(self, movie_id: int) -> Dict[str, Any]:
        """
        Fetch enriched movie details with TR/EN fallback and extracted credits.
        
        Strategy:
            1. Fetch with language=tr-TR (includes credits)
            2. If Turkish overview is empty, fetch EN overview separately
            3. Extract director from crew, top 5 cast
        
        Returns:
            Enriched movie dict with: director, cast, overview_tr, runtime, tagline
        """
        # Step 1: Fetch in Turkish (with credits)
        data = await self.get_movie_details(movie_id, language="tr-TR")
        
        overview_tr = data.get("overview", "")
        overview_en = ""
        
        # Step 2: If Turkish overview empty, get English
        if not overview_tr or len(overview_tr.strip()) == 0:
            try:
                en_data = await self.get_movie_details(movie_id, language="en-US")
                overview_en = en_data.get("overview", "")
                # Also use EN overview as fallback
                overview_tr = overview_en
            except Exception:
                pass
        else:
            # Still fetch EN for potential use
            try:
                en_data = await self.get_movie_details(movie_id, language="en-US")
                overview_en = en_data.get("overview", "")
            except Exception:
                overview_en = overview_tr
        
        # Step 3: Extract director from credits.crew
        director = None
        credits = data.get("credits", {})
        crew = credits.get("crew", [])
        for member in crew:
            if member.get("job") == "Director":
                director = member.get("name")
                break
        
        # Step 4: Extract top 5 cast
        cast_list = credits.get("cast", [])
        cast_names = [actor.get("name", "") for actor in cast_list[:5]]
        cast_profiles = [
            {
                "name": actor.get("name", ""),
                "character": actor.get("character", ""),
                "profile_path": actor.get("profile_path"),
            }
            for actor in cast_list[:5]
        ]
        
        return {
            "id": data.get("id"),
            "name": data.get("title", data.get("name", "Unknown")),
            "genre": self._extract_genre_from_details(data),
            "genres": [g.get("name", "") for g in data.get("genres", [])],
            "poster_path": data.get("poster_path"),
            "backdrop_path": data.get("backdrop_path"),
            "overview": overview_tr,
            "overview_en": overview_en,
            "release_date": data.get("release_date"),
            "vote_average": data.get("vote_average", 0),
            "vote_count": data.get("vote_count", 0),
            "runtime": data.get("runtime"),
            "tagline": data.get("tagline"),
            "director": director,
            "cast": cast_names,
            "cast_details": cast_profiles,
            "original_language": data.get("original_language"),
        }
    
    async def get_watch_providers(self, movie_id: int, country: str = "TR") -> Dict[str, Any]:
        """
        Fetch watch/streaming providers for a movie from TMDB.
        
        Args:
            movie_id: TMDB Movie ID
            country: ISO 3166-1 country code (default: TR for Turkey)
            
        Returns:
            Dict with 'providers' list and 'tmdb_link'
        """
        try:
            url = f"{self.BASE_URL}/movie/{movie_id}/watch/providers"
            params = {"api_key": self.api_key}
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            results = data.get("results", {})
            country_data = results.get(country, {})
            
            # If no data for requested country, try US as fallback
            if not country_data and country != "US":
                country_data = results.get("US", {})
            
            providers = []
            tmdb_link = country_data.get("link", "")
            
            # Collect all provider types
            for provider_type in ["flatrate", "rent", "buy"]:
                for p in country_data.get(provider_type, []):
                    # Avoid duplicates (same provider can appear in multiple types)
                    if not any(existing["provider_id"] == p.get("provider_id") for existing in providers):
                        providers.append({
                            "provider_id": p.get("provider_id"),
                            "provider_name": p.get("provider_name", "Unknown"),
                            "logo_path": p.get("logo_path"),
                            "provider_type": provider_type,
                        })
            
            return {
                "providers": providers,
                "tmdb_link": tmdb_link,
            }
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB watch providers error: {str(e)}")
    
    @staticmethod
    def _extract_genre_from_details(data: Dict) -> str:
        """Extract primary genre from TMDB details response."""
        genres = data.get("genres", [])
        if genres:
            return genres[0].get("name", "General")
        return "General"
