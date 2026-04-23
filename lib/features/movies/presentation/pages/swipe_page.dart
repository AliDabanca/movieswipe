import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:movieswipe/features/movies/presentation/widgets/movie_card.dart';
import 'package:movieswipe/features/movies/presentation/pages/smart_discovery_page.dart';


/// Swipe page - main movie swiping interface
class SwipePage extends StatefulWidget {
  const SwipePage({super.key});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  CardSwiperController controller = CardSwiperController();
  // Key to force-rebuild CardSwiper when new batch arrives
  int _swiperGeneration = 0;
  // Track the current batch's movie IDs to distinguish new batches from rating updates
  List<int> _currentBatchIds = [];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MoviesBloc, MoviesState>(
      listener: (context, state) {
        if (state is MoviesLoaded) {
          // Check if this is a genuinely new batch or just a rating update
          final newIds = state.movies.map((m) => m.id).toList();
                    final isSameBatch = listEquals(newIds, _currentBatchIds);

          if (!isSameBatch) {
            // New batch arrived — rebuild the swiper with a fresh controller
            setState(() {
              controller.dispose();
              controller = CardSwiperController();
              _swiperGeneration++;
              _currentBatchIds = newIds;
            });
          }
          // If same batch (e.g. rating update), do nothing — swiper keeps its position
        }
      },
      child: BlocBuilder<MoviesBloc, MoviesState>(
        builder: (context, state) {
          if (state is MoviesLoading || state is MoviesInitial) {
            return _buildLoadingSkeleton(context);
          } else if (state is MoviesRefreshing) {
            // Show existing cards while refreshing — no jarring loading screen
            return _buildSwipeCards(context, state.movies);
          } else if (state is MoviesEndOfContent) {
            return _buildEndOfContent(context, state.message);
          } else if (state is MoviesLoaded) {
            return _buildSwipeCards(context, state.movies);
          } else if (state is MoviesError) {
            return _buildError(context, state.message);
          }
          return _buildLoadingSkeleton(context);
        },
      ),
    );
  }

  /// Shimmer skeleton loading screen matching the card layout
  Widget _buildLoadingSkeleton(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _ShimmerCard(),
            ),
          ),
          // Ghost action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGhostButton(Colors.red.shade200),
                _buildGhostButton(Colors.grey.shade300),
                _buildGhostButton(Colors.green.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGhostButton(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.3),
      ),
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
                key: ValueKey(_swiperGeneration),
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
                  
                  // Get userId from AuthProvider
                  final userId = Provider.of<AuthProvider>(context, listen: false).currentUserId;
                  
                  if (userId == null) {
                    return true;
                  }

                  // Optimistic UI update - update local state immediately
                  final likedMoviesProvider = Provider.of<LikedMoviesProvider>(context, listen: false);
                  
                  // Crucial: Fetch the latest rating from provider in case it was updated in DetailPage
                  final currentRating = likedMoviesProvider.getMovieRating(movie.id) ?? movie.userRating;

                  if (isLike) {
                    // Use a movie copy with the most up-to-date rating
                    final movieWithRating = currentRating != null && currentRating != movie.userRating
                        ? movie.copyWith(userRating: currentRating)
                        : movie;
                    likedMoviesProvider.addLikedMovie(movieWithRating);
                  } else {
                    likedMoviesProvider.addPass();
                  }
                  
                  context.read<MoviesBloc>().add(
                        SwipeMovieEvent(
                          movieId: movie.id,
                          isLike: isLike,
                          userId: userId,
                          rating: currentRating,
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
                FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: () {
                    controller.undo();
                  },
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.refresh, size: 22),
                ),

                // Smart AI Discovery button
                FloatingActionButton.small(
                  heroTag: 'smart_discovery',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmartDiscoveryPage()),
                    );
                  },
                  backgroundColor: const Color(0xFF7C4DFF),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFE040FB), Colors.white],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
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

  /// End of content screen — movie pool exhausted
  Widget _buildEndOfContent(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                size: 80,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yeni filmler eklendiğinde bilgilendirileceksin!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                context.read<MoviesBloc>().add(LoadMoviesEvent());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
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

/// Animated shimmer card skeleton that matches the movie card layout
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Card(
          margin: EdgeInsets.zero,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Skeleton poster
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(_animation.value - 1, 0),
                        end: Alignment(_animation.value, 0),
                        colors: const [
                          Color(0xFFE0E0E0),
                          Color(0xFFF5F5F5),
                          Color(0xFFE0E0E0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.movie_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),

              // Skeleton info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title skeleton
                    Container(
                      width: 200,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment(_animation.value - 1, 0),
                          end: Alignment(_animation.value, 0),
                          colors: const [
                            Color(0xFFE0E0E0),
                            Color(0xFFF5F5F5),
                            Color(0xFFE0E0E0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Genre chip skeleton
                    Container(
                      width: 80,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment(_animation.value - 1, 0),
                          end: Alignment(_animation.value, 0),
                          colors: const [
                            Color(0xFFE0E0E0),
                            Color(0xFFF5F5F5),
                            Color(0xFFE0E0E0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Loading text
                    Center(
                      child: Text(
                        'Finding movies for you...',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
