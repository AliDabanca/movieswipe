from typing import List, Dict, Any
from fastapi import APIRouter, Depends
from app.core.auth import get_current_user_id
from app.services.notification_service import NotificationService

router = APIRouter()
notification_service = NotificationService()

@router.get("/")
def get_notifications(user_id: str = Depends(get_current_user_id)):
    """Get notifications for the current user."""
    return notification_service.get_notifications(user_id)

@router.get("/unread/count")
def get_unread_count(user_id: str = Depends(get_current_user_id)):
    """Get the count of unread notifications."""
    return {"count": notification_service.get_unread_count(user_id)}

@router.post("/{notification_id}/read")
def mark_as_read(notification_id: str, user_id: str = Depends(get_current_user_id)):
    """Mark a notification as read."""
    success = notification_service.mark_as_read(notification_id)
    return {"success": success}
