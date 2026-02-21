"""Live test: verify Supabase RPC functions work with real database."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from app.data.datasources.supabase_datasource import SupabaseDataSource

ds = SupabaseDataSource()

print("=" * 50)
print("LIVE TEST: Supabase RPC Functions")
print("=" * 50)

# Use a dummy user ID to test unseen movies (should return all movies)
test_user_id = "00000000-0000-0000-0000-000000000099"

print("\n1. Testing get_unseen_movies RPC...")
try:
    unseen = ds.get_unseen_movies(test_user_id, limit=10)
    print(f"   ✅ Returned {len(unseen)} unseen movies")
    if unseen:
        m = unseen[0]
        print(f"   Top movie: {m.get('name', 'N/A')} (vote: {m.get('vote_average', 'N/A')})")
except Exception as e:
    print(f"   ❌ Error: {e}")

print("\n2. Testing get_user_genre_stats RPC...")
try:
    stats = ds.get_user_genre_stats(test_user_id)
    print(f"   ✅ Returned {len(stats)} genre stats (expected 0 for dummy user)")
except Exception as e:
    print(f"   ❌ Error: {e}")

print("\n3. Testing full recommendation pipeline...")
from app.services.recommendation_service import RecommendationService
service = RecommendationService()
try:
    # Cold start test (dummy user has no swipes)
    recs = service.get_recommendations(test_user_id, limit=10)
    print(f"   ✅ Got {len(recs)} recommendations (cold start mode)")
    if recs:
        for i, m in enumerate(recs[:5]):
            print(f"   {i+1}. {m.name} ({m.genre}) - TMDB {m.vote_average}")
        genres = set(m.genre for m in recs)
        print(f"   Genre diversity: {len(genres)} unique genres in {len(recs)} movies")
except Exception as e:
    print(f"   ❌ Error: {e}")

print("\n" + "=" * 50)
print("LIVE TESTS COMPLETE")
print("=" * 50)
