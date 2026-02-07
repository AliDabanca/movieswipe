"""Movie repository implementation."""

from typing import List
from app.domain.entities.movie import Movie
from app.domain.repositories.movie_repository import MovieRepository
from app.core.errors import NotFoundError


class MovieRepositoryImpl(MovieRepository):
    """In-memory implementation of Movie repository."""

    def __init__(self):
        # Hardcoded movies for now
        self._movies = [
            Movie(id=1, name="The Shawshank Redemption", genre="Drama"),
            Movie(id=2, name="Inception", genre="Sci-Fi"),
            Movie(id=3, name="The Dark Knight", genre="Action"),
        ]
        self._swipes = []  # Store swipe history

    async def get_all(self) -> List[Movie]:
        """Get all movies."""
        return self._movies.copy()

    async def get_by_id(self, movie_id: int) -> Movie | None:
        """Get movie by ID."""
        for movie in self._movies:
            if movie.id == movie_id:
                return movie
        return None

    async def create(self, movie: Movie) -> Movie:
        """Create a new movie."""
        self._movies.append(movie)
        return movie

    async def swipe(self, movie_id: int, is_like: bool) -> None:
        """Record a swipe action."""
        movie = await self.get_by_id(movie_id)
        if not movie:
            raise NotFoundError(f"Movie with id {movie_id} not found")

        self._swipes.append({"movie_id": movie_id, "is_like": is_like})
