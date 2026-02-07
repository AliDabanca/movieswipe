import 'package:equatable/equatable.dart';

/// Movie entity - Business logic representation
class Movie extends Equatable {
  final int id;
  final String name;
  final String genre;

  const Movie({
    required this.id,
    required this.name,
    required this.genre,
  });

  @override
  List<Object> get props => [id, name, genre];
}
