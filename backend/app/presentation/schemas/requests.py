"""Request/Response schemas for API."""

from pydantic import BaseModel, Field


class SwipeRequest(BaseModel):
    """Swipe request schema."""

    isLike: bool = Field(..., description="True for like, False for pass")

    class Config:
        json_schema_extra = {"example": {"isLike": True}}


class MessageResponse(BaseModel):
    """Generic message response."""

    message: str = Field(..., description="Response message")

    class Config:
        json_schema_extra = {"example": {"message": "Success"}}
