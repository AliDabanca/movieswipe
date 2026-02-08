import 'package:equatable/equatable.dart';

/// Movie entity - Business logic representation
class Movie extends Equatable {
  final int id;
  final String name;
  final String genre;
  final String? posterPath;
  final String? releaseDate;

  const Movie({
    required this.id,
    required this.name,
    required this.genre,
    this.posterPath,
    this.releaseDate,
  });

  @override
  List<Object?> get props => [id, name, genre, posterPath, releaseDate];
}
