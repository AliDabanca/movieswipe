"""Direct Movie Share DM Pydantic models for request/response validation."""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from uuid import UUID

from app.data.models.social_model import FriendResponse
from app.data.models.movie_model import MovieModel


class MovieShareRequest(BaseModel):
    """Request model for sharing a movie directly with a friend."""
    receiver_id: UUID = Field(..., description="Friend's profile UUID")
    movie_id: int = Field(..., description="Movie ID from database")


class MovieShareResponse(BaseModel):
    """Response model for a direct movie share record."""
    id: UUID = Field(..., description="Unique share record UUID")
    sender_id: UUID = Field(..., description="Sender profile UUID")
    receiver_id: UUID = Field(..., description="Receiver profile UUID")
    movie_id: int = Field(..., description="Shared movie ID")
    reaction: Optional[str] = Field(None, description="Emoji reaction like ❤️, 🍿, 🔥, 👍")
    created_at: datetime = Field(..., description="Share timestamp")
    is_viewed: bool = Field(..., description="Whether receiver viewed the bilet")
    movie: Optional[MovieModel] = Field(None, description="Shared movie details")

    class Config:
        from_attributes = True


class MovieDmListResponse(BaseModel):
    """Response model for an item in the user's direct messages list."""
    friend: FriendResponse = Field(..., description="Friend's profile details")
    last_share: Optional[MovieShareResponse] = Field(None, description="Most recent movie shared")
    unread_count: int = Field(0, description="Unread message count from this friend")
    share_streak: int = Field(0, description="Active daily sharing streak count")

    class Config:
        from_attributes = True


class ReactionUpdateRequest(BaseModel):
    """Request model for updating or removing an emoji reaction."""
    reaction: Optional[str] = Field(None, max_length=10, description="Emoji character e.g. ❤️, 🍿, 🔥, 👍, or null to remove")
