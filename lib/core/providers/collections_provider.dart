import 'package:flutter/foundation.dart';
import 'package:movieswipe/core/network/api_client.dart';

/// A single collection summary (no movie details).
class CollectionSummary {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPublic;
  final int movieCount;
  final String? coverPosterPath;
  final String? createdAt;
  /// Only set when querying per-movie context (contains_movie endpoint).
  final bool? containsMovie;

  CollectionSummary({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isPublic = true,
    this.movieCount = 0,
    this.coverPosterPath,
    this.createdAt,
    this.containsMovie,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    return CollectionSummary(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      movieCount: json['movie_count'] as int? ?? 0,
      coverPosterPath: json['cover_poster_path'] as String?,
      createdAt: json['created_at'] as String?,
      containsMovie: json['contains_movie'] as bool?,
    );
  }
}

/// A movie inside a collection detail.
class CollectionMovie {
  final int id;
  final String name;
  final String genre;
  final String? posterPath;
  final double? voteAverage;
  final int? userRating;

  CollectionMovie({
    required this.id,
    required this.name,
    this.genre = 'General',
    this.posterPath,
    this.voteAverage,
    this.userRating,
  });

  factory CollectionMovie.fromJson(Map<String, dynamic> json) {
    return CollectionMovie(
      id: json['id'] as int,
      name: json['name'] as String,
      genre: json['genre'] as String? ?? 'General',
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      userRating: json['user_rating'] as int?,
    );
  }
}

/// Full collection detail (with movies list).
class CollectionDetail {
  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final int movieCount;
  final String? coverPosterPath;
  final List<CollectionMovie> movies;

  CollectionDetail({
    required this.id,
    required this.name,
    this.description,
    this.isPublic = true,
    this.movieCount = 0,
    this.coverPosterPath,
    this.movies = const [],
  });

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final moviesList = (json['movies'] as List<dynamic>?)
            ?.map((m) => CollectionMovie.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return CollectionDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      movieCount: json['movie_count'] as int? ?? moviesList.length,
      coverPosterPath: json['cover_poster_path'] as String?,
      movies: moviesList,
    );
  }
}

/// Provider for managing user collections state.
///
/// Follows the same ChangeNotifier pattern as [LikedMoviesProvider].
class CollectionsProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<CollectionSummary> _collections = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  CollectionsProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(client: null);

  // Getters
  List<CollectionSummary> get collections => _collections;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  // ── Fetch ────────────────────────────────────────────────

  /// Load all collections for the current user from API.
  Future<void> loadCollections() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/collections');
      if (response is List) {
        _collections = response
            .map((json) =>
                CollectionSummary.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('❌ Failed to load collections: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch full detail for a single collection.
  Future<CollectionDetail?> getCollectionDetail(String collectionId) async {
    try {
      final response = await _apiClient.get('/collections/$collectionId');
      if (response is Map<String, dynamic>) {
        return CollectionDetail.fromJson(response);
      }
    } catch (e) {
      debugPrint('❌ Failed to get collection detail: $e');
    }
    return null;
  }

  /// Get user's collections annotated with whether they contain [movieId].
  Future<List<CollectionSummary>> getCollectionsForMovie(int movieId) async {
    try {
      final response = await _apiClient.get('/collections/movie/$movieId');
      if (response is List) {
        return response
            .map((json) =>
                CollectionSummary.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Failed to get collections for movie: $e');
    }
    return [];
  }

  // ── Create / Update / Delete ─────────────────────────────

  /// Create a new collection and add it to the local list.
  Future<CollectionSummary?> createCollection({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    try {
      final response = await _apiClient.post('/collections', body: {
        'name': name,
        'description': description,
        'is_public': isPublic,
      });

      if (response is Map<String, dynamic>) {
        final newCol = CollectionSummary.fromJson(response);
        _collections.insert(0, newCol);
        notifyListeners();
        return newCol;
      }
    } catch (e) {
      debugPrint('❌ Failed to create collection: $e');
    }
    return null;
  }

  /// Update a collection's metadata.
  Future<bool> updateCollection(
    String collectionId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (isPublic != null) body['is_public'] = isPublic;

      await _apiClient.patch('/collections/$collectionId', body: body);

      // Optimistic local update
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx != -1) {
        final old = _collections[idx];
        _collections[idx] = CollectionSummary(
          id: old.id,
          userId: old.userId,
          name: name ?? old.name,
          description: description ?? old.description,
          isPublic: isPublic ?? old.isPublic,
          movieCount: old.movieCount,
          coverPosterPath: old.coverPosterPath,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update collection: $e');
      return false;
    }
  }

  /// Delete a collection.
  Future<bool> deleteCollection(String collectionId) async {
    try {
      await _apiClient.delete('/collections/$collectionId');

      // Optimistic local removal
      _collections.removeWhere((c) => c.id == collectionId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete collection: $e');
      return false;
    }
  }

  // ── Movie Management ────────────────────────────────────

  /// Add a movie to a collection.
  Future<bool> addMovieToCollection(String collectionId, int movieId) async {
    try {
      await _apiClient.post(
        '/collections/$collectionId/movies',
        body: {'movie_id': movieId},
      );

      // Optimistic: increment local count
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx != -1) {
        final old = _collections[idx];
        _collections[idx] = CollectionSummary(
          id: old.id,
          userId: old.userId,
          name: old.name,
          description: old.description,
          isPublic: old.isPublic,
          movieCount: old.movieCount + 1,
          coverPosterPath: old.coverPosterPath,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to add movie to collection: $e');
      return false;
    }
  }

  /// Remove a movie from a collection.
  Future<bool> removeMovieFromCollection(
      String collectionId, int movieId) async {
    try {
      await _apiClient.delete(
          '/collections/$collectionId/movies/$movieId');

      // Optimistic: decrement local count
      final idx = _collections.indexWhere((c) => c.id == collectionId);
      if (idx != -1) {
        final old = _collections[idx];
        _collections[idx] = CollectionSummary(
          id: old.id,
          userId: old.userId,
          name: old.name,
          description: old.description,
          isPublic: old.isPublic,
          movieCount: (old.movieCount - 1).clamp(0, 999999),
          coverPosterPath: old.coverPosterPath,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to remove movie from collection: $e');
      return false;
    }
  }

  /// Clear all data (e.g. on logout).
  void clear() {
    _collections = [];
    _isLoaded = false;
    notifyListeners();
  }
}
