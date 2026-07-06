"""Supabase client initialization."""

from supabase import create_client, Client, ClientOptions
from app.core.config import settings
import postgrest._sync.request_builder as rb
import httpx
import time
from app.core.logger import logger

# Global client to prevent resource exhaustion and connection pooling issues
supabase: Client = create_client(
    settings.supabase_url,
    settings.supabase_key,
    options=ClientOptions(
        postgrest_client_timeout=30,
        storage_client_timeout=30,
    )
)

def _retrying_execute(original_execute):
    """Global decorator that wraps PostgREST execute calls with a retry mechanism."""
    def wrapper(self, *args, **kwargs):
        max_retries = 3
        base_delay = 0.5
        
        for attempt in range(1, max_retries + 1):
            try:
                return original_execute(self, *args, **kwargs)
            except Exception as e:
                # Gather error messages across the chained exception cause/context
                error_parts = [str(e)]
                for attr in ["__cause__", "__context__"]:
                    inner = getattr(e, attr, None)
                    if inner:
                        error_parts.append(str(inner))
                        deep_inner = getattr(inner, attr, None)
                        if deep_inner:
                            error_parts.append(str(deep_inner))
                
                error_str = " ".join(error_parts).lower()
                
                # Check if the error is a network or keep-alive disconnect
                is_retryable = any(kw in error_str for kw in [
                    "timeout", "timed out", "connection",
                    "522", "503", "502", "reset",
                    "network", "eof", "broken pipe",
                    "protocol", "disconnected", "terminated"
                ]) or isinstance(e, (httpx.HTTPError, httpx.RemoteProtocolError))
                
                if not is_retryable or attempt == max_retries:
                    logger.error(f"❌ PostgREST execute failed permanently on attempt {attempt}: {e}", exc_info=True)
                    raise
                
                delay = base_delay * (2 ** (attempt - 1))
                logger.warning(
                    f"⚡ PostgREST retry {attempt}/{max_retries} after {delay:.1f}s due to error: {e}"
                )
                time.sleep(delay)
    return wrapper

# Dynamically apply the monkeypatch globally to both synchronous request builders
rb.SyncQueryRequestBuilder.execute = _retrying_execute(rb.SyncQueryRequestBuilder.execute)
rb.SyncSingleRequestBuilder.execute = _retrying_execute(rb.SyncSingleRequestBuilder.execute)

logger.info("🔌 Applied global keep-alive auto-retry patch to Supabase database client")


