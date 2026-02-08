"""Movie routes."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.domain.repositories.movie_repository import MovieRepository
from app.data.models.movie_model import MovieModel
from app.presentation.api.dependencies import get_movie_repository
from app.presentation.schemas.requests import SwipeRequest, MessageResponse
from app.core.errors import NotFoundError

router = APIRouter(prefix="/movies", tags=["movies"])


@router.get("/", response_model=List[MovieModel])
async def get_movies(
    repository: MovieRepository = Depends(get_movie_repository),
):
    """
    Get all movies.

    Returns:
        List[MovieModel]: List of all movies
    """
    try:
        entities = await repository.get_all()
        return [MovieModel.from_entity(entity) for entity in entities]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch movies: {str(e)}",
        )


@router.get("/{movie_id}", response_model=MovieModel)
async def get_movie(
    movie_id: int,
    repository: MovieRepository = Depends(get_movie_repository),
):
    """
    Get a specific movie by ID.

    Args:
        movie_id: The movie ID

    Returns:
        MovieModel: The requested movie
    """
    try:
        entity = await repository.get_by_id(movie_id)
        if not entity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Movie with id {movie_id} not found",
            )
        return MovieModel.from_entity(entity)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch movie: {str(e)}",
        )


@router.post("/{movie_id}/swipe", response_model=MessageResponse)
async def swipe_movie(
    movie_id: int,
    request: SwipeRequest,
    repository: MovieRepository = Depends(get_movie_repository),
):
    """
    Swipe a movie (like or pass).

    Args:
        movie_id: The movie ID
        request: Swipe request with isLike boolean and userId
    
    Returns:
        Success message
    """
    try:
        # Get user_id from request body
        user_id = request.userId
        
        # Save swipe via repository
        await repository.swipe(movie_id, request.isLike, user_id)
        
        action = "LIKE" if request.isLike else "PASS"
        print(f"✅ Swipe saved to DB: User {user_id} - Movie {movie_id} - {action}")
        
        return MessageResponse(message=f"Movie {action.lower()}d successfully")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save swipe: {str(e)}",
        )
