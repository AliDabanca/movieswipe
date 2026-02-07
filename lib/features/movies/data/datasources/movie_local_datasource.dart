import 'package:movieswipe/features/movies/data/models/movie_model.dart';

/// Local data source for movies (cache)
abstract class MovieLocalDataSource {
  Future<List<MovieModel>> getCachedMovies();
  Future<void> cacheMovies(List<MovieModel> movies);
}

/// Implementation of local data source
class MovieLocalDataSourceImpl implements MovieLocalDataSource {
  List<MovieModel>? _cachedMovies;

  @override
  Future<List<MovieModel>> getCachedMovies() async {
    if (_cachedMovies != null) {
      return _cachedMovies!;
    }
    throw Exception('No cached movies found');
  }

  @override
  Future<void> cacheMovies(List<MovieModel> movies) async {
    _cachedMovies = movies;
  }
}
