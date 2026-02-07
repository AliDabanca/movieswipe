from pydantic import BaseModel


class Movie(BaseModel):
    """Movie model representing a movie with basic information."""
    
    id: int
    name: str
    genre: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "The Shawshank Redemption",
                "genre": "Drama"
            }
        }
