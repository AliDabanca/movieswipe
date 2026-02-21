"""Smart recommendation service with multi-factor scoring pipeline.

Architecture:
    1. Smart Filter  → Supabase RPC filters out already-swiped movies
    2. Scoring        → UserProfile + MovieScorer compute per-movie scores
    3. Diversity Mix  → DiversityMixer ensures echo chamber prevention
"""

import random
import logging
from typing import List, Dict, Tuple
from datetime import datetime
from collections import Counter

from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.domain.entities.movie import Movie
from app.data.models.movie_model import MovieModel

logger = logging.getLogger("movieswipe.recommendations")


# ──────────────────────────────────────────────────────────
# STAGE 1: User Profile — Genre preference extraction
# ──────────────────────────────────────────────────────────

class UserProfile:
    """Builds a user preference profile from swipe history.
    
    Scoring formula per genre:
        raw_score = (like_count × 1.0) + (pass_count × -0.3)
        
    Pass penalty is intentionally mild (-0.3) because passing a movie
    might mean "not now" rather than "I hate this genre".
    """
    
    LIKE_WEIGHT = 1.0
    PASS_PENALTY = -0.3
    NEUTRAL_SCORE = 0.5  # Score for genres the user hasn't seen yet
    MAX_SCORE = 0.90     # Soft cap — never 100%, always leave room for quality
    MIN_SCORE = 0.10     # Floor — never fully zero
    BAYESIAN_PRIOR = 2   # Virtual samples added per genre (smoothing)
    CONFIDENCE_THRESHOLD = 20  # Swipes needed for full confidence
    
    def __init__(self, genre_stats: List[Dict]):
        self.genre_stats = genre_stats
        self.genre_scores = self._compute_scores()
        self.total_swipes = sum(g.get("total_count", 0) for g in genre_stats)
        self.seen_genres = set(self.genre_scores.keys())
    
    @property
    def is_cold_start(self) -> bool:
        """User has fewer than 10 swipes — not enough data to personalize."""
        return self.total_swipes < 10
    
    def get_genre_score(self, genre: str) -> float:
        """Get normalized genre score (MIN_SCORE to MAX_SCORE).
        
        Returns NEUTRAL_SCORE for genres the user hasn't encountered.
        """
        return self.genre_scores.get(genre, self.NEUTRAL_SCORE)
    
    def get_unseen_genres(self, all_genres: set) -> set:
        """Genres the user has never interacted with — exploration candidates."""
        return all_genres - self.seen_genres
    
    def _compute_scores(self) -> Dict[str, float]:
        """Compute genre scores using Bayesian Smoothing + Confidence Scaling.
        
        Algorithm:
            1. Bayesian Prior: Add virtual samples (BAYESIAN_PRIOR likes + passes)
               to each genre to prevent extreme scores from small samples.
               → A genre with 1 like doesn't instantly become 100%
            
            2. Per-genre rate: (smoothed_likes - smoothed_pass_penalty) / smoothed_total
               → Produces a "like ratio" that accounts for uncertainty
            
            3. Confidence Scaling: Scale deviation from neutral by confidence
               confidence = min(1.0, sqrt(total_swipes / CONFIDENCE_THRESHOLD))
               → 5 swipes = 50% confidence, 20 swipes = 100% confidence
            
            4. Soft Clamping: Scores capped at [MIN_SCORE, MAX_SCORE]
               → Top genre never reaches 1.0, quality/freshness always matter
        """
        if not self.genre_stats:
            return {}
        
        # Step 1: Bayesian smoothed rates per genre
        raw_rates = {}
        for stat in self.genre_stats:
            genre = stat["genre"]
            likes = stat.get("like_count", 0)
            passes = stat.get("pass_count", 0)
            total = stat.get("total_count", 0)
            
            # Add Bayesian prior (virtual samples)
            smoothed_likes = likes + self.BAYESIAN_PRIOR
            smoothed_passes = passes + self.BAYESIAN_PRIOR
            smoothed_total = total + (self.BAYESIAN_PRIOR * 2)
            
            # Rate: how much the user likes this genre (0.0 to ~1.0)
            raw_rate = (smoothed_likes * self.LIKE_WEIGHT + smoothed_passes * self.PASS_PENALTY) / smoothed_total
            raw_rates[genre] = raw_rate
        
        if not raw_rates:
            return {}
        
        # Step 2: Normalize rates to 0-1 range
        min_rate = min(raw_rates.values())
        max_rate = max(raw_rates.values())
        rate_range = max_rate - min_rate
        
        if rate_range == 0:
            return {genre: self.NEUTRAL_SCORE for genre in raw_rates}
        
        normalized = {
            genre: (rate - min_rate) / rate_range
            for genre, rate in raw_rates.items()
        }
        
        # Step 3: Confidence scaling — pull toward neutral for low sample sizes
        total_swipes = sum(s.get("total_count", 0) for s in self.genre_stats)
        confidence = min(1.0, (total_swipes / self.CONFIDENCE_THRESHOLD) ** 0.5)
        
        # Step 4: Apply confidence and clamp
        return {
            genre: max(self.MIN_SCORE, min(self.MAX_SCORE,
                self.NEUTRAL_SCORE + (score - self.NEUTRAL_SCORE) * confidence
            ))
            for genre, score in normalized.items()
        }
    
    def __repr__(self):
        top = sorted(self.genre_scores.items(), key=lambda x: x[1], reverse=True)[:3]
        return f"UserProfile(swipes={self.total_swipes}, top={top})"


