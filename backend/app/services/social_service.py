"""Social service — friendship management and compatibility scoring."""

import random
from typing import List, Dict, Any, Optional

from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.core.errors import ServerError, NotFoundError
from app.core.logger import logger


class SocialService:
    """Handles friendships, friend requests, compatibility, and showcase."""

    def __init__(self):
        self.db = SupabaseDataSource()

    # ── Friend List ───────────────────────────────────────────

    def get_friends(self, user_id: str) -> List[Dict[str, Any]]:
        """Fetch all accepted friends for a user with profile info."""
        try:
            response = self.db.client.table("friendships") \
                .select("friend_id, created_at, profiles!friendships_friend_id_fkey(id, username, display_name, avatar_url)") \
                .eq("user_id", user_id) \
                .execute()

            friends = []
            for row in response.data or []:
                profile = row.get("profiles")
                if profile:
                    friends.append(profile)
            return friends
        except Exception as e:
            logger.error(f"Failed to fetch friends for {user_id}: {e}", exc_info=True)
            raise ServerError("Failed to fetch friends")

    def _safe_get_data(self, response: Any) -> List[Dict[str, Any]]:
        """Safely extract data from Supabase APIResponse to avoid property AttributeErrors."""
        if not response:
            return []
        try:
            data = getattr(response, "data", None)
            if data is None:
                return []
            if isinstance(data, list):
                return data
            return [data]
        except Exception:
            return []

    # ── Friend Requests ───────────────────────────────────────


    def send_friend_request(self, sender_id: str, receiver_username: str) -> Dict[str, Any]:
        """Send a friend request by username lookup."""
        try:
            # 1. Find user by username
            user_res = self.db.client.table("profiles") \
                .select("id") \
                .eq("username", receiver_username) \
                .execute()

            user_data = self._safe_get_data(user_res)
            if not user_data:
                raise NotFoundError(f"User '{receiver_username}' not found")

            receiver_id = user_data[0]["id"]


            if sender_id == receiver_id:
                raise ServerError("Kendi kendine arkadaşlık isteği gönderemezsin :)")


            # 2. Check if already friends
            existing = self.db.client.table("friendships") \
                .select("id") \
                .eq("user_id", sender_id) \
                .eq("friend_id", receiver_id) \
                .execute()

            existing_data = self._safe_get_data(existing)
            if existing_data:
                return {"message": "Already friends", "status": "already_friends"}


            # 3. Check for existing pending request (either direction)
            pending = self.db.client.table("friend_requests") \
                .select("id, sender_id, status") \
                .or_(f"and(sender_id.eq.{sender_id},receiver_id.eq.{receiver_id}),and(sender_id.eq.{receiver_id},receiver_id.eq.{sender_id})") \
                .eq("status", "pending") \
                .execute()

            pending_data = self._safe_get_data(pending)
            if pending_data:
                pending_req = pending_data[0]
                # If the other person already sent us a request, auto-accept it
                if pending_req["sender_id"] == receiver_id:
                    return self.accept_friend_request(sender_id, pending_req["id"])
                return {"message": "Request already pending", "status": "already_pending"}


            # 4. Create request
            res = self.db.client.table("friend_requests") \
                .insert({
                    "sender_id": sender_id,
                    "receiver_id": receiver_id,
                    "status": "pending",
                }) \
                .execute()

            return {"message": "Friend request sent", "status": "sent"}
        except (NotFoundError, ServerError):
            raise
        except Exception as e:
            logger.error(f"Failed to send friend request: {e}", exc_info=True)
            raise ServerError("Failed to send friend request")

    def get_incoming_requests(self, user_id: str) -> List[Dict[str, Any]]:
        """Get pending incoming friend requests with sender profile."""
        try:
            res = self.db.client.table("friend_requests") \
                .select("id, status, created_at, profiles!friend_requests_sender_id_fkey(id, username, display_name, avatar_url)") \
                .eq("receiver_id", user_id) \
                .eq("status", "pending") \
                .order("created_at", desc=True) \
                .execute()
            return res.data or []
        except Exception as e:
            logger.error(f"Failed to fetch incoming requests for {user_id}: {e}", exc_info=True)
            return []

    def get_outgoing_requests(self, user_id: str) -> List[Dict[str, Any]]:
        """Get pending outgoing friend requests."""
        try:
            res = self.db.client.table("friend_requests") \
                .select("id, status, created_at, profiles!friend_requests_receiver_id_fkey(id, username, display_name, avatar_url)") \
                .eq("sender_id", user_id) \
                .eq("status", "pending") \
                .order("created_at", desc=True) \
                .execute()
            return res.data or []
        except Exception as e:
            logger.error(f"Failed to fetch outgoing requests for {user_id}: {e}", exc_info=True)
            return []

    def accept_friend_request(self, receiver_id: str, request_id: str) -> Dict[str, Any]:
        """Accept a friend request → create mutual friendships."""
        try:
            # 1. Get the request
            req = self.db.client.table("friend_requests") \
                .select("*") \
                .eq("id", request_id) \
                .execute()

            req_data = self._safe_get_data(req)
            if not req_data:
                raise NotFoundError("Request not found")

            sender_id = req_data[0]["sender_id"]


            # 2. Update status to accepted
            self.db.client.table("friend_requests") \
                .update({"status": "accepted"}) \
                .eq("id", request_id) \
                .execute()

            # 3. Create mutual friendship records (A→B and B→A)
            try:
                self.db.client.table("friendships") \
                    .insert([
                        {"user_id": sender_id, "friend_id": receiver_id},
                        {"user_id": receiver_id, "friend_id": sender_id},
                    ]) \
                    .execute()
            except Exception as e:
                logger.warning(f"Failed to insert friendships (might already exist): {e}")


            logger.info(f"Friendship created: {sender_id} <-> {receiver_id}")
            return {"message": "Friend request accepted", "status": "accepted"}
        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"Failed to accept request {request_id}: {e}", exc_info=True)
            raise ServerError("Failed to accept friend request")

    def reject_friend_request(self, receiver_id: str, request_id: str) -> Dict[str, Any]:
        """Reject a friend request."""
        try:
            self.db.client.table("friend_requests") \
                .update({"status": "rejected"}) \
                .eq("id", request_id) \
                .eq("receiver_id", receiver_id) \
                .execute()
            return {"message": "Friend request rejected", "status": "rejected"}
        except Exception as e:
            logger.error(f"Failed to reject request {request_id}: {e}", exc_info=True)
            raise ServerError("Failed to reject friend request")

    # ── Compatibility ─────────────────────────────────────────

    def get_compatibility(self, user_a: str, user_b: str) -> Dict[str, Any]:
        """
        Calculate compatibility score between two users.

        Algorithm:
            film_score  = min(common_likes * 10, 60)      → max 60pts
            genre_score = overlapping_top_genres * 15      → max 45pts
            total       = min(film_score + genre_score, 100)
        """
        try:
            # 1. Get liked movie IDs for both
            likes_a = set(self.db.get_user_liked_movie_ids(user_a))
            likes_b = set(self.db.get_user_liked_movie_ids(user_b))

            common_ids = list(likes_a & likes_b)

            # 2. Get genre stats for both
            stats_a = self.db.get_user_genre_stats(user_a)
            stats_b = self.db.get_user_genre_stats(user_b)

            # Top 3 genres by like count
            top_a = {s["genre"] for s in sorted(stats_a, key=lambda x: x.get("like_count", 0), reverse=True)[:3]}
            top_b = {s["genre"] for s in sorted(stats_b, key=lambda x: x.get("like_count", 0), reverse=True)[:3]}
            genre_overlap = list(top_a & top_b)

            # 3. Score
            film_score = min(len(common_ids) * 10, 60)
            genre_score = len(genre_overlap) * 15
            total_score = min(film_score + genre_score, 100)

            # 4. Get movie details for common movies (max 10)
            common_movie_details = []
            if common_ids:
                raw_movies = self.db.get_movies_by_ids(common_ids[:10])
                # Also get the user_a ratings for display
                swipes_a = self.db.client.table("user_swipes") \
                    .select("movie_id, rating") \
                    .eq("user_id", user_a) \
                    .in_("movie_id", common_ids[:10]) \
                    .execute()
                rating_map = {s["movie_id"]: s.get("rating") for s in (swipes_a.data or [])}

                for m in raw_movies:
                    common_movie_details.append({
                        "id": m["id"],
                        "name": m.get("name", "Unknown"),
                        "poster_path": m.get("poster_path"),
                        "user_rating": rating_map.get(m["id"]),
                    })

            return {
                "compatibility_score": total_score,
                "common_movie_count": len(common_ids),
                "common_movies": common_movie_details,
                "top_overlap_genres": genre_overlap,
            }
        except Exception as e:
            logger.error(f"Compatibility calc failed ({user_a} vs {user_b}): {e}", exc_info=True)
            return {
                "compatibility_score": 0,
                "common_movie_count": 0,
                "common_movies": [],
                "top_overlap_genres": [],
            }

    # ── Friend Showcase ───────────────────────────────────────

    def get_friend_showcase(self, friend_id: str) -> List[Dict[str, Any]]:
        """
        Get 3 random high-rated movies from a friend.
        Picks from movies rated 4 or 5 stars by the friend.
        """
        try:
            # Fetch swipes with rating >= 4
            swipes = self.db.client.table("user_swipes") \
                .select("movie_id, rating") \
                .eq("user_id", friend_id) \
                .eq("is_like", True) \
                .gte("rating", 4) \
                .execute()

            if not swipes.data:
                # Fallback: just get any liked movies
                swipes = self.db.client.table("user_swipes") \
                    .select("movie_id, rating") \
                    .eq("user_id", friend_id) \
                    .eq("is_like", True) \
                    .limit(20) \
                    .execute()

            if not swipes.data:
                return []

            # Pick random 3
            picked = random.sample(swipes.data, min(3, len(swipes.data)))
            movie_ids = [s["movie_id"] for s in picked]
            rating_map = {s["movie_id"]: s.get("rating") for s in picked}

            movies = self.db.get_movies_by_ids(movie_ids)
            result = []
            for m in movies:
                result.append({
                    "id": m["id"],
                    "name": m.get("name", "Unknown"),
                    "poster_path": m.get("poster_path"),
                    "user_rating": rating_map.get(m["id"]),
                })
            return result
        except Exception as e:
            logger.error(f"Failed to get showcase for {friend_id}: {e}", exc_info=True)
            return []

    # ── Friend Top Genres ─────────────────────────────────────

    def get_friend_top_genres(self, friend_id: str) -> List[str]:
        """Get friend's top 3 genres by like count."""
        try:
            stats = self.db.get_user_genre_stats(friend_id)
            sorted_genres = sorted(stats, key=lambda x: x.get("like_count", 0), reverse=True)
            return [g["genre"] for g in sorted_genres[:3]]
        except Exception as e:
            logger.error(f"Failed to get top genres for {friend_id}: {e}", exc_info=True)
            return []

    # ── User Search ───────────────────────────────────────────

    def search_users(self, query: str, current_user_id: str) -> List[Dict[str, Any]]:
        """Search users by username (partial match) with friendship status."""
        try:
            # 1. Get matching users
            res = self.db.client.table("profiles") \
                .select("id, username, display_name, avatar_url") \
                .ilike("username", f"%{query}%") \
                .limit(10) \
                .execute()
            
            users = res.data or []
            if not users:
                return []
            
            # 2. Get current user's friends to check status
            friends_res = self.db.client.table("friendships") \
                .select("friend_id") \
                .eq("user_id", current_user_id) \
                .execute()
            
            friend_ids = {f["friend_id"] for f in (friends_res.data or [])}
            
            # 3. Map results
            results = []
            for u in users:
                results.append({
                    **u,
                    "is_friend": u["id"] in friend_ids,
                    "is_self": u["id"] == current_user_id
                })
            
            return results
        except Exception as e:
            logger.error(f"User search failed for '{query}': {e}", exc_info=True)
            return []

