from fastapi import FastAPI
from typing import List
from app.models.movie import Movie

app = FastAPI(
    title="MovieSwipe API",
    description="Backend API for MovieSwipe application",
    version="1.0.0"
)


@app.get("/")
def read_root():
    """Root endpoint."""
    return {"message": "Welcome to MovieSwipe API"}


@app.get("/movies", response_model=List[Movie])
def get_movies():
    """
    Get a list of movies.
    
    Returns:
        List[Movie]: A list of movie objects
    """
    # Hardcoded movies for now
    movies = [
        Movie(id=1, name="The Shawshank Redemption", genre="Drama"),
        Movie(id=2, name="Inception", genre="Sci-Fi"),
        Movie(id=3, name="The Dark Knight", genre="Action")
    ]
    
    return movies