# ──────────────────────────────────────────────────────────
# STAGE 2: Movie Scorer — Multi-factor scoring
# ──────────────────────────────────────────────────────────

class MovieScorer:
    """Scores each movie using 3 weighted factors.
    
    final_score = (genre_score × 0.60) + (quality_score × 0.25) + (freshness × 0.15)
    """
    
    GENRE_WEIGHT = 0.60
    QUALITY_WEIGHT = 0.25
    FRESHNESS_WEIGHT = 0.15
    
    def __init__(self, profile: UserProfile):
        self.profile = profile
    
    def score_movie(self, movie: Movie) -> float:
        """Calculate composite score for a single movie."""
        genre_score = self.profile.get_genre_score(movie.genre)
        quality_score = self._quality_score(movie)
        freshness_score = self._freshness_score(movie)
        
        return (
            genre_score * self.GENRE_WEIGHT +
            quality_score * self.QUALITY_WEIGHT +
            freshness_score * self.FRESHNESS_WEIGHT
        )
    
    def score_movies(self, movies: List[Movie]) -> List[Tuple[Movie, float]]:
        """Score and sort a list of movies."""
        scored = [(m, self.score_movie(m)) for m in movies]
        scored.sort(key=lambda x: x[1], reverse=True)
        return scored
    
    @staticmethod
    def _quality_score(movie: Movie) -> float:
        """TMDB vote_average normalized to 0-1."""
        vote = movie.vote_average if movie.vote_average else 5.0
        return min(1.0, max(0.0, vote / 10.0))
    
    @staticmethod
    def _freshness_score(movie: Movie) -> float:
        """Newer movies get a slight boost. -10% per year from release."""
        if not movie.release_date:
            return 0.5  # Neutral for unknown dates
        
        try:
            release = datetime.strptime(movie.release_date, "%Y-%m-%d")
            years_old = (datetime.now() - release).days / 365.25
            return max(0.0, min(1.0, 1.0 - (years_old * 0.1)))
        except (ValueError, TypeError):
            return 0.5


# ──────────────────────────────────────────────────────────
# STAGE 3: Diversity Mixer — Echo chamber prevention
# ──────────────────────────────────────────────────────────

