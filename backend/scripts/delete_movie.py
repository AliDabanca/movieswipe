
import asyncio
import os
import sys

# Add parent directory to path to allow imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.core.config import settings

async def delete_movie(movie_id: int):
    ds = SupabaseDataSource()
    print(f"🗑️ Attempting to delete movie with ID: {movie_id}")
    
    try:
        # First check if it exists
        try:
            movie = ds.get_movie_by_id(movie_id)
            print(f"Found movie: {movie.get('name')} (ID: {movie.get('id')})")
        except:
            print(f"❌ Movie {movie_id} not found in DB.")
            return

        # Delete swipes referencing this movie first (referential integrity)
        print("Cleaning up user swipes...")
        ds.client.table("user_swipes").delete().eq("movie_id", movie_id).execute()
        
        # Delete the movie
        print("Deleting movie...")
        ds.client.table("movies").delete().eq("id", movie_id).execute()
        
        print(f"✅ Successfully deleted movie {movie_id}")
        
    except Exception as e:
        print(f"❌ Error deleting movie: {e}")

async def delete_movie_by_query(query: str):
    ds = SupabaseDataSource()
    print(f"🔍 Searching for movies matching: '{query}'...")
    
    try:
        # Check if query is ID
        if query.isdigit():
            movie_id = int(query)
            await delete_movie(movie_id)
            return

        # Search by name
        response = ds.client.table("movies").select("*").ilike("name", f"%{query}%").execute()
        movies = response.data
        
        if not movies:
            print(f"❌ No movies found matching '{query}'")
            return
            
        print(f"Found {len(movies)} movies:")
        for m in movies:
            print(f" - [{m['id']}] {m['name']} ({m.get('release_date', 'No Date')})")
            
        if len(movies) == 1:
            movie_id = movies[0]['id']
            confirm = input(f"❓ Delete '{movies[0]['name']}' (ID: {movie_id})? [y/N]: ")
            if confirm.lower() == 'y':
                await delete_movie(movie_id)
        else:
            print("⚠️  Multiple movies found. Please run again with specific ID.")

    except Exception as e:
        print(f"❌ Error searching/deleting: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/delete_movie.py <movie_id_or_name>")
    else:
        query = sys.argv[1]
        asyncio.run(delete_movie_by_query(query))
