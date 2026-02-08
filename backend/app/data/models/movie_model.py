"""Movie Pydantic model for data layer."""

from pydantic import BaseModel, Field


class MovieModel(BaseModel):
    """Movie data model (Pydantic schema)."""

    id: int = Field(..., description="Movie ID")
    name: str = Field(..., min_length=1, max_length=200, description="Movie name")
    genre: str = Field(..., min_length=1, max_length=50, description="Movie genre")
    poster_path: str | None = Field(None, description="TMDB poster path")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "The Shawshank Redemption",
                "genre": "Drama",
                "poster_path": "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
            }
        }

    def to_entity(self):
        """Convert to domain entity."""
        from app.domain.entities.movie import Movie

        return Movie(id=self.id, name=self.name, genre=self.genre, poster_path=self.poster_path)

    @classmethod
    def from_entity(cls, entity):
        """Create from domain entity."""
        return cls(id=entity.id, name=entity.name, genre=entity.genre, poster_path=entity.poster_path)
