import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';

/// My List page showing liked movies grouped by genre
class MyListPage extends StatelessWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LikedMoviesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ),
            ),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
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

        return _MyListContent(moviesByGenre: provider.moviesByGenre);
      },
    );
  }
}

/// Stateful content widget for genre filtering
class _MyListContent extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> moviesByGenre;

  const _MyListContent({required this.moviesByGenre});

  @override
  State<_MyListContent> createState() => _MyListContentState();
}

class _MyListContentState extends State<_MyListContent> {
  String? _selectedGenre;

  Map<String, List<Map<String, dynamic>>> get _filteredMovies {
    if (_selectedGenre == null) {
      return widget.moviesByGenre;
    }
    return {_selectedGenre!: widget.moviesByGenre[_selectedGenre] ?? []};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              backgroundColor: Colors.transparent,
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
            
            // Genre Filter Chips
            SliverToBoxAdapter(
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildGenreChip('All', null),
                    ...widget.moviesByGenre.keys.map((genre) => _buildGenreChip(genre, genre)),
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
                    final filteredMovies = _filteredMovies;
                    final genre = filteredMovies.keys.elementAt(index);
                    final movies = filteredMovies[genre]!;
                    
                    return _buildGenreSection(genre, movies);
                  },
                  childCount: _filteredMovies.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip(String label, String? genreValue) {
    final isSelected = _selectedGenre == genreValue;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGenre = genreValue;
          });
        },
        backgroundColor: Colors.white.withOpacity(0.9),
        selectedColor: Color(0xFFEC4899),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Color(0xFF6366F1),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 2,
        shadowColor: Colors.black.withOpacity(0.3),
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
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
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
                    ? Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.movie, size: 50, color: Colors.white),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1).withOpacity(0.3), Color(0xFFEC4899).withOpacity(0.3)],
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
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
            const SizedBox(height: 12),
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
    );
  }
}
