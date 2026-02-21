"""Supabase JWT authentication for FastAPI."""

from fastapi import Request, HTTPException, status
from supabase import create_client
from app.core.config import settings


async def get_current_user_id(request: Request) -> str:
    """
    Extract and validate user ID from Supabase JWT token.
    
    The token is sent in the Authorization header as 'Bearer <token>'.
    We use the Supabase client to verify the token and extract the user.
    
    Args:
        request: FastAPI request
        
    Returns:
        User ID string from the JWT token
        
    Raises:
        HTTPException: If token is missing or invalid
    """
    auth_header = request.headers.get("Authorization")
    
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )
    
    token = auth_header.split(" ")[1]
    
    try:
        # Use Supabase client to verify token and get user
        client = create_client(settings.supabase_url, settings.supabase_key)
        user_response = client.auth.get_user(token)
        
        if not user_response or not user_response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
            )
        
        return user_response.user.id
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication failed: {str(e)}",
        )
