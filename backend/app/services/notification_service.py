"""Notification service — manages user notifications for social events."""

from typing import List, Dict, Any
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.core.errors import ServerError
from app.core.logger import logger


class NotificationService:
    """Handles creating, fetching, and managing notifications."""

    def __init__(self):
        self.db = SupabaseDataSource()

    def create_notification(self, user_id: str, actor_id: str, n_type: str, related_id: str = None) -> Dict[str, Any]:
        """Create a new notification for a user."""
        try:
            data = {
                "user_id": user_id,
                "actor_id": actor_id,
                "type": n_type,
                "related_id": related_id,
                "is_read": False
            }
            res = self.db.client.table("notifications").insert(data).execute()
            return res.data[0] if res.data else {}
        except Exception as e:
            logger.error(f"Failed to create notification for {user_id}: {e}", exc_info=True)
            # We don't raise here to avoid breaking the main operation (e.g. friend acceptance)
            return {}

    def get_notifications(self, user_id: str) -> List[Dict[str, Any]]:
        """Fetch notifications for a user with actor profile info."""
        try:
            # Join with profiles to get actor info
            res = self.db.client.table("notifications") \
                .select("*, profiles:actor_id(id, username, display_name, avatar_url)") \
                .eq("user_id", user_id) \
                .order("created_at", desc=True) \
                .limit(20) \
                .execute()
            return res.data or []
        except Exception as e:
            logger.error(f"Failed to fetch notifications for {user_id}: {e}", exc_info=True)
            return []

    def mark_as_read(self, notification_id: str) -> bool:
        """Mark a notification as read."""
        try:
            self.db.client.table("notifications") \
                .update({"is_read": True}) \
                .eq("id", notification_id) \
                .execute()
            return True
        except Exception as e:
            logger.error(f"Failed to mark notification {notification_id} as read: {e}", exc_info=True)
            return False

    def get_unread_count(self, user_id: str) -> int:
        """Get the count of unread notifications."""
        try:
            res = self.db.client.table("notifications") \
                .select("id", count="exact") \
                .eq("user_id", user_id) \
                .eq("is_read", False) \
                .execute()
            return res.count or 0
        except Exception as e:
            logger.error(f"Failed to get unread count for {user_id}: {e}", exc_info=True)
            return 0
