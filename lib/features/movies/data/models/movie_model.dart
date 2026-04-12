import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Movie model - Data transfer object
class MovieModel extends Movie {
  const MovieModel({
    required super.id,
    required super.name,
    required super.genre,
    super.posterPath,
    super.releaseDate,
    super.overview,
    super.voteAverage,
    super.userRating,
  });

  /// Create from JSON
  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as int,
      name: json['name'] as String,
      genre: json['genre'] as String? ?? 'General',
      posterPath: json['poster_path'] as String?,
      releaseDate: json['release_date'] as String?,
      overview: json['overview'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      userRating: json['user_rating'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'genre': genre,
      'poster_path': posterPath,
      'release_date': releaseDate,
      'overview': overview,
      'vote_average': voteAverage,
      'user_rating': userRating,
    };
  }

  /// Convert to entity
  Movie toEntity() {
    return Movie(
      id: id,
      name: name,
      genre: genre,
      posterPath: posterPath,
      releaseDate: releaseDate,
      overview: overview,
      voteAverage: voteAverage,
      userRating: userRating,
    );
  }
}

/// Detail model for the movie detail page
class MovieDetailModel extends MovieModel {
  final List<String> genres;
  final String? backdropPath;
  final String? overviewEn;
  final int? runtime;
  final String? tagline;
  final String? director;
  final List<String> cast;
  final List<CastMemberModel> castDetails;
  final int voteCount;
  final List<MovieModel> similarMovies;
  final Map<String, dynamic>? watchProviders;

  const MovieDetailModel({
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
    this.watchProviders,
  });

  /// Create from JSON
  factory MovieDetailModel.fromJson(Map<String, dynamic> json) {
    return MovieDetailModel(
      id: json['id'] as int,
      name: json['name'] as String,
      genre: json['genre'] as String? ?? 'General',
      posterPath: json['poster_path'] as String?,
      releaseDate: json['release_date'] as String?,
      overview: json['overview'] as String?,
      overviewEn: json['overview_en'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      userRating: json['user_rating'] as int?,
      voteCount: json['vote_count'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      backdropPath: json['backdrop_path'] as String?,
      runtime: json['runtime'] as int?,
      tagline: json['tagline'] as String?,
      director: json['director'] as String?,
      cast: (json['cast'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      castDetails: (json['cast_details'] as List<dynamic>?)
              ?.map((e) => CastMemberModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      similarMovies: (json['similar_movies'] as List<dynamic>?)
              ?.map((e) => MovieModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      watchProviders: json['watch_providers'] as Map<String, dynamic>?,
    );
  }

  /// Convert to domain entity
  MovieDetail toDetailEntity() {
    return MovieDetail(
      id: id,
      name: name,
      genre: genre,
      posterPath: posterPath,
      releaseDate: releaseDate,
      overview: overview,
      voteAverage: voteAverage,
      userRating: userRating,
      genres: genres,
      backdropPath: backdropPath,
      overviewEn: overviewEn,
      runtime: runtime,
      tagline: tagline,
      director: director,
      cast: cast,
      castDetails: castDetails
          .map((c) => CastMember(
                name: c.name,
                character: c.character,
                profilePath: c.profilePath,
              ))
          .toList(),
      voteCount: voteCount,
      similarMovies: similarMovies.map((m) => m.toEntity()).toList(),
    );
  }
}

/// Cast member model
class CastMemberModel {
  final String name;
  final String character;
  final String? profilePath;

  const CastMemberModel({
    required this.name,
    this.character = '',
    this.profilePath,
  });

  factory CastMemberModel.fromJson(Map<String, dynamic> json) {
    return CastMemberModel(
      name: json['name'] as String? ?? '',
      character: json['character'] as String? ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }
}
