import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/core/errors/exceptions.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';

/// Remote data source for movies
abstract class MovieRemoteDataSource {
  Future<List<MovieModel>> getMovies();
  Future<List<MovieModel>> getRecommendedMovies(); // NEW: Personalized recommendations
  Future<List<MovieModel>> searchMovies(String query);
  Future<void> swipeMovie(int movieId, bool isLike, String userId, {int? rating});
  Future<MovieDetailModel> getMovieDetails(int movieId);
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
  Future<List<MovieModel>> getRecommendedMovies() async {
    try {
      final response = await apiClient.get('/recommendations');
      
      // Response is now a wrapped object: {status, movies, message}
      if (response is Map<String, dynamic>) {
        final status = response['status'] as String?;
        
        if (status == 'end_of_content') {
          final message = response['message'] as String? ?? 
              'Keşfedecek film kalmadı!';
          throw EndOfContentException(message: message);
        }
        
        // status == "ok" — parse movies list
        final moviesList = response['movies'] as List<dynamic>? ?? [];
        return moviesList
            .map((json) => MovieModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      // Fallback: legacy format (plain list) for backward compatibility
      if (response is List) {
        return (response as List<dynamic>)
            .map((json) => MovieModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw ServerException(message: 'Invalid response format');
    } on EndOfContentException {
      rethrow;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to fetch recommendations: $e');
    }
  }

  @override
  Future<void> swipeMovie(int movieId, bool isLike, String userId, {int? rating}) async {
    try {
      await apiClient.post(
        '/movies/$movieId/swipe',
        body: {
          'isLike': isLike,
          if (rating != null) 'rating': rating,
          // userId now comes from JWT token automatically via ApiClient headers
        },
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to swipe movie: $e');
    }
  }

  @override
  Future<List<MovieModel>> searchMovies(String query) async {
    try {
      final response = await apiClient.get('/movies/search?query=$query');
      
      // Response is a List of movies
      if (response is! List) {
        throw ServerException(message: 'Invalid response format');
      }
      
      return (response as List<dynamic>)
          .map((json) => MovieModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to search movies: $e');
    }
  }
  @override
  Future<MovieDetailModel> getMovieDetails(int movieId) async {
    try {
      final response = await apiClient.get('/movies/$movieId/details');

      if (response is! Map<String, dynamic>) {
        throw ServerException(message: 'Invalid response format');
      }

      return MovieDetailModel.fromJson(response);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to fetch movie details: $e');
    }
  }
}
