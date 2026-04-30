"""Collection Pydantic models for user-created movie collections."""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class CollectionCreateRequest(BaseModel):
    """Request body for creating a new collection."""
    name: str = Field(..., min_length=1, max_length=100, description="Collection name")
    description: Optional[str] = Field(None, max_length=500, description="Optional description")
    is_public: bool = Field(True, description="Whether the collection is visible on profile")


class CollectionUpdateRequest(BaseModel):
    """Request body for updating a collection."""
    name: Optional[str] = Field(None, min_length=1, max_length=100, description="New name")
    description: Optional[str] = Field(None, max_length=500, description="New description")
    is_public: Optional[bool] = Field(None, description="Update visibility")


class CollectionMovieRequest(BaseModel):
    """Request body for adding a movie to a collection."""
    movie_id: int = Field(..., description="TMDB movie ID to add")


class CollectionMovieResponse(BaseModel):
    """A movie within a collection."""
    id: int = Field(..., description="Movie ID")
    name: str = Field(..., description="Movie name")
    genre: str = Field("General", description="Movie genre")
    poster_path: Optional[str] = Field(None, description="TMDB poster path")
    vote_average: Optional[float] = Field(None, description="TMDB vote average")
    user_rating: Optional[int] = Field(None, description="User's personal rating (1-5)")

    class Config:
        from_attributes = True


class CollectionResponse(BaseModel):
    """A user collection (summary view — without movies)."""
    id: str = Field(..., description="Collection UUID")
    user_id: str = Field(..., description="Owner's user ID")
    name: str = Field(..., description="Collection name")
    description: Optional[str] = Field(None, description="Optional description")
    is_public: bool = Field(True, description="Profile visibility")
    movie_count: int = Field(0, description="Number of movies in collection")
    cover_poster_path: Optional[str] = Field(None, description="Poster of first movie for cover art")
    created_at: Optional[str] = Field(None, description="Creation timestamp")

    class Config:
        from_attributes = True


class CollectionDetailResponse(CollectionResponse):
    """Full collection detail including its movies."""
    movies: List[CollectionMovieResponse] = Field(default_factory=list, description="Movies in collection")

    class Config:
        from_attributes = True
