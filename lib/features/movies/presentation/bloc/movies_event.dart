import 'package:equatable/equatable.dart';

/// Movies events
abstract class MoviesEvent extends Equatable {
  const MoviesEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load movies
class LoadMoviesEvent extends MoviesEvent {}

/// Event to swipe a movie
class SwipeMovieEvent extends MoviesEvent {
  final int movieId;
  final bool isLike;
  final String userId;
  final int? rating;

  const SwipeMovieEvent({
    required this.movieId,
    required this.isLike,
    required this.userId,
    this.rating,
  });

  @override
  List<Object?> get props => [movieId, isLike, userId, rating];
}

/// Event to search movies
class SearchMoviesEvent extends MoviesEvent {
  final String query;

  const SearchMoviesEvent(this.query);

  @override
  List<Object> get props => [query];
}

/// Event to update a movie's rating locally (for sync between pages)
class UpdateMovieRatingEvent extends MoviesEvent {
  final int movieId;
  final int rating;

  const UpdateMovieRatingEvent({
    required this.movieId,
    required this.rating,
  });

  @override
  List<Object?> get props => [movieId, rating];
}

/// Event to select a random movie
class GetRandomMovieEvent extends MoviesEvent {}
