"""Collection service — business logic for user-created movie collections."""

from typing import List, Dict, Any, Optional
from app.core.supabase import supabase
from app.core.errors import NotFoundError, ServerError, ValidationError
from app.core.logger import logger


class CollectionService:
    """Handles CRUD operations for user collections via Supabase."""

    def __init__(self):
        self.client = supabase

    # ── Collection CRUD ──────────────────────────────────────

    def create_collection(
        self, user_id: str, name: str, description: Optional[str] = None, is_public: bool = True
    ) -> Dict[str, Any]:
        """Create a new collection for the user."""
        try:
            data = {
                "user_id": user_id,
                "name": name.strip(),
                "description": description.strip() if description else None,
                "is_public": is_public,
            }
            response = self.client.table("user_collections").insert(data).execute()

            if not response.data:
                raise ServerError("Failed to create collection")

            collection = response.data[0]
            collection["movie_count"] = 0
            collection["cover_poster_path"] = None
            logger.info(f"✅ Collection created: '{name}' for user {user_id}")
            return collection

        except Exception as e:
            logger.error(f"❌ Failed to create collection for user {user_id}: {e}", exc_info=True)
            if isinstance(e, (ServerError, ValidationError)):
                raise
            raise ServerError("Failed to create collection")

    def get_user_collections(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all collections for a user with movie counts and cover art."""
        try:
            # Fetch collections
            response = (
                self.client.table("user_collections")
                .select("*")
                .eq("user_id", user_id)
                .order("created_at", desc=True)
                .execute()
            )
            collections = response.data or []

            if not collections:
                return []

            # Fetch movie counts and cover posters for each collection
            collection_ids = [c["id"] for c in collections]
            enriched = []
            for col in collections:
                col_id = col["id"]
                # Count movies
                count_resp = (
                    self.client.table("collection_movies")
                    .select("movie_id", count="exact")
                    .eq("collection_id", col_id)
                    .execute()
                )
                movie_count = count_resp.count if count_resp.count is not None else 0

                # Get first movie poster for cover
                cover_poster = None
                if movie_count > 0:
                    first_movie = (
                        self.client.table("collection_movies")
                        .select("movie_id")
                        .eq("collection_id", col_id)
                        .order("added_at", desc=True)
                        .limit(1)
                        .execute()
                    )
                    if first_movie.data:
                        mid = first_movie.data[0]["movie_id"]
                        movie_data = (
                            self.client.table("movies")
                            .select("poster_path")
                            .eq("id", mid)
                            .execute()
                        )
                        if movie_data.data:
                            cover_poster = movie_data.data[0].get("poster_path")

                col["movie_count"] = movie_count
                col["cover_poster_path"] = cover_poster
                enriched.append(col)

            return enriched

        except Exception as e:
            logger.error(f"❌ Failed to get collections for user {user_id}: {e}", exc_info=True)
            return []

    def get_collection_detail(self, collection_id: str, user_id: str) -> Dict[str, Any]:
        """Get a single collection with all its movies."""
        try:
            # Fetch collection
            col_resp = (
                self.client.table("user_collections")
                .select("*")
                .eq("id", collection_id)
                .single()
                .execute()
            )
            if not col_resp.data:
                raise NotFoundError("Collection not found")

            collection = col_resp.data

            # Verify ownership or public
            if collection["user_id"] != user_id and not collection.get("is_public", False):
                raise NotFoundError("Collection not found")

            # Fetch movies in collection
            movies_resp = (
                self.client.table("collection_movies")
                .select("movie_id, added_at")
                .eq("collection_id", collection_id)
                .order("added_at", desc=True)
                .execute()
            )

            movies = []
            if movies_resp.data:
                movie_ids = [m["movie_id"] for m in movies_resp.data]
                # Fetch movie details in chunks
                CHUNK_SIZE = 50
                all_movie_data = []
                for i in range(0, len(movie_ids), CHUNK_SIZE):
                    chunk = movie_ids[i : i + CHUNK_SIZE]
                    chunk_resp = (
                        self.client.table("movies")
                        .select("id, name, genre, poster_path, vote_average")
                        .in_("id", chunk)
                        .execute()
                    )
                    all_movie_data.extend(chunk_resp.data or [])

                # Build movie map for ordering
                movie_map = {m["id"]: m for m in all_movie_data}

                # Also fetch user ratings for these movies
                rating_resp = (
                    self.client.table("user_swipes")
                    .select("movie_id, rating")
                    .eq("user_id", user_id)
                    .eq("is_like", True)
                    .in_("movie_id", movie_ids)
                    .execute()
                )
                rating_map = {}
                if rating_resp.data:
                    rating_map = {r["movie_id"]: r.get("rating") for r in rating_resp.data}

                # Preserve insertion order
                for mid in movie_ids:
                    if mid in movie_map:
                        m = movie_map[mid]
                        m["user_rating"] = rating_map.get(mid)
                        movies.append(m)

            collection["movies"] = movies
            collection["movie_count"] = len(movies)
            collection["cover_poster_path"] = movies[0].get("poster_path") if movies else None
            return collection

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"❌ Failed to get collection detail {collection_id}: {e}", exc_info=True)
            raise ServerError("Failed to get collection details")

    def update_collection(
        self, collection_id: str, user_id: str, update_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Update a collection's metadata (name, description, is_public)."""
        try:
            # Verify ownership
            existing = (
                self.client.table("user_collections")
                .select("user_id")
                .eq("id", collection_id)
                .single()
                .execute()
            )
            if not existing.data or existing.data["user_id"] != user_id:
                raise NotFoundError("Collection not found")

            # Strip strings
            if "name" in update_data and update_data["name"]:
                update_data["name"] = update_data["name"].strip()
            if "description" in update_data and update_data["description"]:
                update_data["description"] = update_data["description"].strip()

            # Remove None values
            clean = {k: v for k, v in update_data.items() if v is not None}
            if not clean:
                return existing.data

            response = (
                self.client.table("user_collections")
                .update(clean)
                .eq("id", collection_id)
                .execute()
            )
            logger.info(f"✅ Collection {collection_id} updated")
            return response.data[0] if response.data else existing.data

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"❌ Failed to update collection {collection_id}: {e}", exc_info=True)
            raise ServerError("Failed to update collection")

    def delete_collection(self, collection_id: str, user_id: str) -> None:
        """Delete a collection (cascade deletes collection_movies)."""
        try:
            # Verify ownership
            existing = (
                self.client.table("user_collections")
                .select("user_id")
                .eq("id", collection_id)
                .single()
                .execute()
            )
            if not existing.data or existing.data["user_id"] != user_id:
                raise NotFoundError("Collection not found")

            self.client.table("user_collections").delete().eq("id", collection_id).execute()
            logger.info(f"🗑️ Collection {collection_id} deleted by user {user_id}")

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"❌ Failed to delete collection {collection_id}: {e}", exc_info=True)
            raise ServerError("Failed to delete collection")

    # ── Movie Management ──────────────────────────────────────

    def add_movie_to_collection(self, collection_id: str, movie_id: int, user_id: str) -> Dict[str, Any]:
        """Add a movie to a collection."""
        try:
            # Verify ownership
            existing = (
                self.client.table("user_collections")
                .select("user_id")
                .eq("id", collection_id)
                .single()
                .execute()
            )
            if not existing.data or existing.data["user_id"] != user_id:
                raise NotFoundError("Collection not found")

            # Upsert to avoid duplicate errors
            data = {"collection_id": collection_id, "movie_id": movie_id}
            response = (
                self.client.table("collection_movies")
                .upsert(data, on_conflict="collection_id,movie_id")
                .execute()
            )

            logger.info(f"✅ Movie {movie_id} added to collection {collection_id}")
            return response.data[0] if response.data else data

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(
                f"❌ Failed to add movie {movie_id} to collection {collection_id}: {e}",
                exc_info=True,
            )
            raise ServerError("Failed to add movie to collection")

    def remove_movie_from_collection(self, collection_id: str, movie_id: int, user_id: str) -> None:
        """Remove a movie from a collection."""
        try:
            # Verify ownership
            existing = (
                self.client.table("user_collections")
                .select("user_id")
                .eq("id", collection_id)
                .single()
                .execute()
            )
            if not existing.data or existing.data["user_id"] != user_id:
                raise NotFoundError("Collection not found")

            self.client.table("collection_movies").delete().eq(
                "collection_id", collection_id
            ).eq("movie_id", movie_id).execute()

            logger.info(f"✅ Movie {movie_id} removed from collection {collection_id}")

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(
                f"❌ Failed to remove movie {movie_id} from collection {collection_id}: {e}",
                exc_info=True,
            )
            raise ServerError("Failed to remove movie from collection")

    def get_movie_collections(self, movie_id: int, user_id: str) -> List[Dict[str, Any]]:
        """Get which of the user's collections contain a specific movie.
        
        Returns a list of collection summaries with an 'is_in_collection' flag.
        """
        try:
            # Get all user collections
            all_collections = self.get_user_collections(user_id)

            # Get collection IDs that contain this movie
            movie_cols_resp = (
                self.client.table("collection_movies")
                .select("collection_id")
                .eq("movie_id", movie_id)
                .execute()
            )
            movie_col_ids = {r["collection_id"] for r in (movie_cols_resp.data or [])}

            # Annotate each collection
            for col in all_collections:
                col["contains_movie"] = col["id"] in movie_col_ids

            return all_collections

        except Exception as e:
            logger.error(
                f"❌ Failed to get movie collections for movie {movie_id}, user {user_id}: {e}",
                exc_info=True,
            )
            return []
