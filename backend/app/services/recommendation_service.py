"""Smart recommendation service with multi-factor scoring pipeline.

Architecture:
    1. Smart Filter  → Supabase RPC filters out already-swiped movies
    2. Scoring        → UserProfile + MovieScorer compute per-movie scores
    3. Diversity Mix  → DiversityMixer ensures echo chamber prevention
"""

import random
import logging
from typing import List, Dict, Tuple, Any
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
    
    def score_movie(self, movie: Movie, now: datetime) -> float:
        """Calculate composite score for a single movie."""
        genre_score = self.profile.get_genre_score(movie.genre)
        quality_score = self._quality_score(movie)
        freshness_score = self._freshness_score(movie, now)
        
        return (
            genre_score * self.GENRE_WEIGHT +
            quality_score * self.QUALITY_WEIGHT +
            freshness_score * self.FRESHNESS_WEIGHT
        )
    
    def score_movies(self, movies: List[Movie]) -> List[Tuple[Movie, float]]:
        """Score and sort a list of movies."""
        now = datetime.now()
        scored = [(m, self.score_movie(m, now)) for m in movies]
        scored.sort(key=lambda x: x[1], reverse=True)
        return scored
    
    @staticmethod
    def _quality_score(movie: Movie) -> float:
        """TMDB vote_average normalized to 0-1."""
        vote = movie.vote_average if movie.vote_average else 5.0
        return min(1.0, max(0.0, vote / 10.0))
    
    @staticmethod
    def _freshness_score(movie: Movie, now: datetime) -> float:
        """Newer movies get a slight boost. -10% per year from release."""
        if not movie.release_date:
            return 0.5  # Neutral for unknown dates
        
        try:
            # Handle both YYYY-MM-DD and just YYYY if TMDB data is sparse
            date_str = movie.release_date
            if len(date_str) == 4:
                date_str += "-01-01"
            
            release = datetime.strptime(date_str, "%Y-%m-%d")
            years_old = (now - release).days / 365.25
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
    """Smart recommendation service with 3-stage scoring pipeline.
    
    Includes prefetch mechanism: when unseen movies drop below
    PREFETCH_THRESHOLD, triggers a background TMDB sync to replenish.
    """
    
    PREFETCH_THRESHOLD = 10  # Trigger sync when unseen count falls below this
    
    def __init__(self):
        self.supabase_ds = SupabaseDataSource()
        self.mixer = DiversityMixer()
        self._prefetch_in_progress = False
    
    def get_recommendations(
        self,
        user_id: str,
        limit: int = 50,
    ) -> List[Movie]:
        """
        Get personalized movie recommendations.
        
        Pipeline:
            1. Check for semantic fingerprint (taste_vector)
            2a. If taste_vector exists → semantic cosine similarity retrieval
            2b. If no taste_vector → classic genre-based pipeline
            3. Score movies with multi-factor algorithm
            4. Mix with diversity guarantees
            5. Prefetch: if pool is running low, trigger TMDB sync
        
        Args:
            user_id: Authenticated user ID (from JWT)
            limit: Number of recommendations to return
            
        Returns:
            List of recommended Movie entities
        """
        # ── Get swiped IDs for backend-level dedup guard ─────
        swiped_ids = set(self.supabase_ds.get_user_swiped_movie_ids(user_id))

        # ── Try semantic path first ──────────────────────────
        taste_profile = self.supabase_ds.get_user_taste_profile(user_id)
        taste_vector = taste_profile.get("taste_vector") if taste_profile else None

        if taste_vector:
            semantic_results = self._semantic_recommendations(
                user_id, taste_vector, limit, swiped_ids
            )
            if semantic_results:
                # Prefetch if the semantic pool is getting thin
                self._ensure_movie_pool(user_id, len(semantic_results), limit)
                return semantic_results
            logger.info(f"🔄 Semantic path returned no results for user {user_id}, falling back to genre-based")

        # ── Classic genre-based path ─────────────────────────
        # STAGE 1: Get unseen movies (Smart Filter)
        unseen_data = self.supabase_ds.get_unseen_movies(user_id, limit=300)
        
        if not unseen_data:
            logger.info(f"🎬 No unseen movies for user {user_id} — triggering prefetch")
            self._trigger_prefetch()
            return []
        
        unseen_movies = [MovieModel(**m).to_entity() for m in unseen_data]
        
        # Backend-level dedup guard: filter out any swiped movies that leaked through
        unseen_movies = [m for m in unseen_movies if m.id not in swiped_ids]
        
        if not unseen_movies:
            logger.info(f"🎬 All movies filtered by dedup guard for user {user_id} — triggering prefetch")
            self._trigger_prefetch()
            return []
        
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
        
        # Prefetch if pool is running low
        self._ensure_movie_pool(user_id, len(unseen_movies), limit)
        
        return recommendations

    def _semantic_recommendations(
        self,
        user_id: str,
        taste_vector: list,
        limit: int,
        swiped_ids: set = None,
    ) -> List[Movie]:
        """Fetch recommendations using semantic cosine similarity.
        
        Uses the user's taste_vector to query pgvector for the most
        similar unseen movies, then applies scoring and diversity mixing.
        """
        # Fetch semantically similar candidates (3× limit for scoring headroom)
        semantic_data = self.supabase_ds.get_semantic_recommendations(
            taste_vector, user_id, limit=limit * 3
        )

        if not semantic_data:
            return []

        # Log similarity scores at DEBUG level
        for item in semantic_data[:10]:  # Top 10 for readability
            logger.debug(
                f"DEBUG: Movie [{item.get('name', '?')}] similarity: "
                f"{item.get('similarity', 0):.3f}"
            )

        # Convert to Movie entities
        semantic_movies = [
            MovieModel(
                id=m["id"],
                name=m.get("name", "Unknown"),
                genre=m.get("genre", "General"),
                poster_path=m.get("poster_path"),
                overview=m.get("overview"),
                release_date=m.get("release_date"),
                vote_average=m.get("vote_average", 0),
            ).to_entity()
            for m in semantic_data
        ]

        # Backend-level dedup guard
        if swiped_ids:
            semantic_movies = [m for m in semantic_movies if m.id not in swiped_ids]

        if not semantic_movies:
            return []

        # Build profile for scoring + diversity
        genre_stats = self.supabase_ds.get_user_genre_stats(user_id)
        profile = UserProfile(genre_stats)

        # Score the semantically retrieved candidates
        scorer = MovieScorer(profile)
        scored_movies = scorer.score_movies(semantic_movies)

        # Apply diversity mixing
        recommendations = self.mixer.mix(
            scored_movies=scored_movies,
            all_unseen=semantic_movies,
            profile=profile,
            limit=limit,
        )

        logger.info(
            f"🧠 Returning {len(recommendations)} semantic recommendations "
            f"for user {user_id} (from {len(semantic_data)} candidates)"
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

    # ── Prefetch Mechanism ────────────────────────────────────

    def _ensure_movie_pool(self, user_id: str, current_pool_size: int, requested: int) -> None:
        """Trigger TMDB sync if the unseen movie pool is running low."""
        if current_pool_size < self.PREFETCH_THRESHOLD:
            logger.info(
                f"📡 Movie pool low for user {user_id}: "
                f"{current_pool_size} unseen (threshold={self.PREFETCH_THRESHOLD}) — triggering prefetch"
            )
            self._trigger_prefetch()

    def _trigger_prefetch(self) -> None:
        """Fire-and-forget TMDB sync in a background thread.
        
        Uses a simple flag to prevent multiple concurrent syncs.
        The flag is not thread-safe but that's acceptable — worst case
        we get two syncs which is harmless.
        """
        if self._prefetch_in_progress:
            logger.debug("⏳ Prefetch already in progress, skipping")
            return

        import threading

        def _run_sync():
            import asyncio
            try:
                self._prefetch_in_progress = True
                logger.info("🔄 Prefetch: starting TMDB sync for new movies...")

                from app.services.movie_sync_service import movie_sync_service

                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    stats = loop.run_until_complete(
                        movie_sync_service.sync_movies(
                            categories=["popular", "now_playing", "top_rated", "trending"],
                            pages_per_category=2,
                        )
                    )
                    logger.info(
                        f"✅ Prefetch complete: {stats.get('new_movies', 0)} new movies, "
                        f"{stats.get('embeddings_generated', 0)} embeddings"
                    )
                finally:
                    loop.close()
            except Exception as e:
                logger.error(f"❌ Prefetch sync failed: {e}", exc_info=True)
            finally:
                self._prefetch_in_progress = False

        thread = threading.Thread(target=_run_sync, daemon=True)
        thread.start()
    
    def get_user_stats(self, user_id: str) -> Dict:
        """Get user statistics for profile/debugging."""
        genre_stats = self.supabase_ds.get_user_genre_stats(user_id)
        profile = UserProfile(genre_stats)
        
        # Use the new accurate RPC for global counts
        counts = self.supabase_ds.get_user_stats_rpc(user_id)
        total_swipes = counts.get("total_swipes", 0)
        total_likes = counts.get("total_likes", 0)
        total_passes = counts.get("total_passes", 0)
        
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
    
    def get_liked_movies_by_genre(self, user_id: str) -> Dict[str, Any]:
        """Get user's liked movies grouped by genre and the recent 10 additions."""
        liked_swipes = self.supabase_ds.client.table("user_swipes")\
            .select("movie_id, swiped_at, rating")\
            .eq("user_id", user_id)\
            .eq("is_like", True)\
            .order("swiped_at", desc=True)\
            .execute()
        
        if not liked_swipes.data:
            return {"recently_added": [], "by_genre": {}}
        
        liked_movie_ids = [swipe["movie_id"] for swipe in liked_swipes.data]
        
        try:
            movies_data = self.supabase_ds.get_movies_by_ids(liked_movie_ids)
        except Exception as e:
            logger.error(f"Error batch fetching movies: {e}")
            return {"recently_added": [], "by_genre": {}}
        
        # Map by id to preserve swipe chronological order and include ratings
        swipe_map = {s["movie_id"]: s for s in liked_swipes.data}
        movie_map = {m["id"]: m for m in movies_data}
        
        formatted_movies = []
        for m_id in liked_movie_ids:
            if m_id not in movie_map:
                continue
                
            movie = movie_map[m_id]
            swipe = swipe_map.get(m_id, {})
            
            formatted_movies.append({
                "id": movie["id"],
                "name": movie["name"],
                "genre": movie.get("genre", "General"),
                "poster_path": movie.get("poster_path"),
                "vote_average": movie.get("vote_average", 0.0),
                "release_date": movie.get("release_date"),
                "user_rating": swipe.get("rating")
            })
            
        recently_added = formatted_movies[:10]
        
        # Group by genre
        movies_by_genre = {}
        for movie in formatted_movies:
            genre = movie["genre"]
            if genre not in movies_by_genre:
                movies_by_genre[genre] = []
            movies_by_genre[genre].append(movie)
        
        # Sort by count
        sorted_genres = dict(sorted(
            movies_by_genre.items(), key=lambda x: len(x[1]), reverse=True
        ))
        
        return {
            "recently_added": recently_added,
            "by_genre": sorted_genres
        }
