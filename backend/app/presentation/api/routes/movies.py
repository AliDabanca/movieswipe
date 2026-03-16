"""Movie routes."""

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from typing import List

from app.domain.repositories.movie_repository import MovieRepository
from app.data.models.movie_model import MovieModel, MovieDetailModel, WatchProviderModel, WatchProvidersResponse
from app.presentation.api.dependencies import get_movie_repository
from app.presentation.schemas.requests import SwipeRequest, MessageResponse
from app.core.errors import NotFoundError
from app.core.auth import get_current_user_id
from app.data.services.tmdb_service import TMDBService
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.services.embedding_service import embedding_service
from app.core.logger import logger

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
        logger.error(f"Failed to fetch all movies: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch movies",
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
        logger.error(f"Failed to fetch movie by ID {movie_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch movie",
        )


@router.get("/{movie_id}/details", response_model=MovieDetailModel)
async def get_movie_details(
    movie_id: int,
    user_id: str = Depends(get_current_user_id),
):
    """
    Get enriched movie details with credits, TR/EN overview, and similar movies.
    Also includes the user's personal rating if available.
    """
    tmdb = TMDBService()
    ds = SupabaseDataSource()
    
    # Try to get user's existing rating
    user_rating = None
    try:
        swipe = ds.client.table("user_swipes") \
            .select("rating") \
            .eq("user_id", user_id) \
            .eq("movie_id", movie_id) \
            .maybe_single() \
            .execute()
        if swipe.data:
            user_rating = swipe.data.get("rating")
    except Exception as e:
        logger.warning(f"Failed to fetch user rating for movie {movie_id}: {e}")

    try:
        enriched = None
        try:
            # Fetch enriched details from TMDB
            enriched = await tmdb.get_movie_details_enriched(movie_id)
            # Add the user's rating to the enriched data
            if enriched:
                enriched["user_rating"] = user_rating
        except Exception as tmdb_error:
            logger.warning(f"TMDB details unavailable for {movie_id}: {tmdb_error}")
            # Fallback: Try to get basic info from our DB
            ds = SupabaseDataSource()
            try:
                local_movie = ds.get_movie_by_id(movie_id)
                enriched = {
                    "id": local_movie["id"],
                    "name": local_movie.get("name", "Unknown"),
                    "genre": local_movie.get("genre", "General"),
                    "poster_path": local_movie.get("poster_path"),
                    "overview": local_movie.get("overview", "Detaylar şu an ulaşılamıyor."),
                    "release_date": local_movie.get("release_date"),
                    "vote_average": local_movie.get("vote_average", 0),
                    "user_rating": user_rating,
                    # Fill missing fields with defaults
                    "genres": [local_movie.get("genre", "General")],
                    "backdrop_path": None,
                    "overview_en": local_movie.get("overview", ""),
                    "vote_count": 0,
                    "runtime": None,
                    "tagline": None,
                    "director": None,
                    "cast": [],
                    "cast_details": [],
                }
            except Exception as db_error:
                logger.error(f"Critical DB fallback failure for movie {movie_id}: {db_error}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to fetch movie details",
                )

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
            logger.warning(f"Similar movies unavailable for movie {movie_id}: {e}")
        
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
        logger.error(f"Failed to fetch enriched movie details for movie {movie_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch movie details",
        )
    finally:
        await tmdb.close()


@router.get("/{movie_id}/watch-providers", response_model=WatchProvidersResponse)
async def get_watch_providers(movie_id: int, country: str = "TR"):
    """
    Get streaming/watch providers for a movie.
    
    Args:
        movie_id: The TMDB movie ID
        country: ISO 3166-1 country code (default: TR)
    
    Returns:
        WatchProvidersResponse with list of providers and TMDB link
    """
    tmdb = TMDBService()
    try:
        data = await tmdb.get_watch_providers(movie_id, country=country)
        providers = [
            WatchProviderModel(**p) for p in data.get("providers", [])
        ]
        return WatchProvidersResponse(
            providers=providers,
            tmdb_link=data.get("tmdb_link", ""),
        )
    except Exception as e:
        logger.error(f"Failed to fetch watch providers for movie {movie_id}: {str(e)}", exc_info=True)
        # Return empty rather than error — watch providers are non-critical
        return WatchProvidersResponse(providers=[], tmdb_link="")
    finally:
        await tmdb.close()

@router.post("/{movie_id}/swipe", response_model=MessageResponse)
async def swipe_movie(
    movie_id: int,
    request: SwipeRequest,
    background_tasks: BackgroundTasks,
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
        await repository.swipe(movie_id, request.isLike, user_id, request.rating)
        
        action = "LIKE" if request.isLike else "PASS"
        logger.info(f"Swipe saved: User {user_id} - Movie {movie_id} - {action}")
        
        # Conditionally trigger taste vector update on likes
        if request.isLike:
            embedding_service.update_taste_vector(user_id, background_tasks)
        
        return MessageResponse(message=f"Movie {action.lower()}d successfully")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Critical failure saving swipe for user {user_id}, movie {movie_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save swipe",
        )
