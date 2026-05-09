"""Social routes — friendship, compatibility, and user search."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.services.social_service import SocialService
from app.core.auth import get_current_user_id
from app.core.logger import logger
from app.data.models.social_model import (
    FriendResponse,
    FriendRequestResponse,
    CompatibilityResponse,
    FriendProfileResponse,
    ShowcaseMovieResponse,
)

router = APIRouter(prefix="/social", tags=["social"])
social_service = SocialService()


@router.get("/friends", response_model=List[FriendResponse])
def get_friends(user_id: str = Depends(get_current_user_id)):
    """Get accepted friend list with profiles."""
    return social_service.get_friends(user_id)


@router.get("/count/{user_id}")
def get_friend_count(user_id: str):
    """Get friend count for a specific user."""
    count = social_service.get_friend_count(user_id)
    return {"count": count}


@router.get("/requests/incoming")
def get_incoming_requests(user_id: str = Depends(get_current_user_id)):
    """Get pending incoming friend requests with sender info."""
    return social_service.get_incoming_requests(user_id)


@router.get("/requests/outgoing")
def get_outgoing_requests(user_id: str = Depends(get_current_user_id)):
    """Get pending outgoing friend requests."""
    return social_service.get_outgoing_requests(user_id)


@router.post("/request/{username}")
def send_request(username: str, user_id: str = Depends(get_current_user_id)):
    """Send a friend request by username lookup."""
    return social_service.send_friend_request(user_id, username)


@router.post("/accept/{request_id}")
def accept_request(request_id: str, user_id: str = Depends(get_current_user_id)):
    """Accept a pending friend request."""
    return social_service.accept_friend_request(user_id, request_id)


@router.post("/reject/{request_id}")
def reject_request(request_id: str, user_id: str = Depends(get_current_user_id)):
    """Reject a pending friend request."""
    return social_service.reject_friend_request(user_id, request_id)


@router.get("/compatibility/{friend_id}", response_model=CompatibilityResponse)
def get_compatibility(friend_id: str, user_id: str = Depends(get_current_user_id)):
    """Get compatibility score and common movies with a friend."""
    return social_service.get_compatibility(user_id, friend_id)


@router.get("/profile/{friend_id}", response_model=FriendProfileResponse)
def get_friend_profile(friend_id: str, user_id: str = Depends(get_current_user_id)):
    """Get full friend profile: showcase movies, top genres, compatibility."""
    # Get all data in one endpoint for the profile page
    friends = social_service.get_friends(user_id)
    friend_data = next((f for f in friends if f["id"] == friend_id), None)

    if not friend_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend not found or not in your friend list",
        )

    showcase = social_service.get_friend_showcase(friend_id)
    top_genres = social_service.get_friend_top_genres(friend_id)
    compatibility = social_service.get_compatibility(user_id, friend_id)

    return FriendProfileResponse(
        friend=FriendResponse(**friend_data),
        showcase_movies=[ShowcaseMovieResponse(**m) for m in showcase],
        top_genres=top_genres,
        compatibility=CompatibilityResponse(**compatibility),
    )


@router.get("/search/{query}", response_model=List[FriendResponse])
def search_users(query: str, user_id: str = Depends(get_current_user_id)):
    """Search for users by username."""
    results = social_service.search_users(query, user_id)
    return [FriendResponse(**u) for u in results]
