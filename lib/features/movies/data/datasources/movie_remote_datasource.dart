import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/core/errors/exceptions.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';

/// Remote data source for movies
abstract class MovieRemoteDataSource {
  Future<List<MovieModel>> getMovies();
  Future<void> swipeMovie(int movieId, bool isLike);
}

/// Implementation of remote data source
class MovieRemoteDataSourceImpl implements MovieRemoteDataSource {
  final ApiClient apiClient;

  MovieRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<MovieModel>> getMovies() async {
    try {
      final response = await apiClient.get('/movies');
      
      // Response is a List of movies
      if (response is! List) {
        throw ServerException(message: 'Invalid response format');
      }
      
      return (response as List<dynamic>)
          .map((json) => MovieModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to fetch movies: $e');
    }
  }

  @override
  Future<void> swipeMovie(int movieId, bool isLike) async {
    try {
      await apiClient.post(
        '/movies/$movieId/swipe',
        body: {'isLike': isLike},
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to swipe movie: $e');
    }
  }
}
