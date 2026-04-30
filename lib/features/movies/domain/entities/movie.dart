import 'package:equatable/equatable.dart';

/// Movie entity - Business logic representation
class Movie extends Equatable {
  final int id;
  final String name;
  final String genre;
  final String? posterPath;
  final String? releaseDate;
  final String? overview;
  final double? voteAverage;
  final int? userRating;
  /// Contextual recommendation metadata — not intrinsic movie data.
  /// Contains {"code": "genre_match", "text": "Senin Türün: Sci-Fi"}
  final Map<String, dynamic>? recommendationReason;

  const Movie({
    required this.id,
    required this.name,
    required this.genre,
    this.posterPath,
    this.releaseDate,
    this.overview,
    this.voteAverage,
    this.userRating,
    this.recommendationReason,
  });

  Movie copyWith({
    int? id,
    String? name,
    String? genre,
    String? posterPath,
    String? releaseDate,
    String? overview,
    double? voteAverage,
    int? userRating,
    Map<String, dynamic>? recommendationReason,
  }) {
    return Movie(
      id: id ?? this.id,
      name: name ?? this.name,
      genre: genre ?? this.genre,
      posterPath: posterPath ?? this.posterPath,
      releaseDate: releaseDate ?? this.releaseDate,
      overview: overview ?? this.overview,
      voteAverage: voteAverage ?? this.voteAverage,
      userRating: userRating ?? this.userRating,
      recommendationReason: recommendationReason ?? this.recommendationReason,
    );
  }

  @override
  List<Object?> get props => [id, name, genre, posterPath, releaseDate, overview, voteAverage, userRating, recommendationReason];
}

/// Extended movie entity for detail page
class MovieDetail extends Movie {
  final List<String> genres;
  final String? backdropPath;
  final String? overviewEn;
  final int? runtime;
  final String? tagline;
  final String? director;
  final List<String> cast;
  final List<CastMember> castDetails;
  final int voteCount;
  final List<Movie> similarMovies;

  const MovieDetail({
    required super.id,
    required super.name,
    required super.genre,
    super.posterPath,
    super.releaseDate,
    super.overview,
    super.voteAverage,
    super.userRating,
    this.genres = const [],
    this.backdropPath,
    this.overviewEn,
    this.runtime,
    this.tagline,
    this.director,
    this.cast = const [],
    this.castDetails = const [],
    this.voteCount = 0,
    this.similarMovies = const [],
  });

  /// Formatted runtime string (e.g., "2h 28m")
  String? get runtimeFormatted {
    if (runtime == null) return null;
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  @override
  List<Object?> get props => [
        ...super.props,
        genres,
        backdropPath,
        runtime,
        director,
        cast,
        similarMovies,
      ];
}

/// Cast member with character info
class CastMember extends Equatable {
  final String name;
  final String character;
  final String? profilePath;

  const CastMember({
    required this.name,
    this.character = '',
    this.profilePath,
  });

  @override
  List<Object?> get props => [name, character, profilePath];
}
