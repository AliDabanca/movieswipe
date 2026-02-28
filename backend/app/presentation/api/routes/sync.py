"""Movie sync API routes."""

from fastapi import APIRouter, BackgroundTasks, HTTPException, status, Query
from typing import List

from app.services.movie_sync_service import movie_sync_service
from app.core.logger import logger

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
        Sync statistics including embedding generation counts
    """
    try:
        stats = await movie_sync_service.sync_movies(categories, pages)
        return stats
    except Exception as e:
        logger.error(f"Movie synchronization failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Synchronization failed",
        )


@router.post("/backfill-embeddings")
async def backfill_embeddings(
    background_tasks: BackgroundTasks,
    batch_size: int = Query(default=50, ge=10, le=200, description="Batch size for processing"),
    run_in_background: bool = Query(default=True, description="Run as background task to avoid timeout"),
):
    """
    Generate embeddings for movies that don't have one yet.
    
    Scans the database for movies with NULL embedding columns
    and generates semantic vectors using all-MiniLM-L6-v2.
    
    By default runs as a BackgroundTask to avoid HTTP timeouts
    on large datasets. Set run_in_background=false to run synchronously.
    
    Args:
        batch_size: Number of movies to process per batch
        run_in_background: Whether to run as a background task
        
    Returns:
        Backfill statistics (total, success, failed) or acceptance message
    """
    try:
        from app.services.embedding_service import embedding_service

        if run_in_background:
            background_tasks.add_task(embedding_service.backfill_embeddings, batch_size=batch_size)
            return {
                "status": "accepted",
                "message": f"Backfill started in background (batch_size={batch_size}). Check logs for progress."
            }
        else:
            stats = embedding_service.backfill_embeddings(batch_size=batch_size)
            return stats
    except Exception as e:
        logger.error(f"Embedding backfill failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Embedding backfill failed",
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
        logger.error(f"Failed to get database status: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get database status",
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
        logger.error(f"Failed to get scheduler status: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get scheduler status",
        )
