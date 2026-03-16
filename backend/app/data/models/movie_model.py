"""Movie Pydantic model for data layer."""

from pydantic import BaseModel, Field


class MovieModel(BaseModel):
    """Movie data model (Pydantic schema)."""

    id: int = Field(..., description="Movie ID")
    name: str = Field(..., min_length=1, max_length=200, description="Movie name")
    genre: str = Field(..., min_length=1, max_length=50, description="Movie genre")
    poster_path: str | None = Field(None, description="TMDB poster path")
    overview: str | None = Field(None, description="Movie overview/description")
    release_date: str | None = Field(None, description="Release date")
    vote_average: float | None = Field(None, description="TMDB vote average")
    user_rating: int | None = Field(None, ge=1, le=5, description="Personal rating (1-5 stars)")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "The Shawshank Redemption",
                "genre": "Drama",
                "poster_path": "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
            }
        }

    def to_entity(self):
        """Convert to domain entity."""
        from app.domain.entities.movie import Movie

        return Movie(
            id=self.id,
            name=self.name,
            genre=self.genre,
            poster_path=self.poster_path,
            overview=self.overview,
            release_date=self.release_date,
            vote_average=self.vote_average,
            user_rating=self.user_rating,
        )

    @classmethod
    def from_entity(cls, entity):
        """Create from domain entity."""
        return cls(
            id=entity.id,
            name=entity.name,
            genre=entity.genre,
            poster_path=entity.poster_path,
            overview=entity.overview,
            release_date=entity.release_date,
            vote_average=entity.vote_average,
            user_rating=entity.user_rating,
        )


class CastMember(BaseModel):
    """Cast member detail model."""
    name: str = Field(..., description="Actor name")
    character: str = Field("", description="Character played")
    profile_path: str | None = Field(None, description="TMDB profile image path")


class MovieDetailModel(MovieModel):
    """Extended movie model with full details for the detail page."""
    
    genres: list[str] = Field(default_factory=list, description="All genre names")
    backdrop_path: str | None = Field(None, description="TMDB backdrop image path")
    overview_en: str | None = Field(None, description="English overview")
    runtime: int | None = Field(None, description="Runtime in minutes")
    tagline: str | None = Field(None, description="Movie tagline")
    director: str | None = Field(None, description="Director name")
    cast: list[str] = Field(default_factory=list, description="Top 5 cast names")
    cast_details: list[CastMember] = Field(default_factory=list, description="Cast with character info")
    vote_count: int = Field(0, description="Number of votes")
    similar_movies: list[MovieModel] = Field(default_factory=list, description="Similar movies")

    class Config:
        from_attributes = True


class WatchProviderModel(BaseModel):
    """Single streaming/watch provider."""
    provider_id: int = Field(..., description="TMDB provider ID")
    provider_name: str = Field(..., description="Provider name (e.g. Netflix)")
    logo_path: str | None = Field(None, description="TMDB logo path")
    provider_type: str = Field(..., description="flatrate, rent, or buy")


class WatchProvidersResponse(BaseModel):
    """Response model for watch providers endpoint."""
    providers: list[WatchProviderModel] = Field(default_factory=list)
    tmdb_link: str = Field("", description="TMDB page link for this movie's providers")
