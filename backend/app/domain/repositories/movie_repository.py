"""Movie repository interface (abstract)."""

from abc import ABC, abstractmethod
from typing import List
from app.domain.entities.movie import Movie


class MovieRepository(ABC):
    """Abstract repository for Movie entity."""

    @abstractmethod
    def get_all(self) -> List[Movie]:
        """Get all movies."""
        pass

    @abstractmethod
    def get_by_id(self, movie_id: int) -> Movie | None:
        """Get movie by ID."""
        pass

    @abstractmethod
    def create(self, movie: Movie) -> Movie:
        """Create a new movie."""
        pass

    @abstractmethod
    def swipe(self, movie_id: int, is_like: bool, user_id: str, rating: int | None = None) -> None:
        """Record a swipe action."""
        pass

    @abstractmethod
    def delete_swipe(self, movie_id: int, user_id: str) -> None:
        """Delete a swipe record (unlike/unpass)."""
        pass
