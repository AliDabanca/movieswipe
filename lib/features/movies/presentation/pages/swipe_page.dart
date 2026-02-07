import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:movieswipe/features/movies/presentation/widgets/movie_card.dart';
import 'package:movieswipe/core/di/injection_container.dart';

/// Swipe page - main movie swiping interface
class SwipePage extends StatelessWidget {
  const SwipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MoviesBloc>()..add(LoadMoviesEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MovieSwipe'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: BlocBuilder<MoviesBloc, MoviesState>(
          builder: (context, state) {
            if (state is MoviesLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is MoviesLoaded) {
              return _buildMovieList(context, state.movies);
            } else if (state is MoviesError) {
              return _buildError(context, state.message);
            } else if (state is MovieSwiped) {
              // Reload movies after swipe
              context.read<MoviesBloc>().add(LoadMoviesEvent());
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text('Swipe to discover movies!'));
          },
        ),
      ),
    );
  }

  Widget _buildMovieList(BuildContext context, List movies) {
    if (movies.isEmpty) {
      return const Center(
        child: Text('No movies available'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        return MovieCard(
          movie: movies[index],
          onSwipe: (isLike) {
            context.read<MoviesBloc>().add(
                  SwipeMovieEvent(
                    movieId: movies[index].id,
                    isLike: isLike,
                  ),
                );
          },
        );
      },
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<MoviesBloc>().add(LoadMoviesEvent());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
