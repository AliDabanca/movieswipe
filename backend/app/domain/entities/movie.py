"""Movie domain entity."""

from dataclasses import dataclass


@dataclass
class Movie:
    """Movie entity - business logic representation."""

    id: int
    name: str
    genre: str
    poster_path: str | None = None
    overview: str | None = None
    release_date: str | None = None
    vote_average: float | None = None
    user_rating: int | None = None
    # Contextual recommendation metadata (not intrinsic movie data)
    recommendation_reason: dict | None = None  # {"code": "genre_match", "text": "Senin Türün: Sci-Fi"}

    def __eq__(self, other):
        if not isinstance(other, Movie):
            return False
        return self.id == other.id

    def __hash__(self):
        return hash(self.id)
