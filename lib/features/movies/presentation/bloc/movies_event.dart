import 'package:equatable/equatable.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';

/// Movies events
abstract class MoviesEvent extends Equatable {
  const MoviesEvent();

  @override
  List<Object> get props => [];
}

/// Event to load movies
class LoadMoviesEvent extends MoviesEvent {}

/// Event to swipe a movie
class SwipeMovieEvent extends MoviesEvent {
  final int movieId;
  final bool isLike;

  const SwipeMovieEvent({required this.movieId, required this.isLike});

  @override
  List<Object> get props => [movieId, isLike];
}