class DiversityMixer:
    """Mixes personalized picks with exploration to prevent echo chambers.
    
    Split: 80% personalized (top scores) + 20% exploration
    Exploration pool: unseen genres + high-quality popular movies
    Post-mix: no more than 3 consecutive movies of the same genre
    """
    
    PERSONALIZED_RATIO = 0.80
    EXPLORATION_RATIO = 0.20
    MAX_CONSECUTIVE_SAME_GENRE = 3
    
    def mix(
        self,
        scored_movies: List[Tuple[Movie, float]],
        all_unseen: List[Movie],
        profile: UserProfile,
        limit: int = 50,
    ) -> List[Movie]:
        """Build final recommendation list with diversity guarantees."""
        
        personalized_count = int(limit * self.PERSONALIZED_RATIO)
        exploration_count = limit - personalized_count
        
        # --- Personalized picks (top scored) ---
        personalized = [m for m, _ in scored_movies[:personalized_count]]
        
        # --- Exploration picks ---
        exploration = self._pick_exploration(
            scored_movies, all_unseen, profile, exploration_count
        )
        
        # --- Combine and enforce diversity ---
        combined = personalized + exploration
        random.shuffle(combined)  # Mix before diversity enforcement
        
        return self._enforce_genre_diversity(combined)
    
    def _pick_exploration(
        self,
        scored_movies: List[Tuple[Movie, float]],
        all_unseen: List[Movie],
        profile: UserProfile,
        count: int,
    ) -> List[Movie]:
        """Pick exploration movies: unseen genres + high-quality outliers."""
        exploration = []
        used_ids = {m.id for m, _ in scored_movies[:50]}  # Don't repeat personalized
        
        # All available genres in the unseen pool
        all_genres = {m.genre for m in all_unseen}
        unseen_genres = profile.get_unseen_genres(all_genres)
        
        # Half from unseen genres
        unseen_genre_count = count // 2
        unseen_genre_movies = [
            m for m in all_unseen
            if m.genre in unseen_genres and m.id not in used_ids
        ]
        random.shuffle(unseen_genre_movies)
        exploration.extend(unseen_genre_movies[:unseen_genre_count])
        used_ids.update(m.id for m in exploration)
        
        # Half from high-quality popular movies (vote_average > 7.0)
        quality_threshold = 7.0
        quality_count = count - len(exploration)
        quality_movies = [
            m for m in all_unseen
            if (m.vote_average or 0) >= quality_threshold and m.id not in used_ids
        ]
        random.shuffle(quality_movies)
        exploration.extend(quality_movies[:quality_count])
        
        # If still short, fill from remaining unseen
        if len(exploration) < count:
            remaining = [m for m in all_unseen if m.id not in used_ids and m not in exploration]
            random.shuffle(remaining)
            exploration.extend(remaining[:count - len(exploration)])
        
        return exploration
    
    def _enforce_genre_diversity(self, movies: List[Movie]) -> List[Movie]:
        """Ensure no more than MAX_CONSECUTIVE_SAME_GENRE in a row.
        
        If all movies are the same genre (edge case), returns them as-is
        since interleaving is impossible.
        """
        if len(movies) <= self.MAX_CONSECUTIVE_SAME_GENRE:
            return movies
        
        # If only one genre exists, can't enforce diversity
        genres_present = {m.genre for m in movies}
        if len(genres_present) <= 1:
            return movies
        
        result = []
        consecutive_count = 0
        last_genre = None
        deferred = []
        
        for movie in movies:
            if movie.genre == last_genre:
                consecutive_count += 1
                if consecutive_count >= self.MAX_CONSECUTIVE_SAME_GENRE:
                    deferred.append(movie)
                    continue
            else:
                # Insert a deferred movie to break the pattern
                if deferred:
                    result.append(deferred.pop(0))
                consecutive_count = 1
                last_genre = movie.genre
            
            result.append(movie)
        
        # Append any remaining deferred movies
        result.extend(deferred)
        return result


# ──────────────────────────────────────────────────────────
# Main Service — Orchestrates the pipeline
# ──────────────────────────────────────────────────────────

