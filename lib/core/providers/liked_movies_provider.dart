import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Shared state provider for liked movies and user stats.
/// Enables optimistic UI updates across all tabs.
/// Caches data locally for instant startup.
class LikedMoviesProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  // Cache keys
  static const _cacheKeyMovies = 'cached_liked_movies';
  static const _cacheKeyStats = 'cached_user_stats';

  // Liked movies grouped by genre
  Map<String, List<Map<String, dynamic>>> _moviesByGenre = {};
  
  // User stats
  int _totalSwipes = 0;
  int _totalLikes = 0;
  int _totalPasses = 0;
  List<dynamic> _topGenres = [];

  // Loading state
  bool _isLoaded = false;
  bool _isLoading = false;

  LikedMoviesProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(client: null);

  // Getters
  Map<String, List<Map<String, dynamic>>> get moviesByGenre => _moviesByGenre;
  int get totalSwipes => _totalSwipes;
  int get totalLikes => _totalLikes;
  int get totalPasses => _totalPasses;
  double get likeRatio => _totalSwipes > 0 ? _totalLikes / _totalSwipes : 0.0;
  List<dynamic> get topGenres => _topGenres;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Load data: first from cache (instant), then refresh from API (background)
  Future<void> loadFromApi(String userId) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    // Step 1: Load from cache immediately
    await _loadFromCache(userId);
    if (_isLoaded) {
      // Cache hit — show data immediately, keep loading in background
      _isLoading = true; // still loading from API
      notifyListeners();
    }

    // Step 2: Refresh from API in background
    try {
      final results = await Future.wait([
        _apiClient.get('/users/me/liked-movies'),
        _apiClient.get('/users/me/stats'),
      ]);

      // Parse liked movies
      final moviesData = results[0] as Map;
      _moviesByGenre = Map<String, List<Map<String, dynamic>>>.from(
        moviesData.map((key, value) => MapEntry(
          key as String,
          (value as List).map((m) => Map<String, dynamic>.from(m as Map)).toList(),
        )),
      );

      // Parse stats
      final stats = results[1] as Map<String, dynamic>;
      _totalSwipes = stats['total_swipes'] ?? 0;
      _totalLikes = stats['total_likes'] ?? 0;
      _totalPasses = stats['total_passes'] ?? 0;
      _topGenres = stats['top_genres'] as List? ?? [];

      _isLoaded = true;

      // Save to cache for next startup
      await _saveToCache(userId);
    } catch (e) {
      print('❌ Failed to load from API: $e');
      // If cache was loaded, we still have data — that's fine
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load cached data from SharedPreferences
  Future<void> _loadFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moviesJson = prefs.getString('${_cacheKeyMovies}_$userId');
      final statsJson = prefs.getString('${_cacheKeyStats}_$userId');

      if (moviesJson != null && statsJson != null) {
        // Parse cached movies
        final moviesData = jsonDecode(moviesJson) as Map<String, dynamic>;
        _moviesByGenre = moviesData.map((key, value) => MapEntry(
          key,
          (value as List).map((m) => Map<String, dynamic>.from(m as Map)).toList(),
        ));

        // Parse cached stats
        final stats = jsonDecode(statsJson) as Map<String, dynamic>;
        _totalSwipes = stats['total_swipes'] ?? 0;
        _totalLikes = stats['total_likes'] ?? 0;
        _totalPasses = stats['total_passes'] ?? 0;
        _topGenres = stats['top_genres'] as List? ?? [];

        _isLoaded = true;
        print('⚡ Loaded from cache instantly');
      }
    } catch (e) {
      print('⚠️ Cache load failed: $e');
    }
  }

  /// Save current data to SharedPreferences
  Future<void> _saveToCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save movies
      final moviesJson = jsonEncode(_moviesByGenre);
      await prefs.setString('${_cacheKeyMovies}_$userId', moviesJson);

      // Save stats
      final statsJson = jsonEncode({
        'total_swipes': _totalSwipes,
        'total_likes': _totalLikes,
        'total_passes': _totalPasses,
        'top_genres': _topGenres,
      });
      await prefs.setString('${_cacheKeyStats}_$userId', statsJson);
    } catch (e) {
      print('⚠️ Cache save failed: $e');
    }
  }

  /// Optimistically add a liked movie (called immediately on swipe right)
  void addLikedMovie(Movie movie) {
    final genre = movie.genre;
    final movieMap = {
      'id': movie.id,
      'name': movie.name,
      'genre': genre,
      'poster_path': movie.posterPath,
    };

    if (_moviesByGenre.containsKey(genre)) {
      _moviesByGenre[genre]!.insert(0, movieMap);
    } else {
      _moviesByGenre[genre] = [movieMap];
    }

    // Update stats
    _totalSwipes++;
    _totalLikes++;
    _recalculateTopGenres();
    notifyListeners();
  }

  /// Optimistically record a pass (swipe left)
  void addPass() {
    _totalSwipes++;
    _totalPasses++;
    notifyListeners();
  }

  /// Rollback a liked movie if API call fails
  void rollbackLikedMovie(Movie movie) {
    final genre = movie.genre;
    if (_moviesByGenre.containsKey(genre)) {
      _moviesByGenre[genre]!.removeWhere((m) => m['id'] == movie.id);
      if (_moviesByGenre[genre]!.isEmpty) {
        _moviesByGenre.remove(genre);
      }
    }

    _totalSwipes--;
    _totalLikes--;
    _recalculateTopGenres();
    notifyListeners();
  }

  /// Rollback a pass if API call fails
  void rollbackPass() {
    _totalSwipes--;
    _totalPasses--;
    notifyListeners();
  }

  /// Recalculate top genres from current liked movies
  void _recalculateTopGenres() {
    final genreCounts = <String, int>{};
    int totalMovies = 0;

    for (final entry in _moviesByGenre.entries) {
      genreCounts[entry.key] = entry.value.length;
      totalMovies += entry.value.length;
    }

    if (totalMovies == 0) {
      _topGenres = [];
      return;
    }

    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _topGenres = sorted
        .take(3)
        .map((e) => [e.key, e.value / totalMovies])
        .toList();
  }

  /// Clear all data (e.g., on user switch)
  void clear() {
    _moviesByGenre = {};
    _totalSwipes = 0;
    _totalLikes = 0;
    _totalPasses = 0;
    _topGenres = [];
    _isLoaded = false;
    notifyListeners();
  }
}
