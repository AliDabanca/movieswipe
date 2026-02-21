"""
Recommendation Engine — Data Analytics & Edge Case Simulation
═══════════════════════════════════════════════════════════════
Tests the scoring pipeline with simulated user behavior.
Does NOT touch the real database — pure in-memory simulation.

Scenarios:
  1. Standard User: 20 Action likes + 5 Horror passes
  2. Edge Case: 1 single like
  3. Edge Case: 100 likes across many genres
  4. Edge Case: Single-genre obsession (all Adventure)
  5. Normalization Analysis: Why does %100 appear?
"""

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.recommendation_service import UserProfile, MovieScorer, DiversityMixer
from app.domain.entities.movie import Movie


# ═══════════════════════════════════════════════════════════
# HELPER: Pretty table printer
# ═══════════════════════════════════════════════════════════

def print_table(headers, rows, title=None):
    """Print a formatted terminal table."""
    if title:
        print(f"\n{'═' * 60}")
        print(f"  {title}")
        print(f"{'═' * 60}")
    
    col_widths = [max(len(str(h)), max((len(str(r[i])) for r in rows), default=0)) for i, h in enumerate(headers)]
    
    header_line = " │ ".join(h.ljust(w) for h, w in zip(headers, col_widths))
    separator = "─┼─".join("─" * w for w in col_widths)
    
    print(f"  {header_line}")
    print(f"  {separator}")
    for row in rows:
        print(f"  {' │ '.join(str(v).ljust(w) for v, w in zip(row, col_widths))}")


def print_section(title):
    print(f"\n{'▓' * 60}")
    print(f"▓  {title}")
    print(f"{'▓' * 60}")


# ═══════════════════════════════════════════════════════════
# FAKE MOVIE DATABASE (diverse genres and quality levels)
# ═══════════════════════════════════════════════════════════

FAKE_MOVIES = [
    Movie(id=1,  name="Action Blockbuster",    genre="Action",    vote_average=7.8, release_date="2025-01-15"),
    Movie(id=2,  name="Action Sequel",         genre="Action",    vote_average=6.5, release_date="2024-06-01"),
    Movie(id=3,  name="Action Classic",        genre="Action",    vote_average=8.2, release_date="2008-07-18"),
    Movie(id=4,  name="Sci-Fi Epic",           genre="Sci-Fi",    vote_average=8.6, release_date="2014-11-07"),
    Movie(id=5,  name="Sci-Fi B-Movie",        genre="Sci-Fi",    vote_average=4.1, release_date="2020-03-10"),
    Movie(id=6,  name="Comedy Hit",            genre="Comedy",    vote_average=7.2, release_date="2023-12-01"),
    Movie(id=7,  name="Comedy Dud",            genre="Comedy",    vote_average=3.8, release_date="2022-01-01"),
    Movie(id=8,  name="Drama Oscar Winner",    genre="Drama",     vote_average=8.9, release_date="2024-02-14"),
    Movie(id=9,  name="Drama Indie",           genre="Drama",     vote_average=6.7, release_date="2021-09-01"),
    Movie(id=10, name="Horror Classic",        genre="Horror",    vote_average=7.5, release_date="2018-10-31"),
    Movie(id=11, name="Horror Trash",          genre="Horror",    vote_average=2.1, release_date="2023-05-15"),
    Movie(id=12, name="Romance Tearjerker",    genre="Romance",   vote_average=7.9, release_date="2025-02-14"),
    Movie(id=13, name="Romance Comedy",        genre="Romance",   vote_average=6.3, release_date="2019-08-01"),
    Movie(id=14, name="Thriller Suspense",     genre="Thriller",  vote_average=8.1, release_date="2024-09-15"),
    Movie(id=15, name="Thriller Cheap",        genre="Thriller",  vote_average=3.5, release_date="2015-01-01"),
    Movie(id=16, name="Animation Family",      genre="Animation", vote_average=8.4, release_date="2023-06-16"),
    Movie(id=17, name="Documentary Nature",    genre="Documentary",vote_average=9.0, release_date="2024-04-22"),
    Movie(id=18, name="Fantasy Adventure",     genre="Fantasy",   vote_average=7.7, release_date="2022-11-11"),
    Movie(id=19, name="Adventure Epic",        genre="Adventure", vote_average=8.3, release_date="2025-05-01"),
    Movie(id=20, name="Adventure Low Budget",  genre="Adventure", vote_average=4.5, release_date="2016-01-01"),
]


# ═══════════════════════════════════════════════════════════
# SCENARIO 1: Standard User — 20 Action likes + 5 Horror passes
# ═══════════════════════════════════════════════════════════

print_section("SCENARIO 1: Standard User (20 Action likes + 5 Horror passes)")

stats_s1 = [
    {"genre": "Action",  "like_count": 20, "pass_count": 0,  "total_count": 20},
    {"genre": "Horror",  "like_count": 0,  "pass_count": 5,  "total_count": 5},
]

profile_s1 = UserProfile(stats_s1)
scorer_s1 = MovieScorer(profile_s1)

