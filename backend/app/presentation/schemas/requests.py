"""Request/Response schemas for API."""

from pydantic import BaseModel, Field


class SwipeRequest(BaseModel):
    """Swipe request schema."""

    isLike: bool = Field(..., description="True for like, False for pass")
    rating: int | None = Field(None, ge=1, le=5, description="Optional rating (1-5 stars) for liked movies")

    class Config:
        json_schema_extra = {"example": {"isLike": True, "rating": 5}}


class MessageResponse(BaseModel):
    """Generic message response."""

    message: str = Field(..., description="Response message")

    class Config:
        json_schema_extra = {"example": {"message": "Success"}}


VALID_WATCH_STATUSES = {"watched", "watch_later", "favorite", "dropped"}


class WatchStatusRequest(BaseModel):
    """Watch status update request."""

    watch_status: str | None = Field(
        None,
        description="Watch status: watched, watch_later, favorite, dropped, or null to clear",
    )

    class Config:
        json_schema_extra = {"example": {"watch_status": "watched"}}
