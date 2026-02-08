"""Movie search API routes."""

from fastapi import APIRouter, HTTPException, status, Query
from typing import List, Dict, Any

from app.data.services.tmdb_service import TMDBService

router = APIRouter(prefix="/movies/search", tags=["search"])

@router.get("/")
async def search_movies(
    query: str = Query(..., min_length=1, description="Search query"),
    page: int = Query(default=1, ge=1, le=10, description="Page number")
):
    """
    Search for movies via TMDB.
    
    Args:
        query: Movie title to search for
        page: Page number
        
    Returns:
        List of movies
    """
    tmdb_service = TMDBService()
    try:
        results = await tmdb_service.search_movies(query, page)
        
        # Format for frontend
        formatted_movies = []
        for movie in results:
            if not movie.get("title"): # Skip if no title
                continue
                
            formatted_movies.append({
                "id": movie["id"],
                "name": movie["title"],
                "poster_path": movie.get("poster_path"),
                "vote_average": movie.get("vote_average", 0.0),
                "release_date": movie.get("release_date", "")
            })
            
        return formatted_movies
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}",
        )
    finally:
        await tmdb_service.close()
