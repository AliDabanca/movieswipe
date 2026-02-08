"""Application configuration using pydantic-settings."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        extra="ignore"
    )

    # Database

    # Database
    supabase_url: str = "your_supabase_url"
    supabase_key: str = "your_supabase_key"
    database_url: str = "postgresql://localhost/movieswipe"

    # Redis
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = True

    # CORS
    cors_origins: list = ["*"]
    
    # TMDB API
    tmdb_api_key: str = ""


# Global settings instance
settings = Settings()
