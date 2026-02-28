from fastapi import APIRouter, Depends, status, HTTPException

from app.services.recommendation_service import RecommendationService
from app.services.embedding_service import embedding_service
from app.core.auth import get_current_user_id
from app.core.logger import logger

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
        logger.error(f"Failed to fetch profile for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user profile",
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
        logger.error(f"Failed to fetch liked movies for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch liked movies",
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
        logger.error(f"Failed to fetch stats for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user stats",
        )


@router.post("/me/update-taste-vector")
async def update_taste_vector(user_id: str = Depends(get_current_user_id)):
    """
    Manually trigger a recalculation of the user's semantic taste vector.
    
    This averages all liked movie embeddings into a single 384-dim vector
    and stores it in the profiles table. Useful for testing and debugging.
    """
    try:
        result = embedding_service.force_update_taste_vector(user_id)
        return {
            "message": "Taste vector updated successfully",
            "details": result,
        }
    except Exception as e:
        logger.error(f"Failed to update taste vector for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update taste vector",
        )
