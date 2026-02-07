import 'package:dartz/dartz.dart';
import 'package:movieswipe/core/errors/exceptions.dart';
import 'package:movieswipe/core/errors/failures.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/domain/repositories/movie_repository.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_local_datasource.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_remote_datasource.dart';

/// Repository implementation
class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource remoteDataSource;
  final MovieLocalDataSource localDataSource;

  MovieRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<Movie>>> getMovies() async {
    try {
      // Try to get from remote
      final remoteMovies = await remoteDataSource.getMovies();
      
      // Cache the result
      await localDataSource.cacheMovies(remoteMovies);
      
      // Convert models to entities
      final movies = remoteMovies.map((model) => model.toEntity()).toList();
      
      return Right(movies);
    } on ServerException catch (e) {
      // Try to get from cache on failure
      try {
        final cachedMovies = await localDataSource.getCachedMovies();
        final movies = cachedMovies.map((model) => model.toEntity()).toList();
        return Right(movies);
      } catch (_) {
        return Left(ServerFailure(e.message));
      }
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> swipeMovie(int movieId, bool isLike) async {
    try {
      await remoteDataSource.swipeMovie(movieId, isLike);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
