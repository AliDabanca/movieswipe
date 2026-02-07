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
  }) async {
    return await repository.swipeMovie(movieId, isLike);
  }
}
