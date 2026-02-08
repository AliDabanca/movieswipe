"""Recommendation service for personalized movie suggestions."""

import random
from typing import List, Dict
from collections import Counter
from app.data.datasources.supabase_datasource import SupabaseDataSource
from app.domain.entities.movie import Movie
from app.data.models.movie_model import MovieModel


class RecommendationService:
    """Service for generating personalized movie recommendations."""
    
    def __init__(self):
        self.supabase_ds = SupabaseDataSource()
    
    def get_recommendations(
        self, 
        user_id: str, 
        limit: int = 50,
        personalization_ratio: float = 0.7  # 70% personalized, 30% random discovery
    ) -> List[Movie]:
        """
        Get personalized movie recommendations for a user.
        
        Strategy:
        - If user has no history → Show popular/random movies
        - If user has 5+ likes → Mix personalized (70%) + discovery (30%)
        
        Args:
            user_id: User ID
            limit: Number of recommendations to return
            personalization_ratio: Ratio of personalized vs random movies (0.0 to 1.0)
            
        Returns:
            List of recommended Movie entities
        """
        # Get user's swipe history
        liked_movie_ids = self.supabase_ds.get_user_liked_movie_ids(user_id)
        swiped_movie_ids = self.supabase_ds.get_user_swiped_movie_ids(user_id)
        
        # Get all available movies
        all_movies_data = self.supabase_ds.get_movies(limit=1000)
        all_movies = [MovieModel(**movie_data).to_entity() for movie_data in all_movies_data]
        
        # Filter out already swiped movies
        unseen_movies = [m for m in all_movies if m.id not in swiped_movie_ids]
        
        # Cold start: No likes yet
        if len(liked_movie_ids) < 5:
            print(f"🆕 Cold start for user {user_id} ({len(liked_movie_ids)} likes)")
            # Return random/popular movies
            random.shuffle(unseen_movies)
            return unseen_movies[:limit]
        
        # Get liked movies to analyze preferences
        liked_movies_data = [m for m in all_movies_data if m["id"] in liked_movie_ids]
        liked_movies = [MovieModel(**movie_data).to_entity() for movie_data in liked_movies_data]
        
        # Calculate genre preferences
        genre_preferences = self._calculate_genre_preferences(liked_movies)
        
        print(f"👤 User {user_id} preferences: {genre_preferences}")
        
        # Score unseen movies based on genre match
        scored_movies = []
        for movie in unseen_movies:
            score = genre_preferences.get(movie.genre, 0.1)  # Default 0.1 for unknown genres
            scored_movies.append((movie, score))
        
        # Sort by score (descending)
        scored_movies.sort(key=lambda x: x[1], reverse=True)
        
        # Calculate split
        personalized_count = int(limit * personalization_ratio)
        discovery_count = limit - personalized_count
        
        # Get top personalized movies
        personalized_movies = [m for m, _ in scored_movies[:personalized_count]]
        
        # Get random discovery movies (from lower-scored ones to add variety)
        remaining_movies = [m for m, _ in scored_movies[personalized_count:]]
        random.shuffle(remaining_movies)
        discovery_movies = remaining_movies[:discovery_count]
        
        # Combine and shuffle to mix them
        recommendations = personalized_movies + discovery_movies
        random.shuffle(recommendations)
        
        print(f"📊 Returning {len(personalized_movies)} personalized + {len(discovery_movies)} discovery = {len(recommendations)} total")
        
        return recommendations
    
    def _calculate_genre_preferences(self, liked_movies: List[Movie]) -> Dict[str, float]:
        """
        Calculate genre preference scores based on liked movies.
        
        Args:
            liked_movies: List of movies the user liked
            
        Returns:
            Dictionary mapping genre to preference score (0.0 to 1.0)
        """
        if not liked_movies:
            return {}
        
        # Count genres
        genre_counts = Counter([movie.genre for movie in liked_movies])
        total_likes = len(liked_movies)
        
        # Calculate preference scores (ratio of likes)
        genre_preferences = {
            genre: count / total_likes 
            for genre, count in genre_counts.items()
        }
        
        return genre_preferences
    
    def get_user_stats(self, user_id: str) -> Dict:
        """
        Get user statistics for debugging/analytics.
        
        Args:
            user_id: User ID
            
        Returns:
            User statistics dictionary
        """
        swipes = self.supabase_ds.get_user_swipes(user_id)
        liked_ids = self.supabase_ds.get_user_liked_movie_ids(user_id)
        
        total_swipes = len(swipes)
        total_likes = len(liked_ids)
        total_passes = total_swipes - total_likes
        
        # Get liked movies to calculate genre preferences
        all_movies = self.supabase_ds.get_movies(limit=1000)
        liked_movies_data = [m for m in all_movies if m["id"] in liked_ids]
        liked_movies = [MovieModel(**movie_data).to_entity() for movie_data in liked_movies_data]
        
        genre_preferences = self._calculate_genre_preferences(liked_movies)
        
        return {
            "user_id": user_id,
            "total_swipes": total_swipes,
            "total_likes": total_likes,
            "total_passes": total_passes,
            "like_ratio": total_likes / total_swipes if total_swipes > 0 else 0,
            "genre_preferences": genre_preferences,
            "top_genres": sorted(genre_preferences.items(), key=lambda x: x[1], reverse=True)[:3]
        }
    
    def get_all_users(self) -> List[Dict]:
        """
        Get all users with basic statistics.
        
        Returns:
            List of user dictionaries with stats
        """
        # Get all distinct user IDs from swipes
        all_swipes = self.supabase_ds.client.table("user_swipes")\
            .select("user_id")\
            .execute()
        
        if not all_swipes.data:
            return []
        
        # Get unique user IDs
        user_ids = list(set([swipe["user_id"] for swipe in all_swipes.data]))
        
        # Get stats for each user
        users = []
        for user_id in user_ids:
            try:
                stats = self.get_user_stats(user_id)
                users.append(stats)
            except Exception as e:
                print(f"⚠️  Error getting stats for user {user_id}: {e}")
                continue
        
        return users
    
    def get_liked_movies_by_genre(self, user_id: str) -> Dict[str, List[Dict]]:
        """
        Get user's liked movies grouped by genre.
        
        Args:
            user_id: User ID
            
        Returns:
            Dictionary with genres as keys and movie lists as values
        """
        # Get all liked swipes
        liked_swipes = self.supabase_ds.client.table("user_swipes")\
            .select("movie_id")\
            .eq("user_id", user_id)\
            .eq("is_like", True)\
            .execute()
        
        if not liked_swipes.data:
            return {}
        
        # Get all movie IDs
        liked_movie_ids = [swipe["movie_id"] for swipe in liked_swipes.data]
        
        # Batch fetch all movies
        try:
            movies_data = self.supabase_ds.get_movies_by_ids(liked_movie_ids)
        except Exception as e:
            print(f"⚠️  Error batch fetching movies: {e}")
            return {}
            
        # Group by genre
        movies_by_genre = {}
        
        for movie in movies_data:
            genre = movie.get("genre", "General")
            
            if genre not in movies_by_genre:
                movies_by_genre[genre] = []
            
            movies_by_genre[genre].append({
                "id": movie["id"],
                "name": movie["name"],
                "genre": genre,
                "poster_path": movie.get("poster_path")
            })
        
        # Sort genres by number of movies (descending)
        sorted_genres = dict(sorted(
            movies_by_genre.items(),
            key=lambda x: len(x[1]),
            reverse=True
        ))
        
        return sorted_genres
