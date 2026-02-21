"""Recommendation routes."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List

from app.services.recommendation_service import RecommendationService
from app.data.models.movie_model import MovieModel
from app.core.errors import ServerError
from app.core.auth import get_current_user_id

router = APIRouter(prefix="/recommendations", tags=["recommendations"])

# Initialize service
recommendation_service = RecommendationService()


@router.get("/", response_model=List[MovieModel])
async def get_recommendations(
    user_id: str = Depends(get_current_user_id),
    limit: int = Query(50, ge=1, le=100, description="Number of recommendations")
):
    """
    Get personalized movie recommendations for the authenticated user.
    
    User ID is extracted from JWT token automatically.
    
    Strategy:
    - Users with < 5 likes: Random/popular movies (cold start)
    - Users with 5+ likes: 70% personalized + 30% discovery
    
    Args:
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user stats: {str(e)}",
        )
