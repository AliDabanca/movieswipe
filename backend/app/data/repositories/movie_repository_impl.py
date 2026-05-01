"""Movie repository implementation with TMDB and Supabase integration."""

from typing import List
from app.domain.entities.movie import Movie
from app.domain.repositories.movie_repository import MovieRepository
from app.data.services.tmdb_service import TMDBService
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.data.models.movie_model import MovieModel
from app.core.errors import NotFoundError, ServerError
from app.core.config import settings


class MovieRepositoryImpl(MovieRepository):
    """Movie repository with TMDB API and Supabase database."""

    def __init__(self):
        self.supabase_ds = SupabaseDataSource()
        # Only initialize TMDB if API key is provided
        self.tmdb_service = TMDBService() if settings.tmdb_api_key else None

    def get_all(self) -> List[Movie]:
        """
        Get all movies from Supabase. If empty and TMDB available, fetch from TMDB and cache.
        
        Returns:
            List of Movie entities
        """
        try:
            movies_data = self.supabase_ds.get_movies(limit=100)
            
            # If Supabase is empty and TMDB is available, fetch from TMDB and save
            if not movies_data and self.tmdb_service:
                import asyncio
                print("📡 Fetching movies from TMDB (5 pages = ~100 movies)...")
                
                # Using asyncio.run here is safe because this runs in FastAPI's threadpool thread
                # which doesn't have a running asyncio loop
                all_tmdb_movies = []
                for page in range(1, 6):
                    try:
                        loop = asyncio.get_event_loop()
                    except RuntimeError:
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        
                    page_movies = loop.run_until_complete(self.tmdb_service.get_popular_movies(page=page))
                    all_tmdb_movies.extend(page_movies)
                    print(f"  📄 Page {page}/5: {len(page_movies)} movies")
                
                # Transform TMDB data to our format
                movies_to_save = []
                for tmdb_movie in all_tmdb_movies[:100]:  # Limit to 100
                    movie_dict = {
                        "id": tmdb_movie["id"],
                        "name": tmdb_movie["title"],
                        "genre": self._extract_genre(tmdb_movie),
                        "poster_path": tmdb_movie.get("poster_path")
                    }
                    movies_to_save.append(movie_dict)
                
                # Save to Supabase
                print(f"💾 Caching {len(movies_to_save)} movies to Supabase...")
                movies_data = self.supabase_ds.save_movies_batch(movies_to_save)
                print(f"✅ {len(movies_data)} movies cached successfully!")
            elif not movies_data:
                print("⚠️  No movies in Supabase and TMDB key not configured")
                return []
            
            # Convert to domain entities
            return [MovieModel(**movie_data).to_entity() for movie_data in movies_data]
            
        except Exception as e:
            print(f"⚠️  Error fetching movies: {e}")
            
            # If Supabase fails and TMDB is available, fallback to TMDB directly
            if self.tmdb_service:
                import asyncio
                try:
                    print("🔄 Falling back to TMDB (1 page)...")
                    try:
                        loop = asyncio.get_event_loop()
                    except RuntimeError:
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        
                    tmdb_movies = loop.run_until_complete(self.tmdb_service.get_popular_movies(page=1))
                    
                    movies = []
                    for tmdb_movie in tmdb_movies[:20]:
                        movie = Movie(
                            id=tmdb_movie["id"],
                            name=tmdb_movie["title"],
                            genre=self._extract_genre(tmdb_movie),
                            poster_path=tmdb_movie.get("poster_path")
                        )
                        movies.append(movie)
                    
                    return movies
                except Exception as tmdb_error:
                    print(f"❌ TMDB fallback failed: {tmdb_error}")
            
            return []

    def get_by_id(self, movie_id: int) -> Movie | None:
        """Get movie by ID from Supabase."""
        try:
            movie_data = self.supabase_ds.get_movie_by_id(movie_id)
            return MovieModel(**movie_data).to_entity()
        except NotFoundError:
            return None
        except Exception as e:
            print(f"⚠️  Error fetching movie {movie_id}: {e}")
            return None

    def create(self, movie: Movie) -> Movie:
        """Create a new movie in Supabase."""
        movie_model = MovieModel.from_entity(movie)
        saved_data = self.supabase_ds.save_movie(movie_model.model_dump())
        return MovieModel(**saved_data).to_entity()

    def swipe(self, movie_id: int, is_like: bool, user_id: str, rating: int | None = None) -> None:
        """Record a swipe action. Auto-imports movie if missing."""
        try:
            self.supabase_ds.save_swipe(user_id, movie_id, is_like, rating)
        except Exception as e:
            # Check if error is related to foreign key constraint (movie_id not found)
            error_str = str(e).lower()
            if "foreign key constraint" in error_str or "violates foreign key" in error_str:
                print(f"⚠️ Movie {movie_id} missing in DB. Attempting Just-in-Time import...")
                
                if not self.tmdb_service:
                    raise ServerError("TMDB service not available for auto-import")
                
                # Fetch details from TMDB
                import asyncio
                try:
                    try:
                        loop = asyncio.get_event_loop()
                    except RuntimeError:
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        
                    tmdb_movie = loop.run_until_complete(self.tmdb_service.get_movie_details(movie_id))
                    
                    # Convert to our format and save
                    movie_dict = {
                        "id": tmdb_movie["id"],
                        "name": tmdb_movie["title"],
                        "genre": self._extract_genre(tmdb_movie),
                        "poster_path": tmdb_movie.get("poster_path")
                    }
                    self.supabase_ds.save_movie(movie_dict)
                    print(f"✅ Auto-imported movie: {tmdb_movie['title']}")
                    
                    # Retry swipe
                    self.supabase_ds.save_swipe(user_id, movie_id, is_like, rating)
                    print(f"✅ Retry swipe successful for movie {movie_id}")
                    return
                except Exception as import_error:
                    print(f"❌ Failed to auto-import movie {movie_id}: {import_error}")
                    raise e
            
            # Re-raise other errors
            raise e
        
        action = "LIKE" if is_like else "PASS"
        print(f"✅ Swipe saved to DB: User {user_id} - Movie {movie_id} - {action} (Rating: {rating})")

    def delete_swipe(self, movie_id: int, user_id: str) -> None:
        """Delete a swipe record (unlike/unpass)."""
        try:
            self.supabase_ds.delete_swipe(user_id, movie_id)
            print(f"✅ Swipe deleted from DB: User {user_id} - Movie {movie_id}")
        except Exception as e:
            print(f"❌ Failed to delete swipe for user {user_id}, movie {movie_id}: {e}")
            raise e
    
    def _extract_genre(self, tmdb_movie: dict) -> str:
        """
        Extract simplified genre from TMDB movie data.
        
        Args:
            tmdb_movie: TMDB movie dictionary
            
        Returns:
            Genre string (defaults to "General")
        """
        genre_ids = tmdb_movie.get("genre_ids", [])
        
        # TMDB Genre ID mapping (simplified)
        genre_map = {
            28: "Action",
            35: "Comedy",
            18: "Drama",
            27: "Horror",
            10749: "Romance",
            878: "Sci-Fi",
            53: "Thriller",
            16: "Animation",
            80: "Crime",
            14: "Fantasy"
        }
        
        if genre_ids:
            return genre_map.get(genre_ids[0], "General")
        
        return "General"


