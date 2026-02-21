"""User management API routes."""

from fastapi import APIRouter, Depends, status, HTTPException

from app.services.recommendation_service import RecommendationService
from app.core.auth import get_current_user_id

router = APIRouter(prefix="/users", tags=["users"])

# Initialize service
recommendation_service = RecommendationService()


@router.get("/me/profile")
async def get_my_profile(user_id: str = Depends(get_current_user_id)):
    """
    Get the current user's profile with preferences.
    User ID comes from JWT token.
    """
    try:
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user profile: {str(e)}",
        )


@router.get("/me/liked-movies")
async def get_my_liked_movies(user_id: str = Depends(get_current_user_id)):
    """
    Get the current user's liked movies grouped by genre.
    User ID comes from JWT token.
    """
    try:
        movies = recommendation_service.get_liked_movies_by_genre(user_id)
        return movies
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch liked movies: {str(e)}",
        )


@router.get("/me/stats")
async def get_my_stats(user_id: str = Depends(get_current_user_id)):
    """
    Get detailed user statistics.
    User ID comes from JWT token.
    """
    try:
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user stats: {str(e)}",
        )
