import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Movie model - Data transfer object
class MovieModel extends Movie {
  const MovieModel({
    required super.id,
    required super.name,
    required super.genre,
    super.posterPath,
    super.releaseDate,
  });

  /// Create from JSON
  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as int,
      name: json['name'] as String,
      genre: json['genre'] as String? ?? 'General', // Handle optional genre
      posterPath: json['poster_path'] as String?,
      releaseDate: json['release_date'] as String?,
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
    );
  }
}
