import 'package:equatable/equatable.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Movies state
abstract class MoviesState extends Equatable {
  const MoviesState();

  @override
  List<Object> get props => [];
}

/// Initial state
class MoviesInitial extends MoviesState {}

/// Loading state
class MoviesLoading extends MoviesState {}

/// Loaded state
class MoviesLoaded extends MoviesState {
  final List<Movie> movies;

  const MoviesLoaded({required this.movies});

  @override
  List<Object> get props => [movies];
}

/// Error state
class MoviesError extends MoviesState {
  final String message;

  const MoviesError({required this.message});

  @override
  List<Object> get props => [message];
}

/// Swipe success state
class MovieSwiped extends MoviesState {
  final int movieId;
  final bool isLike;

  const MovieSwiped({required this.movieId, required this.isLike});

  @override
  List<Object> get props => [movieId, isLike];
}
