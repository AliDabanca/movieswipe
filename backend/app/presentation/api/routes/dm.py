"""Direct Movie Share DM API endpoints — sharing, reactions, and DM timelines."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from uuid import UUID

from app.services.dm_service import DmService
from app.core.auth import get_current_user_id
from app.core.logger import logger
from app.data.models.dm_model import (
    MovieShareRequest,
    MovieShareResponse,
    MovieDmListResponse,
    ReactionUpdateRequest,
)

router = APIRouter(prefix="/dm", tags=["dm"])
dm_service = DmService()


@router.post("/share", response_model=MovieShareResponse, status_code=status.HTTP_201_CREATED)
def share_movie(request: MovieShareRequest, user_id: str = Depends(get_current_user_id)):
    """Recommend a movie directly to an accepted friend and increment sharing streak."""
    # Ensure uuid conversion matches string representation
    return dm_service.share_movie(
        sender_id=user_id,
        receiver_id=str(request.receiver_id),
        movie_id=request.movie_id
    )


@router.get("/history/{friend_id}", response_model=List[MovieShareResponse])
def get_history(friend_id: UUID, user_id: str = Depends(get_current_user_id)):
    """Fetch all movie shares between you and a friend, marking received ones as viewed."""
    return dm_service.get_shares_with_friend(user_id, str(friend_id))


@router.get("/list", response_model=List[MovieDmListResponse])
def get_dm_list(user_id: str = Depends(get_current_user_id)):
    """Get all friends with unread counters, share streaks, and last message previews."""
    return dm_service.get_dm_list(user_id)


@router.patch("/reaction/{share_id}", response_model=MovieShareResponse)
def update_reaction(
    share_id: UUID,
    request: ReactionUpdateRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Set or update the emoji reaction on a direct movie share."""
    return dm_service.update_reaction(
        share_id=str(share_id),
        user_id=user_id,
        reaction=request.reaction
    )


@router.post("/view/{share_id}", response_model=MovieShareResponse)
def mark_as_viewed(share_id: UUID, user_id: str = Depends(get_current_user_id)):
    """Mark a direct movie share bilet as viewed."""
    return dm_service.mark_as_viewed(str(share_id), user_id)