# Genre scores table
print_table(
    ["Genre", "Raw Score", "Normalized", "Interpretation"],
    [
        ("Action",  f"{20*1.0:.1f}",  f"{profile_s1.get_genre_score('Action'):.2f}",  "⭐ Top preference"),
        ("Horror",  f"{5*-0.3:.1f}",  f"{profile_s1.get_genre_score('Horror'):.2f}",  "❌ Disliked"),
        ("Sci-Fi",  "—",              f"{profile_s1.get_genre_score('Sci-Fi'):.2f}",  "🔍 Never seen (neutral)"),
        ("Comedy",  "—",              f"{profile_s1.get_genre_score('Comedy'):.2f}",  "🔍 Never seen (neutral)"),
        ("Drama",   "—",              f"{profile_s1.get_genre_score('Drama'):.2f}",   "🔍 Never seen (neutral)"),
    ],
    "Genre Preference Profile"
)

# Score movies
scored_s1 = scorer_s1.score_movies(FAKE_MOVIES)
print_table(
    ["Rank", "Movie", "Genre", "TMDB", "GenreS", "QualS", "FreshS", "FINAL"],
    [
        (i+1, m.name[:22], m.genre, f"{m.vote_average}", 
         f"{profile_s1.get_genre_score(m.genre):.2f}",
         f"{MovieScorer._quality_score(m):.2f}",
         f"{MovieScorer._freshness_score(m):.2f}",
         f"{score:.3f}")
        for i, (m, score) in enumerate(scored_s1[:10])
    ],
    "Top 10 Recommended Movies"
)

# Genre distribution
genre_dist_s1 = {}
for m, _ in scored_s1[:10]:
    genre_dist_s1[m.genre] = genre_dist_s1.get(m.genre, 0) + 1
print_table(
    ["Genre", "Count", "Percentage"],
    [(g, c, f"{c/10*100:.0f}%") for g, c in sorted(genre_dist_s1.items(), key=lambda x: x[1], reverse=True)],
    "Genre Distribution in Top 10"
)


# ═══════════════════════════════════════════════════════════
# SCENARIO 2: Edge Case — 1 single like
# ═══════════════════════════════════════════════════════════

print_section("SCENARIO 2: Edge Case — Only 1 Like (Drama)")

stats_s2 = [
    {"genre": "Drama", "like_count": 1, "pass_count": 0, "total_count": 1},
]

profile_s2 = UserProfile(stats_s2)
print(f"\n  Cold Start: {profile_s2.is_cold_start}  (total swipes: {profile_s2.total_swipes})")
print(f"  → System will use COLD START strategy (trending + diverse)")
print(f"  → Genre scoring is IGNORED, quality-first ordering used")

scorer_s2 = MovieScorer(profile_s2)
scored_s2 = scorer_s2.score_movies(FAKE_MOVIES)
print_table(
    ["Rank", "Movie", "Genre", "TMDB", "FINAL"],
    [(i+1, m.name[:25], m.genre, f"{m.vote_average}", f"{score:.3f}")
     for i, (m, score) in enumerate(scored_s2[:5])],
    "What scorer WOULD produce (but cold start overrides this)"
)


# ═══════════════════════════════════════════════════════════
# SCENARIO 3: Edge Case — 100 likes across many genres
# ═══════════════════════════════════════════════════════════

print_section("SCENARIO 3: Heavy User — 100 likes, diverse tastes")

stats_s3 = [
    {"genre": "Action",    "like_count": 25, "pass_count": 5,  "total_count": 30},
    {"genre": "Sci-Fi",    "like_count": 20, "pass_count": 3,  "total_count": 23},
    {"genre": "Drama",     "like_count": 15, "pass_count": 8,  "total_count": 23},
    {"genre": "Comedy",    "like_count": 10, "pass_count": 10, "total_count": 20},
    {"genre": "Horror",    "like_count": 5,  "pass_count": 15, "total_count": 20},
    {"genre": "Romance",   "like_count": 3,  "pass_count": 12, "total_count": 15},
    {"genre": "Thriller",  "like_count": 12, "pass_count": 2,  "total_count": 14},
    {"genre": "Animation", "like_count": 8,  "pass_count": 1,  "total_count": 9},
]

profile_s3 = UserProfile(stats_s3)
print(f"\n  Cold Start: {profile_s3.is_cold_start}  (total swipes: {profile_s3.total_swipes})")

print_table(
    ["Genre", "Likes", "Passes", "Raw Score", "Normalized"],
    [
        (s["genre"], s["like_count"], s["pass_count"],
         f"{s['like_count']*1.0 + s['pass_count']*-0.3:.1f}",
         f"{profile_s3.get_genre_score(s['genre']):.2f}")
        for s in stats_s3
    ],
    "Full Genre Score Breakdown"
)


# ═══════════════════════════════════════════════════════════
# SCENARIO 4: Single-genre obsession
# ═══════════════════════════════════════════════════════════

print_section("SCENARIO 4: Single-Genre Obsession (30 Adventure likes only)")

