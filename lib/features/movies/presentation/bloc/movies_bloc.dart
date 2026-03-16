import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/errors/exceptions.dart';
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
    on<UpdateMovieRatingEvent>(_onUpdateMovieRating);
    on<GetRandomMovieEvent>(_onGetRandomMovie);
  }

  void _onUpdateMovieRating(
    UpdateMovieRatingEvent event,
    Emitter<MoviesState> emit,
  ) {
    if (state is MoviesLoaded) {
      final currentState = state as MoviesLoaded;
      final updatedMovies = currentState.movies.map((movie) {
        if (movie.id == event.movieId) {
          return movie.copyWith(userRating: event.rating);
        }
        return movie;
      }).toList();
      emit(MoviesLoaded(movies: updatedMovies));
    } else if (state is MoviesSearchLoaded) {
      final currentState = state as MoviesSearchLoaded;
      final updatedMovies = currentState.movies.map((movie) {
        if (movie.id == event.movieId) {
          return movie.copyWith(userRating: event.rating);
        }
        return movie;
      }).toList();
      emit(MoviesSearchLoaded(movies: updatedMovies));
    }
  }

  /// Handle load movies event
  Future<void> _onLoadMovies(
    LoadMoviesEvent event,
    Emitter<MoviesState> emit,
  ) async {
    emit(MoviesLoading());

    try {
      final result = await getRecommendedMovies();

      result.fold(
        (failure) => emit(MoviesError(message: failure.message)),
        (movies) => emit(MoviesLoaded(movies: movies)),
      );
    } on EndOfContentException catch (e) {
      emit(MoviesEndOfContent(message: e.message));
    }
  }

  Future<void> _onSwipeMovie(
    SwipeMovieEvent event,
    Emitter<MoviesState> emit,
  ) async {
    final result = await swipeMovie(
      movieId: event.movieId,
      isLike: event.isLike,
      userId: event.userId,
      rating: event.rating,
    );

    result.fold(
      (failure) {
        print('❌ Swipe error: ${failure.message}');
      },
      (_) {
        print('✅ Swipe saved for movie ${event.movieId}');
      },
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

  Future<void> _onGetRandomMovie(
    GetRandomMovieEvent event,
    Emitter<MoviesState> emit,
  ) async {
    if (state is MoviesLoaded) {
      final currentState = state as MoviesLoaded;
      if (currentState.movies.isNotEmpty) {
        final random = (DateTime.now().millisecond +
                DateTime.now().second * 1000) %
            currentState.movies.length;
        final selectedMovie = currentState.movies[random];
        emit(RandomMovieSelected(movie: selectedMovie));
        // Return to Loaded state immediately so subsequent picks work
        emit(currentState);
      }
    }
  }
}
