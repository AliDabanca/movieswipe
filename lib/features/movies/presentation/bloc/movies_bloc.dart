import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/features/movies/domain/usecases/get_movies.dart';
import 'package:movieswipe/features/movies/domain/usecases/swipe_movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';

/// Movies BLoC
class MoviesBloc extends Bloc<MoviesEvent, MoviesState> {
  final GetMovies getMovies;
  final SwipeMovie swipeMovie;

  MoviesBloc({
    required this.getMovies,
    required this.swipeMovie,
  }) : super(MoviesInitial()) {
    on<LoadMoviesEvent>(_onLoadMovies);
    on<SwipeMovieEvent>(_onSwipeMovie);
  }

  /// Handle load movies event
  Future<void> _onLoadMovies(
    LoadMoviesEvent event,
    Emitter<MoviesState> emit,
  ) async {
    emit(MoviesLoading());

    final result = await getMovies();

    result.fold(
      (failure) => emit(MoviesError(message: failure.message)),
      (movies) => emit(MoviesLoaded(movies: movies)),
    );
  }

  /// Handle swipe movie event
  Future<void> _onSwipeMovie(
    SwipeMovieEvent event,
    Emitter<MoviesState> emit,
  ) async {
    final result = await swipeMovie(
      movieId: event.movieId,
      isLike: event.isLike,
    );

    result.fold(
      (failure) => emit(MoviesError(message: failure.message)),
      (_) => emit(MovieSwiped(movieId: event.movieId, isLike: event.isLike)),
    );
  }
}
