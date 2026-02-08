"""Request/Response schemas for API."""

from pydantic import BaseModel, Field


class SwipeRequest(BaseModel):
    """Swipe request schema."""

    isLike: bool = Field(..., description="True for like, False for pass")
    userId: str = Field(..., description="User ID performing the swipe")

    class Config:
        json_schema_extra = {"example": {"isLike": True, "userId": "00000000-0000-0000-0000-000000000001"}}


class MessageResponse(BaseModel):
    """Generic message response."""

    message: str = Field(..., description="Response message")

    class Config:
        json_schema_extra = {"example": {"message": "Success"}}
