"""Dependency injection for FastAPI."""

from app.domain.repositories.movie_repository import MovieRepository
from app.data.repositories.movie_repository_impl import MovieRepositoryImpl

# Singleton instances
_movie_repository: MovieRepository | None = None


def get_movie_repository() -> MovieRepository:
    """Get movie repository instance."""
    global _movie_repository
    if _movie_repository is None:
        _movie_repository = MovieRepositoryImpl()
    return _movie_repository
