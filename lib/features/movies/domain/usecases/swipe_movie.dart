import 'package:dartz/dartz.dart';
import 'package:movieswipe/core/errors/failures.dart';
import 'package:movieswipe/features/movies/domain/repositories/movie_repository.dart';

/// Use case for swiping a movie
class SwipeMovie {
  final MovieRepository repository;

  SwipeMovie(this.repository);

  Future<Either<Failure, void>> call({
    required int movieId,
    required bool isLike,
    required String userId,
    int? rating,
  }) async {
    // Retry logic: 3 attempts with exponential backoff
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      attempts++;
      
      final result = await repository.swipeMovie(movieId, isLike, userId, rating: rating);
      
      // If successful, return immediately
      if (result.isRight()) {
        return result;
      }
      
      // If this was the last attempt, return the error
      if (attempts >= maxAttempts) {
        return result;
      }
      
      // Wait before retrying (exponential backoff: 500ms, 1s, 2s)
      final delayMs = 500 * (1 << (attempts - 1));
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    
    // This should never be reached, but just in case
    return Left(ServerFailure('Failed to save swipe after $maxAttempts attempts'));
  }
}
