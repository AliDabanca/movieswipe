import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
import 'package:movieswipe/core/di/injection_container.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';
import 'package:movieswipe/features/movies/domain/usecases/search_movies.dart';

class MovieSearchSelectSheet extends StatefulWidget {
  final Function(Movie movie) onSelect;

  const MovieSearchSelectSheet({
    super.key,
    required this.onSelect,
  });

  @override
  State<MovieSearchSelectSheet> createState() => _MovieSearchSelectSheetState();
}

class _MovieSearchSelectSheetState extends State<MovieSearchSelectSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    final searchMovies = sl<SearchMovies>();
    final result = await searchMovies(query);

    if (mounted) {
      result.fold(
        (failure) {
          setState(() {
            _searchError = 'Arama hatası: ${failure.message}';
            _isSearching = false;
          });
        },
        (movies) {
          setState(() {
            _searchResults = movies;
            _isSearching = false;
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final likedProvider = Provider.of<LikedMoviesProvider>(context);
    final likedMovies = likedProvider.recentlyAddedAll
        .map((m) => MovieModel.fromJson(m))
        .toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Film Seç Gönder',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _searchController,
                  onChanged: _performSearch,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Film ara...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Content Area
              Expanded(
                child: _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildLikedMoviesSection(likedMovies),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
        ),
      );
    }

    if (_searchError.isNotEmpty) {
      return Center(
        child: Text(
          _searchError,
          style: const TextStyle(color: AppTheme.secondary, fontSize: 14),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Aradığınız film bulunamadı.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        return _buildMovieTile(movie);
      },
    );
  }

  Widget _buildLikedMoviesSection(List<Movie> likedMovies) {
    if (likedMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz beğendiğiniz film yok.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Yukarıdaki arama çubuğundan arayabilirsiniz.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'BEĞENDİĞİN FİLMLER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.accent,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: likedMovies.length,
            itemBuilder: (context, index) {
              final movie = likedMovies[index];
              return _buildMovieTile(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieTile(Movie movie) {
    final posterUrl = movie.posterPath != null && movie.posterPath!.isNotEmpty
        ? (movie.posterPath!.startsWith('http')
            ? movie.posterPath!
            : 'https://image.tmdb.org/t/p/w200${movie.posterPath}')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          widget.onSelect(movie);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50,
                  height: 75,
                  color: Colors.white.withValues(alpha: 0.05),
                  child: posterUrl != null
                      ? Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.white24,
                            size: 20,
                          ),
                        )
                      : const Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.white24,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.genre,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    if (movie.releaseDate != null && movie.releaseDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.releaseDate!.split('-')[0],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
