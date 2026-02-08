import 'package:dartz/dartz.dart';
import 'package:movieswipe/core/errors/failures.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/domain/repositories/movie_repository.dart';

/// Use case for searching movies
class SearchMovies {
  final MovieRepository repository;

  SearchMovies(this.repository);

  Future<Either<Failure, List<Movie>>> call(String query) async {
    return await repository.searchMovies(query);
  }
}
