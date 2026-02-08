import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/user_provider.dart';
import 'package:movieswipe/features/users/presentation/pages/user_selection_page.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:movieswipe/features/movies/presentation/widgets/movie_card.dart';
import 'package:movieswipe/core/di/injection_container.dart';

/// Swipe page - main movie swiping interface
class SwipePage extends StatefulWidget {
  const SwipePage({super.key});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  final CardSwiperController controller = CardSwiperController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MoviesBloc, MoviesState>(
      builder: (context, state) {
        if (state is MoviesLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is MoviesLoaded) {
          return _buildSwipeCards(context, state.movies);
        } else if (state is MoviesError) {
          return _buildError(context, state.message);
        }
        return const Center(child: Text('Swipe to discover movies!'));
      },
    );
  }

  Widget _buildSwipeCards(BuildContext context, List movies) {
    if (movies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No more movies!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Check back later for new movies'),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // Swipe cards
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CardSwiper(
                controller: controller,
                cardsCount: movies.length,
                cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                  return MovieCard(
                    movie: movies[index],
                    onSwipe: (isLike) {
                      // This won't be used with CardSwiper
                    },
                  );
                },
                onSwipe: (previousIndex, currentIndex, direction) {
                  final movie = movies[previousIndex];
                  final isLike = direction == CardSwiperDirection.right;
                  
                  // Get userId from UserProvider
                  final userId = Provider.of<UserProvider>(context, listen: false).currentUserId;
                  
                  if (userId == null) {
                    print ('❌ No user ID found!');
                    return true;
                  }
                  
                  context.read<MoviesBloc>().add(
                        SwipeMovieEvent(
                          movieId: movie.id,
                          isLike: isLike,
                          userId: userId,
                        ),
                      );
                  return true;
                },
                onEnd: () {
                  // Load more movies when deck is finished
                  context.read<MoviesBloc>().add(LoadMoviesEvent());
                },
                duration: const Duration(milliseconds: 300),
                maxAngle: 30,
                threshold: 50,
                scale: 0.9,
                isLoop: false,
                allowedSwipeDirection: const AllowedSwipeDirection.only(
                  left: true,
                  right: true,
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pass button
                FloatingActionButton(
                  heroTag: 'pass',
                  onPressed: () {
                    controller.swipe(CardSwiperDirection.left);
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.close, size: 32),
                ),

                // Undo button
                FloatingActionButton(
                  heroTag: 'undo',
                  onPressed: () {
                    controller.undo();
                  },
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.refresh, size: 28),
                ),

                // Like button
                FloatingActionButton(
                  heroTag: 'like',
                  onPressed: () {
                    controller.swipe(CardSwiperDirection.right);
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.favorite, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
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
