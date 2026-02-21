"""Quick test script for the recommendation scoring pipeline."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from app.services.recommendation_service import UserProfile, MovieScorer, DiversityMixer
from app.domain.entities.movie import Movie

print("=" * 50)
print("TEST 1: UserProfile scoring")
print("=" * 50)

stats = [
    {"genre": "Sci-Fi", "like_count": 8, "pass_count": 1, "total_count": 9},
    {"genre": "Action", "like_count": 5, "pass_count": 3, "total_count": 8},
    {"genre": "Drama", "like_count": 2, "pass_count": 6, "total_count": 8},
    {"genre": "Horror", "like_count": 0, "pass_count": 4, "total_count": 4},
]

profile = UserProfile(stats)
print(f"Profile: {profile}")
print(f"Cold start: {profile.is_cold_start}")
print(f"Sci-Fi score: {profile.get_genre_score('Sci-Fi'):.2f}")
print(f"Action score: {profile.get_genre_score('Action'):.2f}")
print(f"Drama score:  {profile.get_genre_score('Drama'):.2f}")
print(f"Horror score: {profile.get_genre_score('Horror'):.2f}")
print(f"Romance (unseen): {profile.get_genre_score('Romance'):.2f}")

assert profile.get_genre_score("Sci-Fi") > profile.get_genre_score("Action"), "Sci-Fi should beat Action"
assert profile.get_genre_score("Action") > profile.get_genre_score("Drama"), "Action should beat Drama"
assert profile.get_genre_score("Drama") > profile.get_genre_score("Horror"), "Drama should beat Horror"
assert profile.get_genre_score("Romance") == 0.5, "Unseen genres should be neutral (0.5)"
assert not profile.is_cold_start, "29 swipes = not cold start"
print("ALL ASSERTIONS PASSED")

print()
print("=" * 50)
print("TEST 2: MovieScorer multi-factor")
print("=" * 50)

scorer = MovieScorer(profile)

movies = [
    Movie(id=1, name="Interstellar", genre="Sci-Fi", vote_average=8.6, release_date="2014-11-07"),
    Movie(id=2, name="Bad Action Movie", genre="Action", vote_average=3.2, release_date="2010-01-01"),
    Movie(id=3, name="New Drama", genre="Drama", vote_average=7.5, release_date="2025-12-01"),
    Movie(id=4, name="Classic Horror", genre="Horror", vote_average=6.0, release_date="1990-01-01"),
    Movie(id=5, name="Unknown Romance", genre="Romance", vote_average=7.0, release_date="2024-06-01"),
]

scored = scorer.score_movies(movies)
for movie, score in scored:
    print(f"  {score:.3f} | {movie.name} ({movie.genre}) - TMDB {movie.vote_average}")

assert scored[0][0].name == "Interstellar", "Sci-Fi + high quality should be #1"
print("TOP MOVIE CORRECT")

print()
print("=" * 50)
print("TEST 3: Cold Start detection")
print("=" * 50)

cold_profile = UserProfile([
    {"genre": "Action", "like_count": 2, "pass_count": 1, "total_count": 3}
])
print(f"Cold start (3 swipes): {cold_profile.is_cold_start}")
assert cold_profile.is_cold_start, "3 swipes should be cold start"
print("COLD START CORRECT")

print()
print("=" * 50)
print("TEST 4: DiversityMixer")
print("=" * 50)

mixer = DiversityMixer()

# Single-genre edge case: all Action → should pass through gracefully
action_movies = [(Movie(id=i, name=f"Action{i}", genre="Action"), 0.9) for i in range(10)]
diverse = mixer._enforce_genre_diversity([m for m, _ in action_movies])
print(f"Single genre: {len(diverse)} movies returned (edge case, no constraint possible)")
assert len(diverse) == 10, "Should return all movies"

# Multi-genre test: 6 Action + 3 Comedy + 1 Drama
multi_movies = (
    [Movie(id=i, name=f"Action{i}", genre="Action") for i in range(6)] +
    [Movie(id=100+i, name=f"Comedy{i}", genre="Comedy") for i in range(3)] +
    [Movie(id=200, name="Drama1", genre="Drama")]
)
diverse_multi = mixer._enforce_genre_diversity(multi_movies)
consecutive = 0
max_consec = 0
last_genre = None
for m in diverse_multi:
    if m.genre == last_genre:
        consecutive += 1
    else:
        consecutive = 1
        last_genre = m.genre
    max_consec = max(max_consec, consecutive)

print(f"Multi-genre max consecutive: {max_consec} (limit: {mixer.MAX_CONSECUTIVE_SAME_GENRE})")
assert max_consec <= mixer.MAX_CONSECUTIVE_SAME_GENRE, "Should not exceed max consecutive"
print("DIVERSITY ENFORCED")

print()
print("=" * 50)
print("ALL TESTS PASSED!")
print("=" * 50)
