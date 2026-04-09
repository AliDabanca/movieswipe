"""Supabase JWT authentication for FastAPI."""

from fastapi import Request, HTTPException, status
from app.core.supabase import supabase
from app.core.logger import logger


def get_current_user_id(request: Request) -> str:
    """
    Extract and validate user ID from Supabase JWT token.
    
    The token is sent in the Authorization header as 'Bearer <token>'.
    We use the shared Supabase client to verify the token.
    
    Args:
        request: FastAPI request
        
    Returns:
        User ID string from the JWT token
        
    Raises:
        HTTPException: If token is missing or invalid
    """
    auth_header = request.headers.get("Authorization")
    
    if not auth_header or not auth_header.startswith("Bearer "):
        logger.warning("Authentication attempt with missing or invalid header")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )
    
    token = auth_header.split(" ")[1]
    
    try:
        # Reusing the global Supabase client
        user_response = supabase.auth.get_user(token)
        
        if not user_response or not user_response.user:
            logger.warning("Invalid or expired session token provided")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired session",
            )
        
        logger.info(f"User {user_response.user.id} authenticated successfully")
        
        return user_response.user.id
    except HTTPException:
        raise
    except Exception as e:
        # Log the actual error internally with stack trace, but return a generic message to the user
        logger.error(f"Deep Authentication Failure: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
        )
