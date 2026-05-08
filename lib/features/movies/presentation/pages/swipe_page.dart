import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:movieswipe/features/movies/presentation/widgets/movie_card.dart';
import 'package:movieswipe/features/movies/presentation/pages/smart_discovery_page.dart';
import 'package:movieswipe/core/presentation/widgets/logo_loader.dart';


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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGhostButton(AppTheme.passRed.withValues(alpha: 0.3)),
                _buildGhostButton(Colors.grey.withValues(alpha: 0.2)),
                _buildGhostButton(AppTheme.accent.withValues(alpha: 0.2)),
                _buildGhostButton(AppTheme.likeGreen.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGhostButton(Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildSwipeCards(BuildContext context, List movies) {
    if (movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.movie_outlined, size: 64,
                  color: AppTheme.accent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Film kalmadı!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni filmler için daha sonra tekrar gel',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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

          // Premium Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pass button
                _ActionButton(
                  onPressed: () => controller.swipe(CardSwiperDirection.left),
                  gradient: AppTheme.passGradient,
                  glowColor: AppTheme.passRed,
                  icon: Icons.close_rounded,
                  size: 60,
                  iconSize: 30,
                ),

                // Undo button
                _ActionButton(
                  onPressed: () => controller.undo(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A3F5C), Color(0xFF2A2E45)],
                  ),
                  glowColor: Colors.white24,
                  icon: Icons.refresh_rounded,
                  size: 46,
                  iconSize: 22,
                ),

                // Smart AI Discovery button
                _ActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmartDiscoveryPage()),
                    );
                  },
                  gradient: AppTheme.primaryGradient,
                  glowColor: AppTheme.accent,
                  icon: Icons.auto_awesome_rounded,
                  size: 46,
                  iconSize: 22,
                ),

                // Like button
                _ActionButton(
                  onPressed: () => controller.swipe(CardSwiperDirection.right),
                  gradient: AppTheme.likeGradient,
                  glowColor: AppTheme.likeGreen,
                  icon: Icons.favorite_rounded,
                  size: 60,
                  iconSize: 30,
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warning.withValues(alpha: 0.2),
                    AppTheme.warning.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                size: 64,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yeni filmler eklendiğinde bilgilendirileceksin!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<MoviesBloc>().add(LoadMoviesEvent());
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.passRed.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 56, color: AppTheme.passRed),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<MoviesBloc>().add(LoadMoviesEvent());
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

/// Premium action button with gradient background and glow effect
class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Gradient gradient;
  final Color glowColor;
  final IconData icon;
  final double size;
  final double iconSize;

  const _ActionButton({
    required this.onPressed,
    required this.gradient,
    required this.glowColor,
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
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
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            color: AppTheme.surface,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Shimmer effect
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(_animation.value - 1, 0),
                      end: Alignment(_animation.value, 0),
                      colors: [
                        AppTheme.surface,
                        AppTheme.surfaceLight,
                        AppTheme.surface,
                      ],
                    ),
                  ),
                ),
                // Center icon
                Center(
                  child: Icon(
                    Icons.movie_outlined,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                // Bottom shimmer info
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 180,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment(_animation.value - 1, 0),
                            end: Alignment(_animation.value, 0),
                            colors: [
                              Colors.white.withValues(alpha: 0.05),
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 80,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment(_animation.value - 1, 0),
                            end: Alignment(_animation.value, 0),
                            colors: [
                              Colors.white.withValues(alpha: 0.03),
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading text
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Senin için film arıyoruz...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Center LogoLoader
          const Center(
            child: LogoLoader(size: 80),
          ),
        ],
      ),
    );
      },
    );
  }
}
