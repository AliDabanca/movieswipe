"""Movie routes."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.domain.repositories.movie_repository import MovieRepository
from app.data.models.movie_model import MovieModel, MovieDetailModel
from app.presentation.api.dependencies import get_movie_repository
from app.presentation.schemas.requests import SwipeRequest, MessageResponse
from app.core.errors import NotFoundError
from app.core.auth import get_current_user_id
from app.data.services.tmdb_service import TMDBService
from app.data.datasources.supabase_datasource import SupabaseDataSource

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


@router.get("/{movie_id}/details", response_model=MovieDetailModel)
async def get_movie_details(movie_id: int):
    """
    Get enriched movie details with credits, TR/EN overview, and similar movies.
    
    Args:
        movie_id: The TMDB movie ID
    
    Returns:
        MovieDetailModel with director, cast, overview, similar movies
    """
    tmdb = TMDBService()
    try:
        # Fetch enriched details from TMDB
        enriched = await tmdb.get_movie_details_enriched(movie_id)
        
        # Try to get similar movies via vector search
        similar_movies = []
        try:
            ds = SupabaseDataSource()
            similar_raw = ds.get_similar_movies(movie_id, limit=3)
            similar_movies = [
                MovieModel(
                    id=m["id"],
                    name=m.get("name", "Unknown"),
                    genre=m.get("genre", "General"),
                    poster_path=m.get("poster_path"),
                    overview=m.get("overview"),
                    release_date=m.get("release_date"),
                    vote_average=m.get("vote_average", 0),
                )
                for m in similar_raw
            ]
        except Exception as e:
            print(f"⚠️  Similar movies unavailable: {e}")
        
        return MovieDetailModel(
            id=enriched["id"],
            name=enriched["name"],
            genre=enriched["genre"],
            genres=enriched.get("genres", []),
            poster_path=enriched.get("poster_path"),
            backdrop_path=enriched.get("backdrop_path"),
            overview=enriched.get("overview"),
            overview_en=enriched.get("overview_en"),
            release_date=enriched.get("release_date"),
            vote_average=enriched.get("vote_average", 0),
            vote_count=enriched.get("vote_count", 0),
            runtime=enriched.get("runtime"),
            tagline=enriched.get("tagline"),
            director=enriched.get("director"),
            cast=enriched.get("cast", []),
            cast_details=enriched.get("cast_details", []),
            similar_movies=similar_movies,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch movie details: {str(e)}",
        )
    finally:
        await tmdb.close()


@router.post("/{movie_id}/swipe", response_model=MessageResponse)
async def swipe_movie(
    movie_id: int,
    request: SwipeRequest,
    user_id: str = Depends(get_current_user_id),
    repository: MovieRepository = Depends(get_movie_repository),
):
    """
    Swipe a movie (like or pass). User ID is extracted from JWT token.

    Args:
        movie_id: The movie ID
        request: Swipe request with isLike boolean
    
    Returns:
        Success message
    """
    try:
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
