"""Recommendation routes."""

from fastapi import APIRouter, HTTPException, status, Query
from typing import List

from app.services.recommendation_service import RecommendationService
from app.data.models.movie_model import MovieModel
from app.core.errors import ServerError

router = APIRouter(prefix="/recommendations", tags=["recommendations"])

# Initialize service
recommendation_service = RecommendationService()


@router.get("/", response_model=List[MovieModel])
async def get_recommendations(
    user_id: str = Query("00000000-0000-0000-0000-000000000001", description="User ID (UUID format)"),
    limit: int = Query(50, ge=1, le=100, description="Number of recommendations")
):
    """
    Get personalized movie recommendations for a user.
    
    Strategy:
    - Users with < 5 likes: Random/popular movies (cold start)
    - Users with 5+ likes: 70% personalized + 30% discovery
    
    Args:
        user_id: User ID
        limit: Number of recommendations to return
        
    Returns:
        List of recommended movies
    """
    try:
        movies = recommendation_service.get_recommendations(user_id, limit)
        return [MovieModel.from_entity(movie) for movie in movies]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get recommendations: {str(e)}",
        )


@router.get("/debug/stats")
async def get_user_stats(
    user_id: str = Query("00000000-0000-0000-0000-000000000001", description="User ID (UUID format)")
):
    """
    Get user statistics and preferences for debugging.
    
    Args:
        user_id: User ID
        
    Returns:
        User statistics including genre preferences
    """
    try:
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user stats: {str(e)}",
        )
