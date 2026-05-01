"""User Pydantic models for data layer."""

from typing import Optional, List
from pydantic import BaseModel, Field


class UserProfileUpdate(BaseModel):
    """Model for updating user profile fields. All fields are optional."""

    display_name: Optional[str] = Field(None, min_length=1, max_length=100, description="Display name")
    username: Optional[str] = Field(None, min_length=1, max_length=50, description="Username")
    avatar_url: Optional[str] = Field(None, description="Avatar image URL")
    cover_photo_url: Optional[str] = Field(None, description="Cover photo URL")
    pinned_movie_ids: Optional[List[int]] = Field(None, description="List of pinned movie IDs")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "display_name": "John Doe",
                "username": "johndoe",
                "avatar_url": "https://example.com/avatar.jpg",
            }
        }
