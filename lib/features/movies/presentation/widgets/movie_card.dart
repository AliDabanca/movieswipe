import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';
import 'package:movieswipe/core/utils/genre_translator.dart';

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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed poster image
              _buildPosterImage(),

              // Bottom gradient vignette for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.45, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Recommendation reason badge (top-left)
              if (movie.recommendationReason != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildReasonBadge(),
                ),

              // IMDB-style rating badge (top-right)
              if (movie.voteAverage != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildRatingBadge(),
                ),

              // Bottom info panel (glass)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildInfoPanel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    if (movie.posterPath == null) {
      return Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.movie_rounded, size: 100, color: Colors.white24),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: '$tmdbImageBaseUrl${movie.posterPath}',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (context, url) => Container(
        color: AppTheme.surface,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.accent.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.movie_rounded, size: 100, color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildReasonBadge() {
    final code = movie.recommendationReason!['code'] as String? ?? '';
    final text = movie.recommendationReason!['text'] as String? ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: _reasonColor(code).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _reasonIcon(code),
                color: _reasonColor(code),
                size: 14,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  text,
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
    );
  }

  Widget _buildRatingBadge() {
    final rating = movie.voteAverage!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: AppTheme.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppTheme.warning),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Movie title
              Text(
                movie.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Genre chip + detail hint
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      GenreTranslator.translate(movie.genre),
                      style: TextStyle(
                        color: AppTheme.accent.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'Detay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        return AppTheme.accent;
      case 'exploration':
        return AppTheme.tertiary;
      case 'critics_choice':
        return AppTheme.warning;
      case 'cold_start':
        return const Color(0xFF42A5F5);
      default:
        return Colors.white70;
    }
  }
}
