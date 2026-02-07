"""Movie Pydantic model for data layer."""

from pydantic import BaseModel, Field


class MovieModel(BaseModel):
    """Movie data model (Pydantic schema)."""

    id: int = Field(..., description="Movie ID")
    name: str = Field(..., min_length=1, max_length=200, description="Movie name")
    genre: str = Field(..., min_length=1, max_length=50, description="Movie genre")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "The Shawshank Redemption",
                "genre": "Drama",
            }
        }

    def to_entity(self):
        """Convert to domain entity."""
        from app.domain.entities.movie import Movie

        return Movie(id=self.id, name=self.name, genre=self.genre)

    @classmethod
    def from_entity(cls, entity):
        """Create from domain entity."""
        return cls(id=entity.id, name=entity.name, genre=entity.genre)
