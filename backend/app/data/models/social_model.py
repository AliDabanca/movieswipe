"""Social Pydantic models for friendship, compatibility, and profile endpoints."""

from pydantic import BaseModel, Field
from typing import List, Optional


class FriendResponse(BaseModel):
    """A friend's basic profile info."""
    id: str = Field(..., description="User ID")
    username: str = Field(..., description="Username")
    display_name: Optional[str] = Field(None, description="Display name")
    avatar_url: Optional[str] = Field(None, description="Avatar URL")
    is_friend: Optional[bool] = Field(None, description="Whether this user is already a friend")
    is_self: Optional[bool] = Field(None, description="Whether this user is the current user")

    class Config:
        from_attributes = True


class FriendRequestResponse(BaseModel):
    """A friend request with sender/receiver profile info."""
    id: str = Field(..., description="Request ID")
    status: str = Field(..., description="Request status (pending, accepted, rejected)")
    created_at: Optional[str] = Field(None, description="When the request was created")
    profiles: Optional[FriendResponse] = Field(None, description="Sender/receiver profile")

    class Config:
        from_attributes = True


class ShowcaseMovieResponse(BaseModel):
    """A movie shown in a friend's showcase/profile."""
    id: int = Field(..., description="Movie ID")
    name: str = Field(..., description="Movie name")
    poster_path: Optional[str] = Field(None, description="TMDB poster path")
    user_rating: Optional[int] = Field(None, description="Friend's rating (1-5)")

    class Config:
        from_attributes = True


class CompatibilityResponse(BaseModel):
    """Compatibility score and common movies between two users."""
    compatibility_score: int = Field(0, ge=0, le=100, description="Overall compatibility (0-100)")
    common_movie_count: int = Field(0, ge=0, description="Number of commonly liked movies")
    common_movies: List[ShowcaseMovieResponse] = Field(default_factory=list, description="Common liked movies")
    top_overlap_genres: List[str] = Field(default_factory=list, description="Overlapping top genres")

    class Config:
        from_attributes = True


class FriendProfileResponse(BaseModel):
    """Full friend profile with showcase, genres, and compatibility."""
    friend: FriendResponse
    showcase_movies: List[ShowcaseMovieResponse] = Field(default_factory=list)
    top_genres: List[str] = Field(default_factory=list)
    compatibility: CompatibilityResponse

    class Config:
        from_attributes = True
