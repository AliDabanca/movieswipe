"""Semantic embedding service using Sentence-Transformers.

Singleton service that loads `all-MiniLM-L6-v2` once and provides
methods for generating 384-dim embeddings from movie metadata.

Offline-first strategy:
  1. Try loading from local cache (instant, no network).
  2. If not cached, download from HuggingFace with extended timeouts.
  3. All subsequent loads use the local cache automatically.
"""

import os
import threading
from pathlib import Path
from typing import List, Dict, Any

from app.core.logger import logger

# ── HuggingFace connection tuning ────────────────────────────
# These must be set BEFORE any huggingface_hub import
os.environ.setdefault("HF_HUB_DOWNLOAD_TIMEOUT", "120")       # seconds per request
os.environ.setdefault("HUGGINGFACE_HUB_ETAG_TIMEOUT", "30")   # version-check timeout

# Resolve cache path relative to the backend root
_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent    # backend/
_CACHE_DIR = str(_BACKEND_DIR / "models" / "transformer_cache")


class EmbeddingService:
    """Singleton embedding service using all-MiniLM-L6-v2 (384-dim).

    The model is lazily loaded on first use and kept in memory for the
    lifetime of the process.  Thread-safe via a double-checked lock.

    Loading strategy (offline-first):
      1. ``local_files_only=True``  → instant from disk cache
      2. On failure, fall back to network download with retry
    """

    _instance = None
    _lock = threading.Lock()
    _loader_lock = threading.Lock()

    MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
    EMBEDDING_DIM = 384
    CACHE_DIR = _CACHE_DIR


    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._model = None
        return cls._instance

    # ── model lifecycle ──────────────────────────────────────

    def _load_model(self):
        """Load model with offline-first strategy and thread safety."""
        if self._model is None:
            with self._loader_lock:
                if self._model is None:
                    from sentence_transformers import SentenceTransformer

                    device = "cpu"
                    os.makedirs(self.CACHE_DIR, exist_ok=True)

                    # ── Phase 1: try local cache (no network) ──
                    try:
                        logger.info(f"Loading '{self.MODEL_NAME}' from local cache ({self.CACHE_DIR}) ...")
                        self._model = SentenceTransformer(
                            self.MODEL_NAME,
                            device=device,
                            cache_folder=self.CACHE_DIR,
                            local_files_only=True,
                        )
                        logger.info(f"✅ Model loaded from local cache (dim={self.EMBEDDING_DIM})")
                        return
                    except Exception:
                        logger.info("Model not found in local cache — downloading from HuggingFace ...")

                    # ── Phase 2: download with extended timeout ──
                    try:
                        self._model = SentenceTransformer(
                            self.MODEL_NAME,
                            device=device,
                            cache_folder=self.CACHE_DIR,
                        )
                        logger.info(
                            f"✅ Model '{self.MODEL_NAME}' downloaded and cached "
                            f"(dim={self.EMBEDDING_DIM}, cache={self.CACHE_DIR})"
                        )
                    except Exception as e:
                        logger.error(f"❌ Failed to load model '{self.MODEL_NAME}': {e}", exc_info=True)
                        raise RuntimeError(
                            f"Cannot load embedding model '{self.MODEL_NAME}'. "
                            f"Ensure internet access or pre-download the model to {self.CACHE_DIR}"
                        ) from e

    @property
    def model(self):
        if self._model is None:
            self._load_model()
        return self._model

    # ── text helpers ─────────────────────────────────────────

    @staticmethod
    def build_movie_text(movie: Dict[str, Any]) -> str:
        """Compose a single text string from movie metadata.

        Genre is repeated 3× so the model gives it extra weight,
        matching the strategy used by the legacy TF-IDF pipeline.
        """
        name = movie.get("name", "")
        genre = movie.get("genre", "General")
        overview = movie.get("overview", "") or ""
        return f"{name} {genre} {genre} {genre} {overview}"

    # ── embedding generation ─────────────────────────────────

    def generate_embedding(self, text: str) -> List[float]:
        """Generate a single 384-dim embedding vector."""
        vector = self.model.encode(text, normalize_embeddings=True)
        return vector.tolist()

    def generate_embeddings_batch(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for a batch of texts efficiently."""
        vectors = self.model.encode(texts, normalize_embeddings=True, batch_size=64, show_progress_bar=False)
        return vectors.tolist()

    # ── high-level helpers ───────────────────────────────────

    def embed_movies(self, movies: List[Dict[str, Any]]) -> List[List[float]]:
        """Build texts from movie dicts and generate embeddings in one call."""
        texts = [self.build_movie_text(m) for m in movies]
        return self.generate_embeddings_batch(texts)

    def backfill_embeddings(self, batch_size: int = 50) -> Dict[str, int]:
        """Find movies with NULL embeddings and generate them in batches.

        Uses cursor-based pagination (last_id) to avoid:
          - Supabase default row limit (1000) silently truncating results
          - Loading thousands of rows into memory at once

        Returns:
            Dict with 'total', 'success', and 'failed' counts.
        """
        from app.data.datasources.supabase_datasource import SupabaseDataSource

        ds = SupabaseDataSource()
        stats = {"total": 0, "success": 0, "failed": 0}
        last_id = 0  # Cursor: fetch rows with id > last_id

        logger.info(f"Backfill started (batch_size={batch_size})")

        while True:
            # Fetch next batch from DB using cursor
            try:
                response = ds.client.table("movies") \
                    .select("id, name, genre, overview") \
                    .is_("embedding", "null") \
                    .gt("id", last_id) \
                    .order("id") \
                    .limit(batch_size) \
                    .execute()
                batch = response.data if response.data else []
            except Exception as e:
                logger.error(f"Failed to query movies without embeddings (cursor={last_id}): {e}", exc_info=True)
                break

            if not batch:
                break  # No more movies to process

            stats["total"] += len(batch)
            last_id = batch[-1]["id"]  # Move cursor forward

            # Generate embeddings for this batch
            try:
                embeddings = self.embed_movies(batch)
                for movie, embedding in zip(batch, embeddings):
                    if ds.update_movie_embedding(movie["id"], embedding):
                        stats["success"] += 1
                    else:
                        stats["failed"] += 1
            except Exception as e:
                logger.error(f"Backfill batch failed (cursor={last_id}): {e}", exc_info=True)
                stats["failed"] += len(batch)

            logger.info(
                f"Backfill progress: {stats['total']} processed "
                f"({stats['success']} ok, {stats['failed']} fail)"
            )

        logger.info(f"Backfill complete: {stats['success']}/{stats['total']} embeddings generated")
        return stats

    # ── Taste Vector ─────────────────────────────────────────

    TASTE_VECTOR_THRESHOLD = 5  # Minimum likes before triggering update

    def update_taste_vector(self, user_id: str, background_tasks) -> None:
        """Conditionally trigger a taste vector update via BackgroundTasks.

        Checks like_count_since_update from the profiles table.
        If >= TASTE_VECTOR_THRESHOLD, schedules the RPC in the background
        to keep the swipe response fast.
        """
        from app.data.datasources.supabase_datasource import SupabaseDataSource

        ds = SupabaseDataSource()
        profile = ds.get_user_taste_profile(user_id)
        like_count = profile.get("like_count_since_update", 0)

        if like_count >= self.TASTE_VECTOR_THRESHOLD:
            logger.info(
                f"🧠 Taste vector update triggered for user {user_id} "
                f"(like_count={like_count}, threshold={self.TASTE_VECTOR_THRESHOLD})"
            )
            background_tasks.add_task(self._run_taste_vector_update, user_id)
        else:
            logger.debug(
                f"⏳ Like count {like_count}/{self.TASTE_VECTOR_THRESHOLD}, "
                f"skipping taste vector update for user {user_id}"
            )

    def _run_taste_vector_update(self, user_id: str) -> None:
        """Background task: call the Supabase RPC to recompute taste vector."""
        from app.data.datasources.supabase_datasource import SupabaseDataSource

        try:
            ds = SupabaseDataSource()
            result = ds.call_update_taste_vector_rpc(user_id)
            logger.info(f"🧠 Taste vector update complete for user {user_id}: {result}")
        except Exception as e:
            logger.error(
                f"❌ Background taste vector update failed for user {user_id}: {e}",
                exc_info=True,
            )

    def force_update_taste_vector(self, user_id: str) -> Dict[str, Any]:
        """Force-update taste vector immediately (for manual endpoint)."""
        from app.data.datasources.supabase_datasource import SupabaseDataSource

        ds = SupabaseDataSource()
        return ds.call_update_taste_vector_rpc(user_id)


# Global singleton instance
embedding_service = EmbeddingService()
