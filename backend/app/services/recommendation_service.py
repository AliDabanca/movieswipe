"""Smart recommendation service with multi-factor scoring pipeline.

Architecture:
    1. Smart Filter  → Supabase RPC filters out already-swiped movies
    2. Scoring        → UserProfile + MovieScorer compute per-movie scores
    3. Diversity Mix  → DiversityMixer ensures echo chamber prevention
"""

import random
import logging
from typing import List, Dict, Tuple, Any
from datetime import datetime, timedelta
from collections import Counter, defaultdict

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
        """Build final recommendation list with diversity guarantees.
        
        Also injects recommendation_reason metadata for explainability.
        """
        
        personalized_count = int(limit * self.PERSONALIZED_RATIO)
        exploration_count = limit - personalized_count
        
        # --- Personalized picks (top scored) ---
        personalized = [m for m, _ in scored_movies[:personalized_count]]
        # Tag personalized picks with genre-match reason
        genre_phrases = ["Tam Senlik", "Favorin", "Bunu Seversin", "Senin Tarz\u0131n"]
        for m in personalized:
            m.recommendation_reason = {
                "code": "genre_match",
                "text": f"{random.choice(genre_phrases)} ({m.genre})",
            }
        
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
        explore_phrases = ["Farkl\u0131 Bir Tat", "Buna \u015eans Ver", "Ke\u015ffet", "Rutini K\u0131r"]
        for m in unseen_genre_movies[:unseen_genre_count]:
            m.recommendation_reason = {
                "code": "exploration",
                "text": f"{random.choice(explore_phrases)} ({m.genre})",
            }
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
        critics_phrases = ["Herkesin Favorisi", "Ba\u015fyap\u0131t Alarm\u0131", "Kesinlikle \u0130zlemelisin", "S\u00fcrpriz Hit"]
        for m in quality_movies[:quality_count]:
            m.recommendation_reason = {
                "code": "critics_choice",
                "text": random.choice(critics_phrases),
            }
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

        # Tag semantic recommendations
        ai_phrases = ["Ruh Haline Uygun", "Sihirli Eşleşme", "Tam İstediğin Gibi", "Nokta Atışı"]
        for m in recommendations:
            if not m.recommendation_reason:
                m.recommendation_reason = {
                    "code": "vector_match",
                    "text": random.choice(ai_phrases),
                }

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
        
        # Tag cold start movies
        cold_phrases = ["G\u00fcn\u00fcn Pop\u00fcleri", "Trendlerde", "\u00c7ok Konu\u015fulanlar"]
        for m in result:
            m.recommendation_reason = {
                "code": "cold_start",
                "text": random.choice(cold_phrases),
            }
        
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
            .select("movie_id, swiped_at, rating, watch_status")\
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
        
        # Deduplicate: track seen movie IDs to prevent duplicates
        seen_ids = set()
        formatted_movies = []
        for m_id in liked_movie_ids:
            if m_id in seen_ids:
                continue
            seen_ids.add(m_id)
            
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
                "user_rating": swipe.get("rating"),
                "watch_status": swipe.get("watch_status"),
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

    # ── Mood History ──────────────────────────────────────────

    # Genre → Mood mapping
    GENRE_MOOD_MAP = {
        "Comedy":            {"mood": "Neşeli",      "emoji": "😄", "color": "#FFD93D"},
        "Romance":           {"mood": "Romantik",    "emoji": "💕", "color": "#FF6B8A"},
        "Action":            {"mood": "Heyecanlı",   "emoji": "🔥", "color": "#FF6B35"},
        "Adventure":         {"mood": "Heyecanlı",   "emoji": "🔥", "color": "#FF6B35"},
        "Horror":            {"mood": "Gerilimci",   "emoji": "😈", "color": "#8B5CF6"},
        "Thriller":          {"mood": "Gerilimci",   "emoji": "😈", "color": "#8B5CF6"},
        "Drama":             {"mood": "Düşünceli",   "emoji": "🤔", "color": "#4361EE"},
        "Science Fiction":   {"mood": "Hayalperest", "emoji": "🚀", "color": "#06D6A0"},
        "Sci-Fi":            {"mood": "Hayalperest", "emoji": "🚀", "color": "#06D6A0"},
        "Fantasy":           {"mood": "Hayalperest", "emoji": "🚀", "color": "#06D6A0"},
        "Animation":         {"mood": "Eğlenceli",  "emoji": "🎉", "color": "#FF9F1C"},
        "Family":            {"mood": "Eğlenceli",  "emoji": "🎉", "color": "#FF9F1C"},
        "Documentary":       {"mood": "Meraklı",    "emoji": "📚", "color": "#2EC4B6"},
        "History":           {"mood": "Meraklı",    "emoji": "📚", "color": "#2EC4B6"},
        "Crime":             {"mood": "Karanlık",   "emoji": "🌑", "color": "#6C757D"},
        "Mystery":           {"mood": "Karanlık",   "emoji": "🌑", "color": "#6C757D"},
        "War":               {"mood": "Karanlık",   "emoji": "🌑", "color": "#6C757D"},
        "Music":             {"mood": "Keşifçi",    "emoji": "🎭", "color": "#E8A87C"},
        "Western":           {"mood": "Keşifçi",    "emoji": "🎭", "color": "#E8A87C"},
    }

    DEFAULT_MOOD = {"mood": "Keşifçi", "emoji": "🎭", "color": "#E8A87C"}

    # Turkish month abbreviations
    _TR_MONTHS = {
        1: "Oca", 2: "Şub", 3: "Mar", 4: "Nis", 5: "May", 6: "Haz",
        7: "Tem", 8: "Ağu", 9: "Eyl", 10: "Eki", 11: "Kas", 12: "Ara",
    }

    def get_mood_history(self, user_id: str, weeks: int = 12) -> Dict[str, Any]:
        """Analyze the user's swipe history to produce weekly mood snapshots.

        Algorithm:
            1. Fetch all liked swipes with timestamps
            2. Join with movie genres
            3. Group by ISO week
            4. For each week, find the dominant genre → map to mood
            5. Return the last `weeks` entries

        Returns:
            {
              "mood_history": [...],
              "current_mood": str,
              "current_emoji": str,
            }
        """
        # 1. Fetch liked swipes with timestamps
        liked_swipes = self.supabase_ds.client.table("user_swipes") \
            .select("movie_id, swiped_at") \
            .eq("user_id", user_id) \
            .eq("is_like", True) \
            .order("swiped_at", desc=False) \
            .execute()

        if not liked_swipes.data:
            return {"mood_history": [], "current_mood": None, "current_emoji": None}

        # 2. Collect movie IDs and fetch genre info
        movie_ids = list({s["movie_id"] for s in liked_swipes.data})
        try:
            movies_data = self.supabase_ds.get_movies_by_ids(movie_ids)
        except Exception as e:
            logger.error(f"Mood history: failed to fetch movies: {e}")
            return {"mood_history": [], "current_mood": None, "current_emoji": None}

        movie_genre_map = {m["id"]: m.get("genre", "General") for m in movies_data}

        # 3. Group swipes by ISO week
        weekly_genres: Dict[str, Counter] = defaultdict(Counter)

        for swipe in liked_swipes.data:
            movie_id = swipe["movie_id"]
            genre = movie_genre_map.get(movie_id, "General")
            swiped_at_str = swipe.get("swiped_at")
            if not swiped_at_str:
                continue

            try:
                swiped_dt = datetime.fromisoformat(swiped_at_str.replace("Z", "+00:00"))
                iso_year, iso_week, _ = swiped_dt.isocalendar()
                week_key = f"{iso_year}-W{iso_week:02d}"
                weekly_genres[week_key][genre] += 1
            except (ValueError, AttributeError) as e:
                logger.debug(f"Mood history: skipping bad date {swiped_at_str}: {e}")
                continue

        if not weekly_genres:
            return {"mood_history": [], "current_mood": None, "current_emoji": None}

        # 4. Build mood entries per week (sorted chronologically)
        mood_history = []
        for week_key in sorted(weekly_genres.keys()):
            genre_counter = weekly_genres[week_key]
            dominant_genre = genre_counter.most_common(1)[0][0]
            total_likes = sum(genre_counter.values())

            mood_info = self.GENRE_MOOD_MAP.get(dominant_genre, self.DEFAULT_MOOD)

            # Build human-readable week label (e.g. "31 Mar - 6 Nis")
            week_label = self._week_key_to_label(week_key)

            mood_history.append({
                "week": week_key,
                "week_label": week_label,
                "dominant_mood": mood_info["mood"],
                "mood_emoji": mood_info["emoji"],
                "mood_color": mood_info["color"],
                "genre_breakdown": dict(genre_counter),
                "total_likes": total_likes,
            })

        # Keep only the last N weeks
        mood_history = mood_history[-weeks:]

        # Current mood = most recent week's mood
        current = mood_history[-1] if mood_history else None

        return {
            "mood_history": mood_history,
            "current_mood": current["dominant_mood"] if current else None,
            "current_emoji": current["mood_emoji"] if current else None,
        }

    def _week_key_to_label(self, week_key: str) -> str:
        """Convert '2026-W14' to '31 Mar - 6 Nis' style label."""
        try:
            # Parse ISO week to get Monday of that week
            year_str, week_str = week_key.split("-W")
            year = int(year_str)
            week_num = int(week_str)
            monday = datetime.strptime(f"{year}-W{week_num:02d}-1", "%G-W%V-%u")
            sunday = monday + timedelta(days=6)

            m_month = self._TR_MONTHS.get(monday.month, str(monday.month))
            s_month = self._TR_MONTHS.get(sunday.month, str(sunday.month))

            if monday.month == sunday.month:
                return f"{monday.day} - {sunday.day} {s_month}"
            else:
                return f"{monday.day} {m_month} - {sunday.day} {s_month}"
        except Exception:
            return week_key

    # ── Smart AI Discovery ────────────────────────────────────

    # Each answer option maps to descriptive English keywords that the
    # embedding model can understand semantically.
    MOOD_TAGS = {
        # Q1: Mood
        "happy":      "cheerful upbeat lighthearted comedy funny feel-good",
        "dark":       "dark tense suspenseful thriller horror creepy disturbing",
        "emotional":  "emotional touching heartfelt romantic drama tearjerker love",
        "adrenaline": "action explosive fast adventure battle superhero intense",
        "thoughtful": "philosophical thought-provoking cerebral sci-fi existential mind-bending",
        "chill":      "easy relaxing casual popcorn entertaining light fun",
        # Q2: Pace
        "fast":       "high-energy rapid action-packed exciting thrilling non-stop",
        "calm":       "atmospheric slow-burn meditative contemplative serene quiet",
        "twisty":     "plot-twist unpredictable mystery suspense puzzle mindbender",
        "visual":     "visually stunning cinematic beautiful artistic breathtaking epic",
        "grounded":   "realistic grounded true-to-life authentic gritty urban",
        # Q3: World
        "classic":    "classic timeless golden-age vintage old-school legendary masterpiece",
        "modern":     "recent contemporary modern fresh new current",
        "fantasy":    "fantasy sci-fi alien space otherworldly futuristic magical",
        "true_story": "based-on-true-story biography real-events historical documentary inspired",
        "cult":       "cult indie underground quirky unconventional experimental arthouse",
    }

    def get_mood_recommendations(
        self, user_id: str, answers: list[str], limit: int = 5
    ) -> list[Movie]:
        """Generate movie recommendations from mood survey answers.

        Algorithm:
            1. Map each answer tag to its descriptive keywords
            2. Concatenate into a single "mood sentence"
            3. Generate an embedding vector from that sentence
            4. Query pgvector for the closest movies (cosine similarity)
            5. Filter out already-swiped movies
            6. Return the top `limit` results
        """

        # 1. Build mood sentence from answer tags
        keywords = []
        for answer in answers:
            tag_text = self.MOOD_TAGS.get(answer, answer)
            keywords.append(tag_text)

        mood_sentence = " ".join(keywords)
        logger.info(f"Smart Discovery for user {user_id}: '{mood_sentence}'")

        # 2. Generate embedding vector for this mood
        from app.services.embedding_service import embedding_service
        mood_vector = embedding_service.generate_embedding(mood_sentence)

        if not mood_vector:
            logger.error("Failed to generate mood vector")
            return []

        # 3. Query pgvector for semantically similar movies
        swiped_ids = set(self.supabase_ds.get_user_swiped_movie_ids(user_id))

        # Use the existing match_movies RPC
        try:
            # Fetch a smaller pool (limit * 2) to ensure high relevance but keep slight variety
            response = self.supabase_ds.client.rpc("match_movies_for_user", {
                "query_embedding": mood_vector,
                "match_count": limit * 2,  
                "user_id_param": user_id,
            }).execute()
            candidates = response.data if response.data else []
        except Exception as e:
            logger.error(f"Smart Discovery vector search failed: {e}")
            return []

        # 4. Filter swiped + convert to Movie entities
        pre_filtered = []
        for m in candidates:
            if m["id"] in swiped_ids:
                continue
            if not m.get("poster_path"):
                continue

            movie = MovieModel(
                id=m["id"],
                name=m.get("name", "Unknown"),
                genre=m.get("genre", "General"),
                poster_path=m.get("poster_path"),
                overview=m.get("overview"),
                release_date=m.get("release_date"),
                vote_average=m.get("vote_average", 0),
            ).to_entity()
            pre_filtered.append(movie)

        # 5. Shuffle the HIGHLY RELEVANT candidate pool to add variety
        random.shuffle(pre_filtered)
        results = pre_filtered[:limit]

        logger.info(
            f"Smart Discovery returned {len(results)} shuffled movies "
            f"for user {user_id} (from {len(candidates)} candidates)"
        )
        return results
