import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Movie model - Data transfer object
class MovieModel extends Movie {
  const MovieModel({
    required super.id,
    required super.name,
    required super.genre,
  });

  /// Create from JSON
  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as int,
      name: json['name'] as String,
      genre: json['genre'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'genre': genre,
    };
  }

  /// Convert to entity
  Movie toEntity() {
    return Movie(
      id: id,
      name: name,
      genre: genre,
    );
  }
}
