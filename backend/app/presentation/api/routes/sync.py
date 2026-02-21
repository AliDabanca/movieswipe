"""Movie sync API routes."""

from fastapi import APIRouter, HTTPException, status, Query
from typing import List

from app.services.movie_sync_service import movie_sync_service

router = APIRouter(prefix="/movies/sync", tags=["sync"])


@router.post("/")
async def trigger_sync(
    categories: List[str] = Query(
        default=["popular", "now_playing", "upcoming", "top_rated", "trending"],
        description="Categories to sync"
    ),
    pages: int = Query(default=3, ge=1, le=20, description="Pages per category")
):
    """
    Manually trigger movie sync from TMDB.
    
    Args:
        categories: List of categories (popular, now_playing, upcoming, top_rated, trending)
        pages: Number of pages to fetch per category (1-20)
        
    Returns:
        Sync statistics
    """
    try:
        stats = await movie_sync_service.sync_movies(categories, pages)
        return stats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )


@router.get("/status")
async def get_sync_status():
    """
    Get current database movie count.
    
    Returns:
        Database statistics
    """
    try:
        from app.data.datasources.supabase_datasource import SupabaseDataSource
        
        supabase_ds = SupabaseDataSource()
        movies = supabase_ds.get_movies(limit=10000)
        
        return {
            "total_movies": len(movies),
            "message": f"Database contains {len(movies)} movies"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get status: {str(e)}",
        )


@router.get("/scheduler")
async def get_scheduler_status():
    """
    Get scheduler status: next sync time, last sync results.
    
    Returns:
        Scheduler info
    """
    try:
        from app.services.scheduler_service import scheduler_service
        return scheduler_service.get_status()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get scheduler status: {str(e)}",
        )
