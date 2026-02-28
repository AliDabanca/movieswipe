"""Supabase client initialization."""

from supabase import create_client, Client
from app.core.config import settings

# Global client to prevent resource exhaustion and connection pooling issues
supabase: Client = create_client(settings.supabase_url, settings.supabase_key)
