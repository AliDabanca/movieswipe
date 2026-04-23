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
  static const _cacheKeyMood = 'cached_mood_history';

  // Liked movies structured data
  List<Map<String, dynamic>> _recentlyAddedAll = [];
  Map<String, List<Map<String, dynamic>>> _moviesByGenre = {};
  
  // User stats
  int _totalSwipes = 0;
  int _totalLikes = 0;
  int _totalPasses = 0;
  List<dynamic> _topGenres = [];

  // Mood
  List<Map<String, dynamic>> _moodHistory = [];
  String? _currentMood;
  String? _currentEmoji;

  // Sorting
  SortCriteria _currentSortCriteria = SortCriteria.recentlyAdded;

  // Loading state
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isInitialized = false;  // becomes true once loadFromApi is first called

  // Counters (Persistent via SharedPreferences)
  int _smartDiscoveryCount = 0;
  int _moodDiscoveryCount = 0;

  LikedMoviesProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(client: null) {
    _loadCounters();
  }

  // Getters
  List<Map<String, dynamic>> get recentlyAddedAll => _recentlyAddedAll;
  Map<String, List<Map<String, dynamic>>> get moviesByGenre => _moviesByGenre;
  int get totalSwipes => _totalSwipes;
  int get totalLikes => _totalLikes;
  int get totalPasses => _totalPasses;
  double get likeRatio => _totalSwipes > 0 ? _totalLikes / _totalSwipes : 0.0;
  List<dynamic> get topGenres => _topGenres;
  List<Map<String, dynamic>> get moodHistory => _moodHistory;
  String? get currentMood => _currentMood;
  String? get currentEmoji => _currentEmoji;
  bool get isLoaded => _isLoaded;
  /// Returns true if data is actively loading OR if loadFromApi hasn't been called yet.
  /// This prevents the UI from briefly showing empty state on startup.
  bool get isLoading => _isLoading || !_isInitialized;
  SortCriteria get currentSortCriteria => _currentSortCriteria;

  // Counter Getters
  int get smartDiscoveryCount => _smartDiscoveryCount;
  int get moodDiscoveryCount => _moodDiscoveryCount;

  /// Look up the current user rating for a movie by its ID.
  /// Returns null if the movie is not in the liked list or has no rating.
  int? getMovieRating(int movieId) {
    for (final movies in _moviesByGenre.values) {
      for (final m in movies) {
        if (m['id'] == movieId) {
          return m['user_rating'] as int?;
        }
      }
    }
    return null;
  }

  /// Check if a movie is already in the liked list.
  bool isMovieLiked(int movieId) {
    for (final movies in _moviesByGenre.values) {
      if (movies.any((m) => m['id'] == movieId)) {
        return true;
      }
    }
    return false;
  }

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

  /// List of ALL achievements with unlock status
  List<Map<String, dynamic>> get achievements {
    // Check genre master
    String? genreMasterName;
    for (final genre in _topGenres) {
      if ((genre[1] as num) > 0.4 && _totalLikes > 20) {
        genreMasterName = genre[0] as String;
        break;
      }
    }

    // Check if user has rated any movie 5 stars
    bool hasGivenFiveStars = false;
    for (final movies in _moviesByGenre.values) {
      for (final m in movies) {
        if ((m['user_rating'] as int?) == 5) {
          hasGivenFiveStars = true;
          break;
        }
      }
      if (hasGivenFiveStars) break;
    }

    // NEW LOGIC HELPERS
    final allMoviesList = _moviesByGenre.values.expand((list) => list).toList();
    
    // 1. Decade/Era Logic
    final Set<int> decadesLikes = {};
    int pre1990Count = 0;
    int pre1970Count = 0;
    int post2020Count = 0;
    
    // 2. Critical Logic
    int fiveStarCount = 0;
    int totalRatedCount = 0;
    int highTmdbCount = 0; // 8.5+
    
    // 3. Genre Specific
    int animationCount = _moviesByGenre['Animation']?.length ?? 0;
    int docCount = _moviesByGenre['Documentary']?.length ?? 0;

    for (final movie in allMoviesList) {
      final releaseDate = movie['release_date'] as String? ?? '';
      if (releaseDate.length >= 4) {
        final year = int.tryParse(releaseDate.substring(0, 4)) ?? 0;
        if (year > 0) {
          decadesLikes.add((year / 10).floor() * 10);
          if (year < 1990) pre1990Count++;
          if (year < 1970) pre1970Count++;
          if (year >= 2020) post2020Count++;
        }
      }

      final userRating = movie['user_rating'] as int? ?? 0;
      if (userRating > 0) totalRatedCount++;
      if (userRating == 5) fiveStarCount++;
      
      final tmdbScore = (movie['vote_average'] as num? ?? 0.0);
      if (tmdbScore >= 8.5) highTmdbCount++;
    }

    // 4. Balanced Taste Logic (Top 3 genres within 0.2)
    bool isBalanced = false;
    if (_topGenres.length >= 3) {
      final score1 = _topGenres[0][1] as num;
      final score3 = _topGenres[2][1] as num;
      if ((score1 - score3).abs() <= 0.2) isBalanced = true;
    }

    return [
      // --- CORE (Existing 10) ---
      {
        'id': 'first_swipe',
        'title': 'İlk Adım',
        'icon': '🎯',
        'description': 'İlk swipe\'ını yap',
        'isUnlocked': _totalSwipes > 0,
      },
      {
        'id': 'like_10',
        'title': 'Zevk Sahibi',
        'icon': '⭐',
        'description': '10 film beğen',
        'isUnlocked': _totalLikes >= 10,
      },
      {
        'id': 'like_50',
        'title': 'Film Kurdu',
        'icon': '🎬',
        'description': '50 film beğen',
        'isUnlocked': _totalLikes >= 50,
      },
      {
        'id': 'pass_50',
        'title': 'Seçici Ruh',
        'icon': '🧐',
        'description': '50 film geç',
        'isUnlocked': _totalPasses >= 50,
      },
      {
        'id': 'diverse_taste',
        'title': 'Gurme',
        'icon': '🌍',
        'description': '5 farklı türden film beğen',
        'isUnlocked': _moviesByGenre.keys.length >= 5,
      },
      {
        'id': 'marathon',
        'title': 'Maratoncu',
        'icon': '🏃',
        'description': '100 swipe yap',
        'isUnlocked': _totalSwipes >= 100,
      },
      {
        'id': 'picky_eater',
        'title': 'Zor Beğenen',
        'icon': '🍷',
        'description': 'Beğeni oranı %30 altında (min 20 swipe)',
        'isUnlocked': _totalSwipes >= 20 && likeRatio < 0.3,
      },
      {
        'id': 'perfect_match',
        'title': 'Her Şeyi Sever',
        'icon': '💖',
        'description': 'Beğeni oranı %70 üstünde (min 20 swipe)',
        'isUnlocked': _totalSwipes >= 20 && likeRatio > 0.7,
      },
      {
        'id': 'critic',
        'title': 'Eleştirmen',
        'icon': '📝',
        'description': 'Bir filme 5 yıldız ver',
        'isUnlocked': hasGivenFiveStars,
      },
      {
        'id': 'genre_master',
        'title': genreMasterName != null ? '$genreMasterName Ustası' : 'Tür Ustası',
        'icon': '🏆',
        'description': 'Bir türde %40+ beğeni oranına ulaş',
        'isUnlocked': genreMasterName != null,
      },

      // --- NEW: AI & Discovery ---
      {
        'id': 'ai_explorer',
        'title': 'AI Kaşifi',
        'icon': '🧠',
        'description': 'Smart AI Discovery\'i 5 kez kullan',
        'isUnlocked': _smartDiscoveryCount >= 5,
      },
      {
        'id': 'mood_voyager',
        'title': 'Duygusal Yolculuk',
        'icon': '🌈',
        'description': 'Mod tabanlı keşfi 10 kez kullan',
        'isUnlocked': _moodDiscoveryCount >= 10,
      },
      {
        'id': 'indecisive',
        'title': 'Kararsız',
        'icon': '🌀',
        'description': 'Toplam 200 film kaydır',
        'isUnlocked': _totalSwipes >= 200,
      },

      // --- NEW: Time Travelers ---
      {
        'id': 'nostalgia_king',
        'title': 'Nostalji Kralı',
        'icon': '📽️',
        'description': '1990 öncesi 10 film beğen',
        'isUnlocked': pre1990Count >= 10,
      },
      {
        'id': 'vintage_soul',
        'title': 'Siyah Beyaz Ruhu',
        'icon': '🎞️',
        'description': '1970 öncesi 3 film beğen',
        'isUnlocked': pre1970Count >= 3,
      },
      {
        'id': 'modernist',
        'title': 'Modernist',
        'icon': '🚀',
        'description': '2020 sonrası 15 film beğen',
        'isUnlocked': post2020Count >= 15,
      },
      {
        'id': 'century_fan',
        'title': 'Yüzyılın İzleyicisi',
        'icon': '📜',
        'description': '5 farklı on yıla ait film beğen',
        'isUnlocked': decadesLikes.length >= 5,
      },

      // --- NEW: Critical Thinking ---
      {
        'id': 'generous',
        'title': 'Cömert',
        'icon': '💎',
        'description': '5 farklı filme 5 yıldız ver',
        'isUnlocked': fiveStarCount >= 5,
      },
      {
        'id': 'perfectionist',
        'title': 'Mükemmeliyetçi',
        'icon': '🌟',
        'description': 'Puanı 8.5+ olan 10 film beğen',
        'isUnlocked': highTmdbCount >= 10,
      },
      {
        'id': 'master_critic',
        'title': 'Usta Eleştirmen',
        'icon': '🖋️',
        'description': 'Toplam 20 filme puan ver',
        'isUnlocked': totalRatedCount >= 20,
      },

      // --- NEW: Collector & Genre ---
      {
        'id': 'genre_collector',
        'title': 'Tür Koleksiyoncusu',
        'icon': '🏺',
        'description': '10 farklı türden film beğen',
        'isUnlocked': _moviesByGenre.keys.length >= 10,
      },
      {
        'id': 'animation_fan',
        'title': 'Animasyon Sever',
        'icon': '🐬',
        'description': '5 animasyon filmi beğen',
        'isUnlocked': animationCount >= 5,
      },
      {
        'id': 'doc_buff',
        'title': 'Belgesel Meraklısı',
        'icon': '📚',
        'description': '3 belgesel beğen',
        'isUnlocked': docCount >= 3,
      },
      {
        'id': 'balanced_taste',
        'title': 'Dengeli Zevk',
        'icon': '⚖️',
        'description': 'Tüm türlere karşı adilsin',
        'isUnlocked': isBalanced,
      },
    ];
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
    _isInitialized = true;
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
        _apiClient.get('/users/me/mood-history'),
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

      // Parse mood
      final moodRes = results[2] as Map<String, dynamic>;
      _moodHistory = (moodRes['mood_history'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _currentMood = moodRes['current_mood'] as String?;
      _currentEmoji = moodRes['current_emoji'] as String?;

      _isLoaded = true;

      // Save to cache for next startup
      await _saveToCache(userId);
    } catch (e) {
      // logger.error('❌ Failed to load from API: $e');
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
      final moodJson = prefs.getString('${_cacheKeyMood}_$userId');

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

        // Parse cached mood
        if (moodJson != null) {
          final moodData = jsonDecode(moodJson) as Map<String, dynamic>;
          _moodHistory = (moodData['mood_history'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _currentMood = moodData['current_mood'] as String?;
          _currentEmoji = moodData['current_emoji'] as String?;
        }

        _isLoaded = true;
      }
    } catch (e) {
      // logger.error('⚠️ Cache load failed: $e');
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

      // Save mood
      final moodJson = jsonEncode({
        'mood_history': _moodHistory,
        'current_mood': _currentMood,
        'current_emoji': _currentEmoji,
      });
      await prefs.setString('${_cacheKeyMood}_$userId', moodJson);
    } catch (e) {
      debugPrint('⚠️ Cache save failed: $e');
    }
  }

  /// Optimistically add a liked movie (called immediately on swipe right)
  void addLikedMovie(Movie movie) {
    final genre = movie.genre;
    // Check if we already have a rating for this movie in memory to prevent overwriting with 0/null
    var finalRating = movie.userRating;
    if (finalRating == null || finalRating == 0) {
      final existingRating = getMovieRating(movie.id);
      if (existingRating != null && existingRating > 0) {
        finalRating = existingRating;
      }
    }

    final movieMap = {
      'id': movie.id,
      'name': movie.name,
      'genre': genre,
      'poster_path': movie.posterPath,
      'vote_average': movie.voteAverage,
      'release_date': movie.releaseDate,
      'user_rating': finalRating,
    };

    // Check if movie already exists in this genre's list
    bool alreadyExists = false;
    if (_moviesByGenre.containsKey(genre)) {
      final existingIndex = _moviesByGenre[genre]!.indexWhere((m) => m['id'] == movie.id);
      if (existingIndex != -1) {
        // Movie already in the list — update its data in place
        _moviesByGenre[genre]![existingIndex] = movieMap;
        alreadyExists = true;
      } else {
        _moviesByGenre[genre]!.insert(0, movieMap);
      }
    } else {
      _moviesByGenre[genre] = [movieMap];
    }
    
    // Guard recentlyAddedAll against duplicates too
    final recentIndex = _recentlyAddedAll.indexWhere((m) => m['id'] == movie.id);
    if (recentIndex != -1) {
      _recentlyAddedAll[recentIndex] = movieMap;
    } else {
      _recentlyAddedAll.insert(0, movieMap);
      if (_recentlyAddedAll.length > 10) {
        _recentlyAddedAll.removeLast();
      }
    }

    // Only increment stats if this is a genuinely new like, not a re-swipe
    if (!alreadyExists) {
      _totalSwipes++;
      _totalLikes++;
      _recalculateTopGenres();
    }
    notifyListeners();
  }

  /// Optimistically record a pass (swipe left)
  void addPass() {
    _totalSwipes++;
    _totalPasses++;
    notifyListeners();
  }

  /// Remove a movie from liked list (un-swipe/unlike)
  void removeLikedMovie(int movieId) {
    bool removed = false;

    // 1. Remove from byGenre maps
    _moviesByGenre.forEach((genre, list) {
      final index = list.indexWhere((m) => m['id'] == movieId);
      if (index != -1) {
        list.removeAt(index);
        removed = true;
      }
    });

    // Clean up empty genre lists
    _moviesByGenre.removeWhere((genre, list) => list.isEmpty);

    // 2. Remove from recentlyAddedAll
    final recentIndex = _recentlyAddedAll.indexWhere((m) => m['id'] == movieId);
    if (recentIndex != -1) {
      _recentlyAddedAll.removeAt(recentIndex);
      removed = true;
    }

    if (removed) {
      // 3. Update stats (Decrementing because we are undoing a like)
      _totalSwipes--;
      _totalLikes--;
      _recalculateTopGenres();
      notifyListeners();
    }
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
    _moodHistory = [];
    _currentMood = null;
    _currentEmoji = null;
    _isLoaded = false;
    notifyListeners();
  }

  // --- PERSISTENT COUNTERS ---

  static const _keySmartCount = 'smart_discovery_count';
  static const _keyMoodCount = 'mood_discovery_count';

  Future<void> _loadCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _smartDiscoveryCount = prefs.getInt(_keySmartCount) ?? 0;
      _moodDiscoveryCount = prefs.getInt(_keyMoodCount) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to load counters: $e');
    }
  }

  Future<void> _saveCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySmartCount, _smartDiscoveryCount);
      await prefs.setInt(_keyMoodCount, _moodDiscoveryCount);
    } catch (e) {
      debugPrint('⚠️ Failed to save counters: $e');
    }
  }

  void incrementSmartDiscovery() {
    _smartDiscoveryCount++;
    _saveCounters();
    notifyListeners();
  }

  void incrementMoodDiscovery() {
    _moodDiscoveryCount++;
    _saveCounters();
    notifyListeners();
  }
}
