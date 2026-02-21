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

    def __eq__(self, other):
        if not isinstance(other, Movie):
            return False
        return self.id == other.id

    def __hash__(self):
        return hash(self.id)
