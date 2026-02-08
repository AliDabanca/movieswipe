"""User management API routes."""

from fastapi import APIRouter, status, HTTPException, Query
from typing import List
from uuid import uuid4

from app.services.recommendation_service import RecommendationService
from app.core.errors import ServerError

router = APIRouter(prefix="/users", tags=["users"])

# Initialize service
recommendation_service = RecommendationService()


@router.get("/")
async def get_users():
    """
    Get list of all users with basic statistics.
    
    Returns:
        List of users with swipe counts and preferences
    """
    try:
        # For now, we'll get distinct user_ids from swipes
        # In production, you'd have a proper users table
        users = recommendation_service.get_all_users()
        return users
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch users: {str(e)}",
        )


@router.post("/")
async def create_user():
    """
    Create a new user.
    
    Returns:
        New user object with UUID
    """
    user_id = str(uuid4())
    return {
        "user_id": user_id,
        "created": True,
        "message": f"User {user_id} created successfully"
    }


@router.get("/{user_id}/profile")
async def get_user_profile(user_id: str):
    """
    Get detailed user profile with preferences.
    
    Args:
        user_id: User UUID
        
    Returns:
        User statistics and genre preferences
    """
    try:
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user profile: {str(e)}",
        )


@router.get("/{user_id}/liked-movies")
async def get_liked_movies(user_id: str):
    """
    Get user's liked movies grouped by genre.
    
    Args:
        user_id: User UUID
        
    Returns:
        Movies grouped by genre {"Action": [...], "Drama": [...]}
    """
    try:
        movies = recommendation_service.get_liked_movies_by_genre(user_id)
        return movies
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch liked movies: {str(e)}",
        )


@router.get("/{user_id}/stats")
async def get_detailed_stats(user_id: str):
    """
    Get detailed user statistics.
    
    Args:
        user_id: User UUID
        
    Returns:
        Detailed user statistics
    """
    try:
        # For now, use same as profile endpoint
        # Can be extended with more detailed analytics later
        stats = recommendation_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user stats: {str(e)}",
        )


@router.get("/compare")
async def compare_users(user_ids: str = Query(..., description="Comma-separated user IDs")):
    """
    Compare multiple user profiles.
    
    Args:
        user_ids: Comma-separated list of user UUIDs
        
    Returns:
        List of user profiles for comparison
    """
    try:
        ids = [uid.strip() for uid in user_ids.split(",")]
        profiles = []
        
        for user_id in ids:
            try:
                stats = recommendation_service.get_user_stats(user_id)
                profiles.append(stats)
            except Exception as e:
                print(f"⚠️  Error getting profile for {user_id}: {e}")
                continue
        
        return profiles
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to compare users: {str(e)}",
        )
