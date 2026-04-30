"""Collection routes — CRUD for user-created movie collections."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.services.collection_service import CollectionService
from app.core.auth import get_current_user_id
from app.core.logger import logger
from app.data.models.collection_model import (
    CollectionCreateRequest,
    CollectionUpdateRequest,
    CollectionMovieRequest,
    CollectionResponse,
    CollectionDetailResponse,
)

router = APIRouter(prefix="/collections", tags=["collections"])
collection_service = CollectionService()


# ── Collection CRUD ──────────────────────────────────────────

@router.post("", response_model=CollectionResponse, status_code=status.HTTP_201_CREATED)
def create_collection(
    body: CollectionCreateRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Create a new collection."""
    result = collection_service.create_collection(
        user_id=user_id,
        name=body.name,
        description=body.description,
        is_public=body.is_public,
    )
    return CollectionResponse(**result)


@router.get("", response_model=List[CollectionResponse])
def get_my_collections(user_id: str = Depends(get_current_user_id)):
    """Get all collections for the authenticated user."""
    results = collection_service.get_user_collections(user_id)
    return [CollectionResponse(**c) for c in results]


@router.get("/{collection_id}", response_model=CollectionDetailResponse)
def get_collection_detail(
    collection_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Get a single collection with all its movies."""
    result = collection_service.get_collection_detail(collection_id, user_id)
    return CollectionDetailResponse(**result)


@router.patch("/{collection_id}", response_model=CollectionResponse)
def update_collection(
    collection_id: str,
    body: CollectionUpdateRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Update a collection's name, description, or visibility."""
    update_data = body.model_dump(exclude_unset=True)
    result = collection_service.update_collection(collection_id, user_id, update_data)
    return CollectionResponse(**result)


@router.delete("/{collection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_collection(
    collection_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Delete a collection (and all its movie associations)."""
    collection_service.delete_collection(collection_id, user_id)


# ── Movie Management ────────────────────────────────────────

@router.post("/{collection_id}/movies", status_code=status.HTTP_201_CREATED)
def add_movie_to_collection(
    collection_id: str,
    body: CollectionMovieRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Add a movie to a collection."""
    collection_service.add_movie_to_collection(collection_id, body.movie_id, user_id)
    return {"detail": "Movie added to collection"}


@router.delete("/{collection_id}/movies/{movie_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_movie_from_collection(
    collection_id: str,
    movie_id: int,
    user_id: str = Depends(get_current_user_id),
):
    """Remove a movie from a collection."""
    collection_service.remove_movie_from_collection(collection_id, movie_id, user_id)


# ── Movie-centric Queries ───────────────────────────────────

@router.get("/movie/{movie_id}", response_model=List[CollectionResponse])
def get_collections_for_movie(
    movie_id: int,
    user_id: str = Depends(get_current_user_id),
):
    """Get user's collections annotated with whether they contain this movie.
    
    Each collection in the response has a 'contains_movie' boolean field.
    """
    return collection_service.get_movie_collections(movie_id, user_id)
