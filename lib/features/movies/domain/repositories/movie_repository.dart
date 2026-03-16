import 'package:dartz/dartz.dart';
import 'package:movieswipe/core/errors/failures.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Abstract repository interface for movies
abstract class MovieRepository {
  /// Get list of movies
  Future<Either<Failure, List<Movie>>> getMovies();

  /// Get personalized movie recommendations
  Future<Either<Failure, List<Movie>>> getRecommendedMovies();

  /// Swipe movie (like/dislike)
  Future<Either<Failure, void>> swipeMovie(int movieId, bool isLike, String userId, {int? rating});

  /// Search movies
  Future<Either<Failure, List<Movie>>> searchMovies(String query);
}