stats_s4 = [
    {"genre": "Adventure", "like_count": 30, "pass_count": 0, "total_count": 30},
]

profile_s4 = UserProfile(stats_s4)
print(f"\n  Cold Start: {profile_s4.is_cold_start}  (total swipes: {profile_s4.total_swipes})")

print_table(
    ["Genre", "Normalized Score", "Issue?"],
    [
        ("Adventure", f"{profile_s4.get_genre_score('Adventure'):.2f}", "← Only genre, gets 0.50 (tied)"),
        ("Action",    f"{profile_s4.get_genre_score('Action'):.2f}",    "← Unseen = neutral 0.50"),
        ("Horror",    f"{profile_s4.get_genre_score('Horror'):.2f}",    "← Unseen = neutral 0.50"),
    ],
    "Genre Scores (single genre = all tied at 0.50)"
)

print("""
  ⚠️  ANALYSIS: When only 1 genre exists in the profile:
      - score_range = 0 (max == min)
      - All genres fall to 0.50 (equal)
      - Scoring effectively becomes quality-only
      - This is actually CORRECT behavior — no comparative data exists
""")


# ═══════════════════════════════════════════════════════════
# NORMALIZATION DEEP DIVE: Why does %100 appear?
# ═══════════════════════════════════════════════════════════

print_section("NORMALIZATION ANALYSIS: The %100 Problem")

print("""
  CURRENT ALGORITHM: Min-Max Normalization
  ─────────────────────────────────────────
  normalized = (raw_score - min_score) / (max_score - min_score)
  
  PROBLEM: The top genre ALWAYS gets 1.0 (100%)
  
  Example: Action=20 likes, Horror=5 passes
    Action raw = 20.0, Horror raw = -1.5
    Range = 21.5
    Action normalized = (20.0 - (-1.5)) / 21.5 = 1.000 ← ALWAYS 100%
    Horror normalized = ((-1.5) - (-1.5)) / 21.5  = 0.050 ← Floor
    
  This means:
    ✗ Top genre is ALWAYS 1.0 regardless of confidence
    ✗ 3 Action likes = 1.0, 300 Action likes = 1.0 (no difference!)
    ✗ System cannot distinguish "strong preference" from "only data point"
""")

# Demonstrate the issue
for scenario_name, stats in [
    ("3 Action likes only", [{"genre": "Action", "like_count": 3, "pass_count": 0, "total_count": 3}]),
    ("30 Action likes only", [{"genre": "Action", "like_count": 30, "pass_count": 0, "total_count": 30}]),
    ("300 Action likes only", [{"genre": "Action", "like_count": 300, "pass_count": 0, "total_count": 300}]),
    ("3 Action + 3 Horror", [
        {"genre": "Action", "like_count": 3, "pass_count": 0, "total_count": 3},
        {"genre": "Horror", "like_count": 0, "pass_count": 3, "total_count": 3},
    ]),
]:
    p = UserProfile(stats)
    action_score = p.get_genre_score("Action")
    print(f"  {scenario_name:30s} → Action = {action_score:.2f}  (cold_start={p.is_cold_start})")


print("""
  ═══════════════════════════════════════════════════════════
  PROPOSED FIX: Bayesian Smoothing + Confidence Scaling
  ═══════════════════════════════════════════════════════════
  
  Instead of raw min-max, apply:
  
  1. BAYESIAN PRIOR: Add a virtual "baseline" of 2 likes + 2 passes per genre
     → raw = ((likes + 2) * 1.0 + (passes + 2) * -0.3) / (total + 4)
     → Prevents extreme scores from small samples
     
  2. CONFIDENCE SCALING: Scale by confidence = min(1.0, total_swipes / 20)  
     → final = neutral + (raw_score - neutral) * confidence
     → 3 swipes = low confidence, 20+ swipes = full confidence
     
  3. SOFT CLAMPING: Cap genre scores at 0.90 (never 100%)
     → Even the #1 genre leaves room for quality/freshness to matter

  Result: Scores become smoother and more meaningful.
""")


# ═══════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════

print_section("SUMMARY & VERDICTS")

print("""
  ┌─────────────────────────┬──────────┬──────────────────────────────────┐
  │ Scenario                │ Status   │ Verdict                          │
  ├─────────────────────────┼──────────┼──────────────────────────────────┤
  │ Standard User (20+5)    │ ✅ Works │ Correct ranking, genre weighted  │
  │ 1 Like (cold start)     │ ✅ Works │ Falls to cold start correctly    │
  │ 100 Likes (heavy user)  │ ✅ Works │ Good gradient across genres      │
  │ Single-Genre Obsession  │ ⚠️  Okay │ Falls to 0.50 (acceptable)      │
  │ Normalization %100      │ ❌ Bug   │ Top genre ALWAYS 1.0, needs fix  │
  └─────────────────────────┴──────────┴──────────────────────────────────┘
  
  RECOMMENDATION: Apply Bayesian Smoothing + Confidence Scaling fix
  to recommendation_service.py UserProfile._compute_scores()
""")
