"""
Bulk load movies from TMDB into database.

Run this script once to populate the database with a large initial set of movies.
Usage:  cd backend && python -m scripts.bulk_load_movies

This fetches movies from 5 categories × 10 pages = ~1000 unique movies.
"""

import asyncio
import sys
import os
import time

# Add backend root to path so imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()


async def main():
    from app.services.movie_sync_service import MovieSyncService
    
    print("=" * 60)
    print("🎬 MovieSwipe Bulk Movie Loader")
    print("=" * 60)
    print()
    
    categories = ["popular", "now_playing", "upcoming", "top_rated", "trending"]
    pages_per_category = 10  # 10 pages × 20 movies/page = ~200 per category
    
    print(f"📋 Categories: {', '.join(categories)}")
    print(f"📄 Pages per category: {pages_per_category}")
    print(f"📊 Expected: ~{len(categories) * pages_per_category * 20} total (with duplicates)")
    print()
    
    start_time = time.time()

    sync_service = MovieSyncService()
    try:
        stats = await sync_service.sync_movies(
            categories=categories,
            pages_per_category=pages_per_category
        )
    finally:
        await sync_service.close()
    
    elapsed = time.time() - start_time
    
    print()
    print("=" * 60)
    print("📊 BULK LOAD RESULTS")
    print("=" * 60)
    print(f"  Total fetched:    {stats['total_fetched']}")
    print(f"  New movies added: {stats['new_movies']}")
    print(f"  Already existed:  {stats['existing_movies']}")
    print(f"  Errors:           {stats['errors']}")
    print(f"  Time taken:       {elapsed:.1f}s")
    print()
    
    for cat, cat_stats in stats['categories'].items():
        print(f"  📁 {cat}: {cat_stats['new']} new, {cat_stats['existing']} existing")
    
    print()
    print("✅ Done! Your database is now loaded with movies.")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
