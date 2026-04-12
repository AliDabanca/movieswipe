"""Scheduler service for automated movie sync.

Professional approach: APScheduler runs background jobs on a schedule,
similar to cron jobs in production environments.
"""

import asyncio
import logging
from datetime import datetime
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

logger = logging.getLogger("movieswipe.scheduler")


class SchedulerService:
    """Manages scheduled background tasks for movie sync."""
    
    SYNC_INTERVAL_HOURS = 6  # How often to auto-sync (every 6 hours)
    SYNC_PAGES = 3           # Pages per category for scheduled sync
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self.last_sync_time: datetime | None = None
        self.last_sync_stats: dict | None = None
        self._is_running = False
    
    def start(self):
        """Start the scheduler with periodic movie sync job."""
        if self._is_running:
            logger.warning("⚠️ Scheduler already running")
            return
        
        # Add the periodic sync job
        self.scheduler.add_job(
            self._run_sync,
            trigger=IntervalTrigger(hours=self.SYNC_INTERVAL_HOURS),
            id="movie_sync",
            name="Periodic Movie Sync",
            replace_existing=True,
        )
        
        self.scheduler.start()
        self._is_running = True
        logger.info(f"🚀 Scheduler started! Movies will sync every {self.SYNC_INTERVAL_HOURS} hours")
    
    def stop(self):
        """Stop the scheduler gracefully."""
        if self._is_running:
            self.scheduler.shutdown(wait=False)
            self._is_running = False
            logger.info("🛑 Scheduler stopped")
    
    async def run_startup_sync(self):
        """Run an immediate sync on startup, but only if database is empty."""
        try:
            from app.data.datasources.supabase_datasource import SupabaseDataSource
            ds = SupabaseDataSource()
            count_resp = ds.client.table("movies").select("id", count="exact").limit(1).execute()
            movie_count = count_resp.count or 0
            
            if movie_count > 0:
                logger.info(
                    f"Skipping startup sync (database already has {movie_count} movies). "
                    f"Background updates will run every {self.SYNC_INTERVAL_HOURS} hours."
                )
                return
            
            logger.info("Database is empty - running initial movie sync...")
            await self._run_sync()
            logger.info("Initial sync complete!")
        except Exception as e:
            logger.error(f"Startup sync check failed: {e}")
    
    async def _run_sync(self):
        """Execute the actual sync job."""
        from app.services.movie_sync_service import MovieSyncService
        
        sync_service = MovieSyncService()
        try:
            logger.info(f"📡 Starting scheduled sync at {datetime.now()}")
            
            stats = await sync_service.sync_movies(
                pages_per_category=self.SYNC_PAGES
            )
            
            self.last_sync_time = datetime.now()
            self.last_sync_stats = stats
            
            logger.info(
                f"✅ Sync complete: {stats['new_movies']} new, "
                f"{stats['existing_movies']} existing, "
                f"{stats['errors']} errors"
            )
        except Exception as e:
            logger.error(f"❌ Scheduled sync failed: {e}")
        finally:
            await sync_service.close()
    
    def get_status(self) -> dict:
        """Get scheduler status info."""
        next_run = None
        if self._is_running:
            job = self.scheduler.get_job("movie_sync")
            if job and job.next_run_time:
                next_run = job.next_run_time.isoformat()
        
        return {
            "scheduler_running": self._is_running,
            "sync_interval_hours": self.SYNC_INTERVAL_HOURS,
            "last_sync_time": self.last_sync_time.isoformat() if self.last_sync_time else None,
            "last_sync_stats": self.last_sync_stats,
            "next_sync_time": next_run,
        }


# Global instance
scheduler_service = SchedulerService()
