import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/features/movies/domain/usecases/get_recommended_movies.dart';
import 'package:movieswipe/features/movies/domain/usecases/swipe_movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:movieswipe/features/movies/domain/usecases/search_movies.dart';

/// Movies BLoC
class MoviesBloc extends Bloc<MoviesEvent, MoviesState> {
  final GetRecommendedMovies getRecommendedMovies;
  final SwipeMovie swipeMovie;
  final SearchMovies searchMovies;

  MoviesBloc({
    required this.getRecommendedMovies,
    required this.swipeMovie,
    required this.searchMovies,
  }) : super(MoviesInitial()) {
    on<LoadMoviesEvent>(_onLoadMovies);
    on<SwipeMovieEvent>(_onSwipeMovie);
    on<SearchMoviesEvent>(_onSearchMovies);
  }

  /// Handle load movies event
  Future<void> _onLoadMovies(
    LoadMoviesEvent event,
    Emitter<MoviesState> emit,
  ) async {
    emit(MoviesLoading());

    final result = await getRecommendedMovies();

    result.fold(
      (failure) => emit(MoviesError(message: failure.message)),
      (movies) => emit(MoviesLoaded(movies: movies)),
    );
  }

  Future<void> _onSearchMovies(
    SearchMoviesEvent event,
    Emitter<MoviesState> emit,
  ) async {
    emit(MoviesLoading());

    final result = await searchMovies(event.query);

    result.fold(
      (failure) => emit(MoviesError(message: failure.message)),
      (movies) => emit(MoviesSearchLoaded(movies: movies)),
    );
  }

  Future<void> _onSwipeMovie(
    SwipeMovieEvent event,
    Emitter<MoviesState> emit,
  ) async {
    final result = await swipeMovie(
      movieId: event.movieId,
      isLike: event.isLike,
      userId: event.userId,
    );

    result.fold(
      (failure) {
        // Show error but don't change the movie list state
        print('❌ Swipe error: ${failure.message}');
        // Keep the current state (movies still visible)
        // The error will be logged but won't interrupt the user experience
      },
      (_) {
        // Swipe successful - keep current state
        print('✅ Swipe saved for movie ${event.movieId}');
      },
    );
  }
}
