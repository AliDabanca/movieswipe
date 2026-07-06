"""Direct Movie Share DM service implementation for handling direct movie exchanges and streaks."""

from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional
from uuid import UUID

from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.services.notification_service import NotificationService
from app.core.errors import ServerError, NotFoundError
from app.core.logger import logger


class DmService:
    """Service class for direct movie sharing, streaks, and ticket timelines."""

    def __init__(self):
        self.db = SupabaseDataSource()
        self.notifications = NotificationService()

    # ── Minimalist Direct Share ───────────────────────────────

    def share_movie(self, sender_id: str, receiver_id: str, movie_id: int) -> Dict[str, Any]:
        """Send a direct movie recommendation to a friend and calculate/update streak."""
        try:
            # 1. Ensure receiver is a friend
            friendship_check = self.db.client.table("friendships") \
                .select("share_streak, last_share_date") \
                .eq("user_id", sender_id) \
                .eq("friend_id", receiver_id) \
                .execute()
            
            if not friendship_check.data:
                raise ServerError("Yalnızca arkadaşlarınıza film önerebilirsiniz.")

            # 2. Insert movie share record
            share_data = {
                "sender_id": sender_id,
                "receiver_id": receiver_id,
                "movie_id": movie_id,
                "is_viewed": False
            }
            share_res = self.db.client.table("movie_shares").insert(share_data).execute()
            if not share_res.data:
                raise ServerError("Film paylaşımı kaydedilemedi.")
            
            new_share = share_res.data[0]

            # 3. Calculate and update Movie Share Streak
            friendship_data = friendship_check.data[0]
            current_streak = friendship_data.get("share_streak", 0)
            last_share_date_str = friendship_data.get("last_share_date")
            
            today = datetime.utcnow().date()
            new_streak = 1
            
            if last_share_date_str:
                last_share_date = datetime.strptime(last_share_date_str, "%Y-%m-%d").date()
                diff = (today - last_share_date).days
                if diff == 0:
                    new_streak = current_streak
                elif diff == 1:
                    new_streak = current_streak + 1
                else:
                    new_streak = 1
            else:
                new_streak = 1

            # Update both friendship records
            self.db.client.table("friendships") \
                .update({"share_streak": new_streak, "last_share_date": today.isoformat()}) \
                .eq("user_id", sender_id) \
                .eq("friend_id", receiver_id) \
                .execute()

            self.db.client.table("friendships") \
                .update({"share_streak": new_streak, "last_share_date": today.isoformat()}) \
                .eq("user_id", receiver_id) \
                .eq("friend_id", sender_id) \
                .execute()

            # 4. Trigger push notification/system notification to receiver
            try:
                # Find sender's username
                sender_res = self.db.client.table("profiles").select("display_name, username").eq("id", sender_id).single().execute()
                sender_name = sender_res.data.get("display_name") or sender_res.data.get("username") or "Bir arkadaşın"
                
                # Fetch movie title
                movie_details = self.db.get_movie_by_id(movie_id)
                movie_title = movie_details.get("name", "bir film")

                self.notifications.create_notification(
                    user_id=receiver_id,
                    actor_id=sender_id,
                    n_type="movie_shared",
                    related_id=str(new_share["id"])
                )
                logger.info(f"Notification triggered: {sender_name} recommended '{movie_title}' to {receiver_id}")
            except Exception as notif_err:
                logger.warning(f"Could not trigger notification for movie share: {notif_err}")

            # Attach movie data to response
            new_share["movie"] = self.db.get_movie_by_id(movie_id)
            return new_share

        except Exception as e:
            logger.error(f"Failed to share movie {movie_id} from {sender_id} to {receiver_id}: {e}", exc_info=True)
            raise ServerError("Film paylaşımı yapılamadı.")

    def update_reaction(self, share_id: str, user_id: str, reaction: Optional[str]) -> Dict[str, Any]:
        """Update or remove emoji reaction on a movie share."""
        try:
            # Fetch share to ensure permissions
            share = self.db.client.table("movie_shares").select("*").eq("id", share_id).execute()
            if not share.data:
                raise NotFoundError("Film bilet paylaşımı bulunamadı.")
            
            share_data = share.data[0]
            # Sender or receiver can update reaction (e.g. sender reacts, receiver reacts, or replaces)
            if share_data["sender_id"] != user_id and share_data["receiver_id"] != user_id:
                raise ServerError("Bu paylaşım üzerinde reaksiyon bırakma izniniz yok.")

            res = self.db.client.table("movie_shares") \
                .update({"reaction": reaction}) \
                .eq("id", share_id) \
                .execute()
            
            if not res.data:
                raise ServerError("Reaksiyon güncellenemedi.")
            
            updated_share = res.data[0]
            updated_share["movie"] = self.db.get_movie_by_id(updated_share["movie_id"])
            return updated_share

        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"Failed to update reaction for share {share_id}: {e}", exc_info=True)
            raise ServerError("Reaksiyon güncellenemedi.")

    # ── History & View ────────────────────────────────────────

    def get_shares_with_friend(self, user_id: str, friend_id: str) -> List[Dict[str, Any]]:
        """Fetch history of shares with a friend and mark received shares as viewed."""
        try:
            # Query shares in both directions
            shares_res = self.db.client.table("movie_shares") \
                .select("*") \
                .or_(f"and(sender_id.eq.{user_id},receiver_id.eq.{friend_id}),and(sender_id.eq.{friend_id},receiver_id.eq.{user_id})") \
                .order("created_at", desc=False) \
                .execute()
            
            shares = shares_res.data or []
            if not shares:
                return []

            # Extract distinct movie IDs to batch fetch details
            movie_ids = list(set(s["movie_id"] for s in shares))
            movies = self.db.get_movies_by_ids(movie_ids)
            movie_map = {m["id"]: m for m in movies}

            unviewed_ids = []
            for s in shares:
                s["movie"] = movie_map.get(s["movie_id"])
                # Collect unviewed shares received by current user
                if s["receiver_id"] == user_id and not s["is_viewed"]:
                    unviewed_ids.append(s["id"])
                    s["is_viewed"] = True  # optimistically mark for response

            # Mark all collected as viewed in background database call
            if unviewed_ids:
                try:
                    self.db.client.table("movie_shares") \
                        .update({"is_viewed": True}) \
                        .in_("id", unviewed_ids) \
                        .execute()
                except Exception as view_err:
                    logger.warning(f"Failed to mark shares as viewed: {view_err}")

            return shares

        except Exception as e:
            logger.error(f"Failed to fetch shares between {user_id} and {friend_id}: {e}", exc_info=True)
            raise ServerError("Paylaşım geçmişi yüklenemedi.")

    def mark_as_viewed(self, share_id: str, user_id: str) -> Dict[str, Any]:
        """Mark a single received share as viewed."""
        try:
            res = self.db.client.table("movie_shares") \
                .update({"is_viewed": True}) \
                .eq("id", share_id) \
                .eq("receiver_id", user_id) \
                .execute()
            if not res.data:
                raise NotFoundError("Bilet bulunamadı veya güncelleme izni yok.")
            
            viewed_share = res.data[0]
            viewed_share["movie"] = self.db.get_movie_by_id(viewed_share["movie_id"])
            return viewed_share
        except NotFoundError:
            raise
        except Exception as e:
            logger.error(f"Failed to mark share {share_id} as viewed: {e}", exc_info=True)
            raise ServerError("İşlem gerçekleştirilemedi.")

    # ── Direct Message List ───────────────────────────────────

    def get_dm_list(self, user_id: str) -> List[Dict[str, Any]]:
        """Fetch list of friends with their last shared movie, unread count, and streak."""
        try:
            # 1. Fetch all friendships with streaks
            friends_res = self.db.client.table("friendships") \
                .select("friend_id, share_streak, profiles!friendships_friend_id_fkey(id, username, display_name, avatar_url, current_streak, best_streak)") \
                .eq("user_id", user_id) \
                .execute()
            
            if not friends_res.data:
                return []

            friendships = friends_res.data
            friend_ids = [f["friend_id"] for f in friendships]

            # 2. Fetch last share for each friend
            # Supabase doesn't easily support a grouping 'last share' query in a single standard select without complex RPC,
            # so we fetch recent shares for the user and resolve them in Python memory, which is fast and lightweight.
            recent_shares_res = self.db.client.table("movie_shares") \
                .select("*") \
                .or_(f"sender_id.eq.{user_id},receiver_id.eq.{user_id}") \
                .order("created_at", desc=True) \
                .limit(200) \
                .execute()
            
            shares = recent_shares_res.data or []

            # 3. Fetch unread counts received by user
            unread_counts_res = self.db.client.table("movie_shares") \
                .select("sender_id", count="exact") \
                .eq("receiver_id", user_id) \
                .eq("is_viewed", False) \
                .execute()
            
            unread_data = unread_counts_res.data or []
            # Calculate unread count grouped by sender
            unread_map = {}
            for row in unread_data:
                sender = row.get("sender_id")
                unread_map[sender] = unread_map.get(sender, 0) + 1

            # Build map of last share for each friend
            last_share_map = {}
            for s in shares:
                other_party = s["receiver_id"] if s["sender_id"] == user_id else s["sender_id"]
                if other_party not in last_share_map:
                    last_share_map[other_party] = s

            # Fetch movie details for all last shares
            movie_ids = list(set(s["movie_id"] for s in last_share_map.values()))
            movies = self.db.get_movies_by_ids(movie_ids)
            movie_map = {m["id"]: m for m in movies}

            # Map movie details into shares
            for s in last_share_map.values():
                s["movie"] = movie_map.get(s["movie_id"])

            # 4. Construct response list
            dm_list = []
            for f in friendships:
                friend_profile = f.get("profiles")
                if not friend_profile:
                    continue
                
                fid = friend_profile["id"]
                last_share = last_share_map.get(fid)
                unread_cnt = unread_map.get(fid, 0)

                dm_list.append({
                    "friend": friend_profile,
                    "last_share": last_share,
                    "unread_count": unread_cnt,
                    "share_streak": f.get("share_streak", 0)
                })

            # Sort DM list: unread first, then by last share date descending, then by username
            def get_sort_key(item):
                unread = item["unread_count"] > 0
                created_at = "1970-01-01T00:00:00Z"
                if item["last_share"]:
                    created_at = item["last_share"]["created_at"]
                return (not unread, created_at)

            # Sort ascending on (not unread) ensures unread=True comes first
            dm_list.sort(key=get_sort_key, reverse=True)
            return dm_list

        except Exception as e:
            logger.error(f"Failed to load DM list for user {user_id}: {e}", exc_info=True)
            raise ServerError("Mesaj listesi yüklenemedi.")
