import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';

/// Movie card widget with swipe actions and tap-to-detail navigation
class MovieCard extends StatelessWidget {
  final Movie movie;
  final Function(bool) onSwipe;

  // TMDB image base URL
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  const MovieCard({
    super.key,
    required this.movie,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<MoviesBloc>(),
              child: MovieDetailPage(movie: movie),
            ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster Image with optional recommendation badge overlay
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  // Poster
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: movie.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: '$tmdbImageBaseUrl${movie.posterPath}',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF1a1a2e),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF1a1a2e),
                                child: const Icon(Icons.movie, size: 100, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1a1a2e),
                              child: const Center(
                                child: Icon(Icons.movie, size: 100, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                  // Recommendation reason badge (glassmorphism)
                  if (movie.recommendationReason != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _reasonIcon(movie.recommendationReason!['code'] as String? ?? ''),
                                  color: _reasonColor(movie.recommendationReason!['code'] as String? ?? ''),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    movie.recommendationReason!['text'] as String? ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Movie Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.name,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        label: Text(movie.genre),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      const SizedBox(width: 8),
                      if (movie.voteAverage != null)
                        Chip(
                          avatar: const Icon(Icons.star,
                              size: 16, color: Colors.amber),
                          label: Text(
                            movie.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '← Sola kaydır: Geç',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'Detay için dokun ℹ️',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Sağa kaydır: Beğen →',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Map recommendation reason codes to icons
  static IconData _reasonIcon(String code) {
    switch (code) {
      case 'genre_match':
        return Icons.favorite_rounded;
      case 'vector_match':
        return Icons.auto_awesome;
      case 'exploration':
        return Icons.explore_rounded;
      case 'critics_choice':
        return Icons.workspace_premium_rounded;
      case 'cold_start':
        return Icons.trending_up_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  /// Map recommendation reason codes to accent colors
  static Color _reasonColor(String code) {
    switch (code) {
      case 'genre_match':
        return const Color(0xFFE040FB);
      case 'vector_match':
        return const Color(0xFF7C4DFF);
      case 'exploration':
        return const Color(0xFF00BFA5);
      case 'critics_choice':
        return Colors.amber;
      case 'cold_start':
        return const Color(0xFF42A5F5);
      default:
        return Colors.white70;
    }
  }
}
