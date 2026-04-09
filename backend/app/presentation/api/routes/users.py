from fastapi import APIRouter, Depends, status, HTTPException

from app.services.recommendation_service import RecommendationService
from app.services.embedding_service import embedding_service
from app.core.auth import get_current_user_id
from app.core.logger import logger
from app.data.models.user_model import UserProfileUpdate
from app.data.datasources.supabase_datasource import SupabaseDataSource

router = APIRouter(prefix="/users", tags=["users"])

# Initialize services
recommendation_service = RecommendationService()
supabase_ds = SupabaseDataSource()


@router.get("/me/profile")
def get_my_profile(user_id: str = Depends(get_current_user_id)):
    """
    Get the current user's profile with stats and preferences.
    """
    try:
        # Get basic profile info from Supabase
        profile_data = supabase_ds.client.table("profiles").select("*").eq("id", user_id).single().execute()
        
        # Get recommendation stats
        stats = recommendation_service.get_user_stats(user_id)
        
        # Merge them
        result = {**stats}
        if profile_data.data:
            result.update({
                "display_name": profile_data.data.get("display_name"),
                "avatar_url": profile_data.data.get("avatar_url"),
                "cover_photo_url": profile_data.data.get("cover_photo_url"),
                "username": profile_data.data.get("username"),
                "pinned_movie_ids": profile_data.data.get("pinned_movie_ids", [])
            })
        return result
    except Exception as e:
        logger.error(f"Failed to fetch profile for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user profile",
        )


@router.patch("/me")
def update_my_profile(
    profile_update: UserProfileUpdate,
    user_id: str = Depends(get_current_user_id)
):
    """
    Update the current user's profile information.
    """
    try:
        # Filter out None values to only update provided fields
        update_dict = profile_update.dict(exclude_none=True)
        if not update_dict:
            return {"message": "No changes provided"}
            
        updated_profile = supabase_ds.update_profile(user_id, update_dict)
        return {
            "message": "Profile updated successfully",
            "profile": updated_profile
        }
    except Exception as e:
        logger.error(f"Failed to update profile for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update profile",
        )


@router.get("/me/liked-movies")
def get_my_liked_movies(user_id: str = Depends(get_current_user_id)):
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
def get_my_stats(user_id: str = Depends(get_current_user_id)):
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


@router.get("/me/mood-history")
def get_my_mood_history(user_id: str = Depends(get_current_user_id)):
    """
    Get the user's weekly mood history derived from liked movie genres.
    Returns up to 12 weeks of mood snapshots.
    """
    try:
        mood_data = recommendation_service.get_mood_history(user_id)
        return mood_data
    except Exception as e:
        logger.error(f"Failed to fetch mood history for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch mood history",
        )

@router.post("/me/update-taste-vector")
def update_taste_vector(user_id: str = Depends(get_current_user_id)):
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
