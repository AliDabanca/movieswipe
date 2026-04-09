from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from pydantic import BaseModel

from app.services.recommendation_service import RecommendationService
from app.data.models.movie_model import MovieModel
from app.core.auth import get_current_user_id
from app.core.logger import logger

router = APIRouter(prefix="/recommendations", tags=["recommendations"])

# Initialize service
recommendation_service = RecommendationService()


class RecommendationResponse(BaseModel):
    """Wrapped recommendation response with content status."""
    status: str  # "ok" | "end_of_content"
    movies: List[MovieModel]
    message: Optional[str] = None


@router.get("/", response_model=RecommendationResponse)
def get_recommendations(
    user_id: str = Depends(get_current_user_id),
    limit: int = Query(50, ge=1, le=100, description="Number of recommendations")
):
    """
    Get personalized movie recommendations for the authenticated user.
    
    User ID is extracted from JWT token automatically.
    
    Returns:
        RecommendationResponse with:
        - status: "ok" (movies available) or "end_of_content" (pool exhausted)
        - movies: list of recommended movies
        - message: optional user-facing message when end_of_content
    """
    try:
        movies = recommendation_service.get_recommendations(user_id, limit)
        
        if not movies:
            logger.info(f"🏁 End of content for user {user_id}")
            return RecommendationResponse(
                status="end_of_content",
                movies=[],
                message="Keşfedecek film kalmadı! Yeni türler seçmeye ne dersin?",
            )
        
        return RecommendationResponse(
            status="ok",
            movies=[MovieModel.from_entity(movie) for movie in movies],
        )
    except Exception as e:
        logger.error(f"Failed to get recommendations for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get recommendations",
        )


@router.get("/debug/stats")
def get_user_stats(
    user_id: str = Depends(get_current_user_id),
):
    """
    Get user statistics and preferences for debugging.
    User ID is extracted from JWT token automatically.
    
    Returns:
        User statistics including genre preferences
    """
    try:
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        logger.error(f"Failed to get user stats for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get user stats",
        )
