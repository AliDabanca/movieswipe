import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/social_entities.dart';

/// Horizontal showcase of friend's highest-rated movies
class MovieShowcaseCard extends StatelessWidget {
  final List<ShowcaseMovieEntity> movies;
  final String title;

  const MovieShowcaseCard({
    super.key,
    required this.movies,
    this.title = 'En Beğendiği Filmler',
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD93D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFFFD93D), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _buildMovieTile(movie);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieTile(ShowcaseMovieEntity movie) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: movie.posterPath != null
                ? CachedNetworkImage(
                    imageUrl:
                        'https://image.tmdb.org/t/p/w200${movie.posterPath}',
                    height: 145,
                    width: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 145,
                      width: 100,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: Icon(Icons.movie, color: Colors.white24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 145,
                      width: 100,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.broken_image, color: Colors.white24),
                    ),
                  )
                : Container(
                    height: 145,
                    width: 100,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.movie, color: Colors.white24),
                  ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            movie.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          // Rating
          if (movie.userRating != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < movie.userRating! ? Icons.star : Icons.star_border,
                  size: 12,
                  color: const Color(0xFFFFD93D),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
