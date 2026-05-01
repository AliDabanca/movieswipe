
import asyncio
import os
import sys

# Add parent directory to path to allow imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.core.logger import logger

async def cleanup_movies_without_posters():
    ds = SupabaseDataSource()
    print("[SEARCH] Searching for movies without posters...")
    
    try:
        # Query movies where poster_path is null or empty
        response = ds.client.table("movies").select("id, name").or_("poster_path.is.null,poster_path.eq.").execute()
        movies_to_delete = response.data
        
        if not movies_to_delete:
            print("[SUCCESS] No movies found missing posters. Database is clean!")
            return

        print(f"[INFO] Found {len(movies_to_delete)} movies to remove.")
        for m in movies_to_delete:
            print(f" - [{m['id']}] {m['name']}")

        # Confirmation removed for automated cleanup
        print("\n[INFO] Proceeding with automated deletion...")

        for movie in movies_to_delete:
            movie_id = movie['id']
            movie_name = movie['name']
            
            print(f"[DELETE] Deleting '{movie_name}' (ID: {movie_id})...")
            
            try:
                # 1. Clean up swiped records (Foreign Key Integrity)
                ds.client.table("user_swipes").delete().eq("movie_id", movie_id).execute()
                
                # 2. Delete the movie
                ds.client.table("movies").delete().eq("id", movie_id).execute()
                
                print(f" [OK] Success")
            except Exception as e:
                print(f" [FAIL] Failed: {e}")

        print("\n[DONE] Cleanup complete!")

    except Exception as e:
        print(f"❌ Error during cleanup: {e}")
        logger.error(f"Cleanup failed: {e}", exc_info=True)

if __name__ == "__main__":
    asyncio.run(cleanup_movies_without_posters())
