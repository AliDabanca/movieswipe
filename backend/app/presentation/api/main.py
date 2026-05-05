"""Main FastAPI application."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.errors import DomainException, NotFoundError, ValidationError
from app.presentation.api.routes import movies, recommendations, users, sync, search, social, collections, notifications

# Configure logging - single handler to avoid duplicate output
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
# Prevent duplicate log lines from child loggers
logging.getLogger("movieswipe").propagate = False
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(asctime)s [%(name)s] %(levelname)s: %(message)s"))
movieswipe_logger = logging.getLogger("movieswipe")
if not movieswipe_logger.handlers:
    movieswipe_logger.addHandler(handler)
    movieswipe_logger.setLevel(logging.INFO)

logger = logging.getLogger("movieswipe")

# Suppress noisy third-party loggers
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events for the application."""
    # === STARTUP ===
    from app.services.scheduler_service import scheduler_service
    
    logger.info("🚀 MovieSwipe API starting up...")
    
    # Start the scheduler (periodic sync every 6 hours)
    scheduler_service.start()
    
    # Run immediate startup sync in background (non-blocking)
    import asyncio
    asyncio.create_task(scheduler_service.run_startup_sync())
    
    # Warm up the ML model in the background so the first request is instant
    from app.services.embedding_service import embedding_service
    asyncio.create_task(asyncio.to_thread(embedding_service._load_model))

    
    logger.info("✅ Startup complete!")
    
    yield  # App is running
    
    # === SHUTDOWN ===
    logger.info("🛑 Shutting down...")
    scheduler_service.stop()
    logger.info("👋 Goodbye!")


# Create FastAPI app
app = FastAPI(
    title="MovieSwipe API",
    description="Clean Architecture Backend for MovieSwipe Application",
    version="2.0.0",
    debug=settings.debug,
    lifespan=lifespan,
)

# CORS middleware - Allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for physical device testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Error handling middleware
@app.exception_handler(DomainException)
async def domain_exception_handler(request: Request, exc: DomainException):
    """Handle domain exceptions."""
    status_code = status.HTTP_400_BAD_REQUEST
    if isinstance(exc, NotFoundError):
        status_code = status.HTTP_404_NOT_FOUND
    elif isinstance(exc, ValidationError):
        status_code = status.HTTP_422_UNPROCESSABLE_ENTITY

    return JSONResponse(
        status_code=status_code,
        content={"detail": exc.message},
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions."""
    from app.core.errors import ServerError
    
    if isinstance(exc, ServerError):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message},
        )
        
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"},
    )



# Root endpoint
@app.get("/")
async def read_root():
    """Root endpoint."""
    return {
        "message": "Welcome to MovieSwipe API",
        "version": "2.0.0",
        "architecture": "Clean Architecture",
    }


# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


# Include routers
app.include_router(movies.router)
app.include_router(recommendations.router)
app.include_router(users.router)
app.include_router(sync.router)
app.include_router(search.router)
app.include_router(social.router)
app.include_router(collections.router)
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
