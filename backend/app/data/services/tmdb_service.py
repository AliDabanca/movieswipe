"""TMDB API Service for fetching movie data with Redis caching."""

import json
import asyncio
import httpx
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.errors import ServerError
from app.core.redis import get_redis_client
from app.core.logger import logger


# Cache TTL constants (seconds)
CACHE_TTL_LIST = 3600         # 1 hour for list endpoints (popular, trending, etc.)
CACHE_TTL_DETAILS = 86400     # 24 hours for movie details
CACHE_TTL_SEARCH = 1800       # 30 minutes for search results
CACHE_TTL_PROVIDERS = 86400   # 24 hours for watch providers


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

    # ── Cache helpers ─────────────────────────────────────────────────
    _redis_available: bool | None = None  # None = not checked yet

    @classmethod
    async def _check_redis_once(cls) -> bool:
        """Check Redis availability exactly once per application lifetime."""
        if cls._redis_available is not None:
            return cls._redis_available
        try:
            rc = await get_redis_client()
            await rc.ping()
            cls._redis_available = True
            logger.info("Redis connected successfully - caching enabled")
        except Exception as e:
            cls._redis_available = False
            logger.warning(f"Redis unavailable - caching disabled for this session: {e}")
        return cls._redis_available

    async def _cache_get(self, key: str) -> Optional[Any]:
        """Get a value from Redis cache. Returns None on miss or error."""
        if not await TMDBService._check_redis_once():
            return None
        try:
            rc = await get_redis_client()
            cached = await rc.get(key)
            if cached:
                return json.loads(cached)
        except Exception as e:
            TMDBService._redis_available = False
            logger.warning(f"Redis error during get, disabling cache: {e}")
        return None

    async def _cache_set(self, key: str, value: Any, ttl: int) -> None:
        """Set a value in Redis cache with TTL. Silently ignores errors."""
        if not await TMDBService._check_redis_once():
            return
        try:
            rc = await get_redis_client()
            await rc.set(key, json.dumps(value), ex=ttl)
        except Exception as e:
            TMDBService._redis_available = False
            logger.warning(f"Redis error during set, disabling cache: {e}")

    # ── List endpoints (with caching) ─────────────────────────────────
    async def get_popular_movies(self, page: int = 1) -> List[Dict[str, Any]]:
        """Fetch popular movies from TMDB (cached 1h)."""
        cache_key = f"tmdb:popular:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/popular"
            params = {"api_key": self.api_key, "language": "en-US", "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_LIST)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB API error: {str(e)}")
    
    def get_poster_url(self, poster_path: str | None) -> str | None:
        """Get full poster URL from TMDB poster path."""
        if not poster_path:
            return None
        return f"{self.IMAGE_BASE_URL}{poster_path}"
    
    async def search_movies(self, query: str, page: int = 1) -> List[Dict[str, Any]]:
        """Search for movies by title (cached 30m)."""
        cache_key = f"tmdb:search:{query.lower().strip()}:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/search/movie"
            params = {"api_key": self.api_key, "language": "en-US", "query": query, "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_SEARCH)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB search error: {str(e)}")
    
    async def get_now_playing(self, page: int = 1) -> List[Dict[str, Any]]:
        """Fetch movies currently in theaters (cached 1h)."""
        cache_key = f"tmdb:now_playing:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/now_playing"
            params = {"api_key": self.api_key, "language": "en-US", "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_LIST)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB now playing error: {str(e)}")
    
    async def get_upcoming(self, page: int = 1) -> List[Dict[str, Any]]:
        """Fetch upcoming movies (cached 1h)."""
        cache_key = f"tmdb:upcoming:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/upcoming"
            params = {"api_key": self.api_key, "language": "en-US", "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_LIST)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB upcoming error: {str(e)}")

    async def get_top_rated(self, page: int = 1) -> List[Dict[str, Any]]:
        """Fetch top rated movies from TMDB (cached 1h)."""
        cache_key = f"tmdb:top_rated:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/top_rated"
            params = {"api_key": self.api_key, "language": "en-US", "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_LIST)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB top rated error: {str(e)}")

    async def get_trending(self, page: int = 1) -> List[Dict[str, Any]]:
        """Fetch trending movies this week from TMDB (cached 1h)."""
        cache_key = f"tmdb:trending:{page}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/trending/movie/week"
            params = {"api_key": self.api_key, "language": "en-US", "page": page}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            results = response.json().get("results", [])
            await self._cache_set(cache_key, results, CACHE_TTL_LIST)
            return results
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB trending error: {str(e)}")

    # ── Detail endpoints (with caching) ───────────────────────────────
    async def get_movie_details(self, movie_id: int, language: str = "en-US") -> Dict[str, Any]:
        """Fetch details for a specific movie with credits (cached 24h)."""
        cache_key = f"tmdb:details:{movie_id}:{language}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/{movie_id}"
            params = {
                "api_key": self.api_key,
                "language": language,
                "append_to_response": "credits"
            }
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            await self._cache_set(cache_key, data, CACHE_TTL_DETAILS)
            return data
        except httpx.HTTPError as e:
            if hasattr(e, "response") and e.response.status_code == 404:
                raise ServerError(f"Movie {movie_id} not found in TMDB")
            logger.error(f"TMDB API connection error for movie {movie_id}: {str(e)}")
            raise ServerError(f"TMDB details error: {str(e)}")

    async def get_movie_details_enriched(self, movie_id: int) -> Dict[str, Any]:
        """
        Fetch enriched movie details with TR/EN fallback and extracted credits.
        Uses asyncio.gather to fetch TR and EN details concurrently.
        """
        # Fetch TR and EN details concurrently
        tr_task = self.get_movie_details(movie_id, language="tr-TR")
        en_task = self.get_movie_details(movie_id, language="en-US")

        results = await asyncio.gather(tr_task, en_task, return_exceptions=True)
        
        data = results[0] if not isinstance(results[0], Exception) else None
        en_data = results[1] if not isinstance(results[1], Exception) else None

        if data is None:
            if en_data is None:
                raise ServerError(f"Failed to fetch details for movie {movie_id}")
            data = en_data

        overview_tr = data.get("overview", "")
        overview_en = en_data.get("overview", "") if en_data else ""
        
        # If Turkish overview empty, use English as fallback
        if not overview_tr or len(overview_tr.strip()) == 0:
            overview_tr = overview_en
        
        # Extract director from credits.crew
        director = None
        credits = data.get("credits", {})
        crew = credits.get("crew", [])
        for member in crew:
            if member.get("job") == "Director":
                director = member.get("name")
                break
        
        # Extract top 5 cast
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
        """Fetch watch/streaming providers for a movie from TMDB (cached 24h)."""
        cache_key = f"tmdb:providers:{movie_id}:{country}"
        cached = await self._cache_get(cache_key)
        if cached is not None:
            return cached

        try:
            url = f"{self.BASE_URL}/movie/{movie_id}/watch/providers"
            params = {"api_key": self.api_key}
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            results = data.get("results", {})
            country_data = results.get(country, {})
            
            if not country_data and country != "US":
                country_data = results.get("US", {})
            
            providers = []
            tmdb_link = country_data.get("link", "")
            
            for provider_type in ["flatrate", "rent", "buy"]:
                for p in country_data.get(provider_type, []):
                    if not any(existing["provider_id"] == p.get("provider_id") for existing in providers):
                        providers.append({
                            "provider_id": p.get("provider_id"),
                            "provider_name": p.get("provider_name", "Unknown"),
                            "logo_path": p.get("logo_path"),
                            "provider_type": provider_type,
                        })
            
            result = {"providers": providers, "tmdb_link": tmdb_link}
            await self._cache_set(cache_key, result, CACHE_TTL_PROVIDERS)
            return result
            
        except httpx.HTTPError as e:
            raise ServerError(f"TMDB watch providers error: {str(e)}")
    
    @staticmethod
    def _extract_genre_from_details(data: Dict) -> str:
        """Extract primary genre from TMDB details response."""
        genres = data.get("genres", [])
        if genres:
            return genres[0].get("name", "General")
        return "General"