class RecommendationService:
    """Smart recommendation service with 3-stage scoring pipeline."""
    
    def __init__(self):
        self.supabase_ds = SupabaseDataSource()
        self.mixer = DiversityMixer()
    
    def get_recommendations(
        self,
        user_id: str,
        limit: int = 50,
    ) -> List[Movie]:
        """
        Get personalized movie recommendations.
        
        Pipeline:
            1. Fetch unseen movies (Supabase RPC / fallback)
            2. Build user profile from genre stats
            3. Score movies with multi-factor algorithm
            4. Mix with diversity guarantees
        
        Args:
            user_id: Authenticated user ID (from JWT)
            limit: Number of recommendations to return
            
        Returns:
            List of recommended Movie entities
        """
        # STAGE 1: Get unseen movies (Smart Filter)
        unseen_data = self.supabase_ds.get_unseen_movies(user_id, limit=300)
        
        if not unseen_data:
            logger.info(f"🎬 No unseen movies for user {user_id}")
            return []
        
        unseen_movies = [MovieModel(**m).to_entity() for m in unseen_data]
        
        # STAGE 2: Build user profile
        genre_stats = self.supabase_ds.get_user_genre_stats(user_id)
        profile = UserProfile(genre_stats)
        
        logger.info(f"👤 {profile}")
        
        # Cold Start: not enough data → trending + quality mix
        if profile.is_cold_start:
            return self._cold_start_recommendations(unseen_movies, limit)
        
        # STAGE 3: Score movies
        scorer = MovieScorer(profile)
        scored_movies = scorer.score_movies(unseen_movies)
        
        # STAGE 4: Diversity mix
        recommendations = self.mixer.mix(
            scored_movies=scored_movies,
            all_unseen=unseen_movies,
            profile=profile,
            limit=limit,
        )
        
        logger.info(
            f"📊 Returning {len(recommendations)} recommendations "
            f"({int(limit * 0.8)} personalized + {int(limit * 0.2)} exploration)"
        )
        
        return recommendations
    
    def _cold_start_recommendations(
        self, unseen_movies: List[Movie], limit: int
    ) -> List[Movie]:
        """Cold start strategy for new users.
        
        Shows high-quality, genre-diverse movies to help build a profile.
        Prioritizes: trending (high vote_average) + genre variety.
        """
        logger.info("🆕 Cold start — serving trending + diverse movies")
        
        # Sort by quality first
        quality_sorted = sorted(
            unseen_movies,
            key=lambda m: m.vote_average or 0,
            reverse=True,
        )
        
        # Ensure genre diversity: pick at most 3 from each genre
        result = []
        genre_count = Counter()
        
        for movie in quality_sorted:
            if len(result) >= limit:
                break
            if genre_count[movie.genre] < 3:
                result.append(movie)
                genre_count[movie.genre] += 1
        
        # Shuffle for variety (don't always show highest rated first)
        random.shuffle(result)
        
        return result
    
    def get_user_stats(self, user_id: str) -> Dict:
        """Get user statistics for profile/debugging."""
        genre_stats = self.supabase_ds.get_user_genre_stats(user_id)
        profile = UserProfile(genre_stats)
        
        swipes = self.supabase_ds.get_user_swipes(user_id)
        liked_ids = self.supabase_ds.get_user_liked_movie_ids(user_id)
        
        total_swipes = len(swipes)
        total_likes = len(liked_ids)
        total_passes = total_swipes - total_likes
        
        return {
            "user_id": user_id,
            "total_swipes": total_swipes,
            "total_likes": total_likes,
            "total_passes": total_passes,
            "like_ratio": total_likes / total_swipes if total_swipes > 0 else 0,
            "is_cold_start": profile.is_cold_start,
            "genre_preferences": profile.genre_scores,
            "top_genres": sorted(
                profile.genre_scores.items(), key=lambda x: x[1], reverse=True
            )[:5],
            "genre_stats_raw": genre_stats,
        }
    
    def get_liked_movies_by_genre(self, user_id: str) -> Dict[str, List[Dict]]:
        """Get user's liked movies grouped by genre."""
        liked_swipes = self.supabase_ds.client.table("user_swipes")\
            .select("movie_id")\
            .eq("user_id", user_id)\
            .eq("is_like", True)\
            .execute()
        
        if not liked_swipes.data:
            return {}
        
        liked_movie_ids = [swipe["movie_id"] for swipe in liked_swipes.data]
        
        try:
            movies_data = self.supabase_ds.get_movies_by_ids(liked_movie_ids)
        except Exception as e:
            logger.error(f"Error batch fetching movies: {e}")
            return {}
        
        # Group by genre
        movies_by_genre = {}
        for movie in movies_data:
            genre = movie.get("genre", "General")
            if genre not in movies_by_genre:
                movies_by_genre[genre] = []
            movies_by_genre[genre].append({
                "id": movie["id"],
                "name": movie["name"],
                "genre": genre,
                "poster_path": movie.get("poster_path"),
            })
        
        # Sort by count
        return dict(sorted(
            movies_by_genre.items(), key=lambda x: len(x[1]), reverse=True
        ))
