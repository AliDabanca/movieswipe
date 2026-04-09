import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';
import 'package:movieswipe/features/movies/presentation/widgets/dice_roll_animation.dart';
import 'dart:math' as math;

/// My List page showing liked movies grouped by genre
class MyListPage extends StatelessWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LikedMoviesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (provider.moviesByGenre.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 100,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No liked movies yet!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start swiping to build your collection',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return _MyListContent();
      },
    );
  }
}

/// Stateful content widget for genre filtering
class _MyListContent extends StatefulWidget {
  const _MyListContent();

  @override
  State<_MyListContent> createState() => _MyListContentState();
}

class _MyListContentState extends State<_MyListContent> {
  String? _selectedGenre;
  String _searchQuery = '';
  bool _isCategoryOpen = false;
  bool _isRollingDice = false;
  Map<String, dynamic>? _selectedRandomMovie;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, dynamic>>> _getFilteredMovies(LikedMoviesProvider provider) {
    // Start with genre filter and apply active sort logic from provider
    Map<String, List<Map<String, dynamic>>> result = {};
    if (_selectedGenre == null) {
      for (final genre in provider.moviesByGenre.keys) {
        // Limit each genre row to max 10 items when viewing "All"
        result[genre] = provider.getSortedMoviesByGenre(genre).take(10).toList();
      }
    } else {
      result[_selectedGenre!] = provider.getSortedMoviesByGenre(_selectedGenre);
    }

    // Apply search filter on top
    if (_searchQuery.isEmpty) {
      return result;
    }

    final query = _searchQuery.toLowerCase();
    final filtered = <String, List<Map<String, dynamic>>>{};
    for (final entry in result.entries) {
      final matchingMovies = entry.value
          .where((m) => (m['name'] as String? ?? '').toLowerCase().contains(query))
          .toList();
      if (matchingMovies.isNotEmpty) {
        filtered[entry.key] = matchingMovies;
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LikedMoviesProvider>();
    final filteredMoviesMap = _getFilteredMovies(provider);

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  onPressed: () {
                    final provider = context.read<LikedMoviesProvider>();
                    final allMovies = <Map<String, dynamic>>[];
                    for (final movies in provider.moviesByGenre.values) {
                      allMovies.addAll(movies);
                    }

                    if (allMovies.isNotEmpty) {
                      final random = math.Random().nextInt(allMovies.length);
                      setState(() {
                        _selectedRandomMovie = allMovies[random];
                        _isRollingDice = true;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hiç beğenilen film bulunamadı!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.casino, color: Colors.amber, size: 28),
                  tooltip: 'Şansına bir film seç!',
                ),
                PopupMenuButton<SortCriteria>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  onSelected: (criteria) => provider.setSortCriteria(criteria),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: SortCriteria.recentlyAdded,
                      child: Text('En Son Eklenenler'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.highestRated,
                      child: Text('En Yüksek Puanlılar'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.alphabetical,
                      child: Text('A-Z'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.releaseDate,
                      child: Text('Çıkış Tarihi'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'My List',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search your movies...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            
            // Recently Added Band
            if (_selectedGenre == null && _searchQuery.isEmpty && provider.recentlyAddedAll.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildGenreSection(
                    'Son Eklenenler',
                    provider.recentlyAddedAll.take(10).toList(),
                  ),
                ),
              ),

            // Category Toggle Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    // Toggle Button — compact Netflix-style pill
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCategoryOpen = !_isCategoryOpen;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCategoryOpen
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedGenre ?? 'Categories',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _isCategoryOpen ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Expandable Genre Panel
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildGenreChip('All', null, provider),
                            ...provider.moviesByGenre.keys.map(
                              (genre) => _buildGenreChip(genre, genre, provider),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _isCategoryOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),
            ),
            
            // Movie List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final genre = filteredMoviesMap.keys.elementAt(index);
                    final movies = filteredMoviesMap[genre]!;
                    
                    return _buildGenreSection(genre, movies);
                  },
                  childCount: filteredMoviesMap.length,
                ),
              ),
            ),
          ],
        ),
    );

    return Stack(
      children: [
        scaffold,
        if (_isRollingDice && _selectedRandomMovie != null)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: DiceRollAnimation(
                onComplete: () {
                  final movie = _selectedRandomMovie!;
                  final movieEntity = Movie(
                    id: movie['id'],
                    name: movie['name'],
                    genre: movie['genre'] ?? 'General',
                    posterPath: movie['poster_path'],
                    voteAverage: (movie['vote_average'] as num?)?.toDouble(),
                    userRating: movie['user_rating'] as int?,
                  );

                  setState(() {
                    _isRollingDice = false;
                    _selectedRandomMovie = null;
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<MoviesBloc>(),
                        child: MovieDetailPage(movie: movieEntity),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenreChip(String label, String? genreValue, LikedMoviesProvider provider) {
    final isSelected = _selectedGenre == genreValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGenre = genreValue;
          _isCategoryOpen = false; // collapse after selection
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEC4899)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection(String genre, List<dynamic> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFEC4899).withOpacity(0.5),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                genre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${movies.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMovieCard(dynamic movie, int index) {
    final posterPath = movie['poster_path'] as String?;
    final movieName = movie['name'] as String;
    final posterUrl = posterPath != null 
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: Duration(milliseconds: 300 + (index * 50)),
      child: GestureDetector(
        onTap: () {
          final movieEntity = Movie(
            id: movie['id'],
            name: movie['name'],
            genre: movie['genre'] ?? 'General',
            posterPath: movie['poster_path'],
            voteAverage: (movie['vote_average'] as num?)?.toDouble(),
            userRating: movie['user_rating'] as int?,
          );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<MoviesBloc>(),
                  child: MovieDetailPage(movie: movieEntity),
                ),
              ),
            );
        },
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1).withValues(alpha: 0.3),
                                const Color(0xFFEC4899).withValues(alpha: 0.3)
                              ],
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.movie,
                              size: 50, color: Colors.white),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.movie, size: 50, color: Colors.white),
                      ),
              ),
            ),
            if (movie['user_rating'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < (movie['user_rating'] as int) ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFFD700),
                      size: 14,
                    );
                  }),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                movieName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
