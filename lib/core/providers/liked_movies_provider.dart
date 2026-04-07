import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';

enum SortCriteria {
  recentlyAdded,
  highestRated,
  alphabetical,
  releaseDate
}

/// Shared state provider for liked movies and user stats.
/// Enables optimistic UI updates across all tabs.
/// Caches data locally for instant startup.
class LikedMoviesProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  // Cache keys
  static const _cacheKeyMovies = 'cached_liked_movies';
  static const _cacheKeyStats = 'cached_user_stats';

  // Liked movies structured data
  List<Map<String, dynamic>> _recentlyAddedAll = [];
  Map<String, List<Map<String, dynamic>>> _moviesByGenre = {};
  
  // User stats
  int _totalSwipes = 0;
  int _totalLikes = 0;
  int _totalPasses = 0;
  List<dynamic> _topGenres = [];

  // Sorting
  SortCriteria _currentSortCriteria = SortCriteria.recentlyAdded;

  // Loading state
  bool _isLoaded = false;
  bool _isLoading = false;

  LikedMoviesProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(client: null);

  // Getters
  List<Map<String, dynamic>> get recentlyAddedAll => _recentlyAddedAll;
  Map<String, List<Map<String, dynamic>>> get moviesByGenre => _moviesByGenre;
  int get totalSwipes => _totalSwipes;
  int get totalLikes => _totalLikes;
  int get totalPasses => _totalPasses;
  double get likeRatio => _totalSwipes > 0 ? _totalLikes / _totalSwipes : 0.0;
  List<dynamic> get topGenres => _topGenres;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  SortCriteria get currentSortCriteria => _currentSortCriteria;

  /// Dynamic title based on top genre
  String get movieDnaTitle {
    if (_totalLikes < 10) return 'Yeni İzleyici';
    if (_topGenres.isEmpty) return 'Keşifçi';
    
    final topGenre = _topGenres[0][0] as String;
    switch (topGenre) {
      case 'Action': return 'Aksiyon Tutkunu';
      case 'Comedy': return 'Kahkaha Avcısı';
      case 'Drama': return 'Drama Eleştirmeni';
      case 'Horror': return 'Korkusuz İzleyici';
      case 'Sci-Fi': 
      case 'Science Fiction': return 'Bilimkurgu Gezgini';
      case 'Romance': return 'Romantik Ruh';
      case 'Animation': return 'Animasyon Sever';
      case 'Documentary': return 'Bilgi Küpü';
      case 'Thriller': return 'Gerilim Avcısı';
      case 'Fantasy': return 'Hayalperest';
      default: return 'Film Gurmesi';
    }
  }

  /// List of unlocked achievements
  List<Map<String, dynamic>> get achievements {
    final list = <Map<String, dynamic>>[];
    
    if (_totalSwipes > 0) {
      list.add({'id': 'first_swipe', 'title': 'İlk Adım', 'icon': '🎯'});
    }
    if (_totalLikes >= 10) {
      list.add({'id': 'like_10', 'title': 'Zevk Sahibi', 'icon': '⭐'});
    }
    if (_totalLikes >= 50) {
      list.add({'id': 'like_50', 'title': 'Film Kurdu', 'icon': '🎬'});
    }
    if (_totalPasses >= 50) {
      list.add({'id': 'pass_50', 'title': 'Zor Beğenen', 'icon': '🧐'});
    }
    
    // Genre specific
    for (final genre in _topGenres) {
      if ((genre[1] as num) > 0.4 && _totalLikes > 20) {
        list.add({'id': 'genre_master', 'title': '${genre[0]} Ustası', 'icon': '🏆'});
        break; 
      }
    }
    
    return list;
  }

  void setSortCriteria(SortCriteria criteria) {
    if (_currentSortCriteria != criteria) {
      _currentSortCriteria = criteria;
      notifyListeners();
    }
  }

  /// Get movies filtered by genre and sorted by current criteria
  List<Map<String, dynamic>> getSortedMoviesByGenre(String? genre) {
    List<Map<String, dynamic>> movies;
    if (genre == null) {
      movies = _moviesByGenre.values.expand((list) => list).toList();
    } else {
      movies = List.from(_moviesByGenre[genre] ?? []);
    }

    switch (_currentSortCriteria) {
      case SortCriteria.recentlyAdded:
        // Already in order of addition (assuming prepended or loaded sorted)
        return movies;
      case SortCriteria.highestRated:
        return movies..sort((a, b) => (b['vote_average'] as num? ?? 0).compareTo(a['vote_average'] as num? ?? 0));
      case SortCriteria.alphabetical:
        return movies..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      case SortCriteria.releaseDate:
        return movies..sort((a, b) => (b['release_date'] as String? ?? '').compareTo(a['release_date'] as String? ?? ''));
    }
  }

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
      final moviesResponse = results[0] as Map;
      final recentlyAddedData = moviesResponse['recently_added'] as List? ?? [];
      final byGenreData = moviesResponse['by_genre'] as Map? ?? {};

      _recentlyAddedAll = recentlyAddedData.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      
      _moviesByGenre = Map<String, List<Map<String, dynamic>>>.from(
        byGenreData.map((key, value) => MapEntry(
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
        
        if (moviesData.containsKey('recently_added')) {
          final recentlyAddedData = moviesData['recently_added'] as List? ?? [];
          final byGenreData = moviesData['by_genre'] as Map<String, dynamic>? ?? {};

          _recentlyAddedAll = recentlyAddedData.map((m) => Map<String, dynamic>.from(m as Map)).toList();
          _moviesByGenre = byGenreData.map((key, value) => MapEntry(
            key,
            (value as List).map((m) => Map<String, dynamic>.from(m as Map)).toList(),
          ));
        } else {
          // Fallback for older cache format
          _moviesByGenre = moviesData.map((key, value) => MapEntry(
            key,
            (value as List).map((m) => Map<String, dynamic>.from(m as Map)).toList(),
          ));
          _recentlyAddedAll = [];
        }

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
      final moviesJson = jsonEncode({
        'recently_added': _recentlyAddedAll,
        'by_genre': _moviesByGenre,
      });
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
      'vote_average': movie.voteAverage,
      'release_date': movie.releaseDate,
      'user_rating': movie.userRating,
    };

    if (_moviesByGenre.containsKey(genre)) {
      _moviesByGenre[genre]!.insert(0, movieMap);
    } else {
      _moviesByGenre[genre] = [movieMap];
    }
    
    // Add to recently added and keep up to 10
    _recentlyAddedAll.insert(0, movieMap);
    if (_recentlyAddedAll.length > 10) {
      _recentlyAddedAll.removeLast();
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

  /// Update the rating for a movie that is already in the liked list
  void updateMovieRating(int movieId, int rating) {
    bool found = false;

    // Update in recentlyAddedAll
    for (var i = 0; i < _recentlyAddedAll.length; i++) {
      if (_recentlyAddedAll[i]['id'] == movieId) {
        _recentlyAddedAll[i]['user_rating'] = rating;
        found = true;
      }
    }

    // Update in moviesByGenre
    _moviesByGenre.forEach((genre, list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i]['id'] == movieId) {
          list[i]['user_rating'] = rating;
          found = true;
        }
      }
    });

    if (found) {
      notifyListeners();
      // Optional: Save to cache immediately if needed, 
      // but usually the next loadFromApi or explicit save will do it.
    }
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
    
    _recentlyAddedAll.removeWhere((m) => m['id'] == movie.id);

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
    _recentlyAddedAll = [];
    _moviesByGenre = {};
    _totalSwipes = 0;
    _totalLikes = 0;
    _totalPasses = 0;
    _topGenres = [];
    _isLoaded = false;
    notifyListeners();
  }
}
