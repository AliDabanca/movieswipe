import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/providers/collections_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';

/// Full-screen page showing all movies inside a collection.
class CollectionDetailPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  CollectionDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final provider = context.read<CollectionsProvider>();
    final detail = await provider.getCollectionDetail(widget.collectionId);
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.collectionName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_detail != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_detail!.movieCount} film',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFEC4899)),
              tooltip: 'Film Ekle',
              onPressed: _showAddFromMyListSheet,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _detail == null
              ? _buildErrorState()
              : _detail!.movies.isEmpty
                  ? _buildEmptyState()
                  : _buildMovieList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            'Koleksiyon yüklenemedi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDetail();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            'Koleksiyon boş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Film detay sayfasından bu koleksiyona\nfilm ekleyebilirsin',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _detail!.movies.length,
      itemBuilder: (context, index) {
        final movie = _detail!.movies[index];
        return _buildMovieCard(movie);
      },
    );
  }

  Widget _buildMovieCard(CollectionMovie movie) {
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w300${movie.posterPath}'
        : null;

    return GestureDetector(
      onTap: () {
        final entity = Movie(
          id: movie.id,
          name: movie.name,
          genre: movie.genre,
          posterPath: movie.posterPath,
          voteAverage: movie.voteAverage,
          userRating: movie.userRating,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<MoviesBloc>(),
              child: MovieDetailPage(movie: entity),
            ),
          ),
        );
      },
      onLongPress: () => _showRemoveDialog(movie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1).withValues(alpha: 0.3),
                                const Color(0xFFEC4899).withValues(alpha: 0.3),
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
                        errorWidget: (_, e1, e2) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(Icons.movie, size: 32, color: Colors.white),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                          ),
                        ),
                        child: const Icon(Icons.movie, size: 32, color: Colors.white),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(CollectionMovie movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              movie.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              title: const Text(
                'Koleksiyondan Çıkar',
                style: TextStyle(color: Colors.redAccent),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final provider = context.read<CollectionsProvider>();
                final success = await provider.removeMovieFromCollection(
                  widget.collectionId,
                  movie.id,
                );
                if (success && mounted) {
                  // Reload the detail
                  _loadDetail();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${movie.name} koleksiyondan çıkarıldı'),
                      backgroundColor: const Color(0xFFEF5350),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFromMyListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddFromMyListSheet(
        collectionId: widget.collectionId,
        existingMovies: _detail?.movies ?? [],
        onMovieAdded: (movie) {
          // BottomSheet zaten listeye ekledi (reference pass olduğu için)
          // Burada sadece arkaplanın (parent) rebuild olması için setState diyoruz.
          setState(() {});
          _loadDetail(); // Opsiyonel: Backend ile senkronize etmek için
        },
      ),
    );
  }
}

class _AddFromMyListSheet extends StatefulWidget {
  final String collectionId;
  final List<CollectionMovie> existingMovies;
  final Function(CollectionMovie) onMovieAdded;

  const _AddFromMyListSheet({
    required this.collectionId,
    required this.existingMovies,
    required this.onMovieAdded,
  });

  @override
  State<_AddFromMyListSheet> createState() => _AddFromMyListSheetState();
}

class _AddFromMyListSheetState extends State<_AddFromMyListSheet> {
  String _searchQuery = '';
  String? _selectedGenre;
  
  // Arama metni gecikmesi için
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredMovies(Map<String, List<Map<String, dynamic>>> byGenre) {
    List<Map<String, dynamic>> allMovies = [];

    // Kategoriye göre filtrele
    if (_selectedGenre != null && byGenre.containsKey(_selectedGenre)) {
      allMovies = List.from(byGenre[_selectedGenre]!);
    } else {
      // Tüm kategorileri birleştir (mükerrerleri engellemek için id bazında set kullanabiliriz 
      // ama LikedMoviesProvider zaten filmleri primary genre'sinde tutuyor)
      allMovies = byGenre.values.expand((list) => list).toList();
    }

    // Arama metnine göre filtrele
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allMovies = allMovies.where((m) {
        final name = (m['name'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }

    return allMovies;
  }

  @override
  Widget build(BuildContext context) {
    final likedProvider = context.watch<LikedMoviesProvider>();
    final byGenre = likedProvider.moviesByGenre;
    final genres = byGenre.keys.toList()..sort();
    
    final filteredMovies = _getFilteredMovies(byGenre);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "My List'ten Film Ekle",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Film ara...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEC4899)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 12),
            
            // Genre Filter Chips
            if (genres.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildGenreChip('Tümü', isSelected: _selectedGenre == null, onTap: () {
                      setState(() => _selectedGenre = null);
                    }),
                    ...genres.map((g) => _buildGenreChip(g, isSelected: _selectedGenre == g, onTap: () {
                      setState(() => _selectedGenre = g);
                    })),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
            
            // List of Movies
            if (filteredMovies.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'Bu kategoride film yok' : 'Aramaya uygun film bulunamadı',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: filteredMovies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final movie = filteredMovies[index];
                    final movieId = movie['id'] as int;
                    final movieName = movie['name'] as String? ?? 'Bilinmeyen Film';
                    final moviePosterPath = movie['poster_path'] as String?;
                    final movieGenre = movie['genre'] as String? ?? 'General';
                    final userRating = movie['user_rating'] as int?;
                    final voteAverage = (movie['vote_average'] as num?)?.toDouble();

                    final isInCollection = widget.existingMovies.any((m) => m.id == movieId);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isInCollection ? 0.02 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isInCollection ? Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)) : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w200$moviePosterPath',
                            width: 45,
                            height: 65,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 45,
                              height: 65,
                              color: Colors.white12,
                              child: const Icon(Icons.movie, color: Colors.white54),
                            ),
                          ),
                        ),
                        title: Text(
                          movieName,
                          style: TextStyle(
                            color: isInCollection ? Colors.white70 : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          movieGenre,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                        ),
                        trailing: Icon(
                          isInCollection ? Icons.check_circle : Icons.add_circle_outline,
                          color: isInCollection ? const Color(0xFF4CAF50) : const Color(0xFFEC4899),
                        ),
                        onTap: isInCollection
                            ? null
                            : () async {
                                // 1. Optimistically mark in local list
                                setState(() {
                                  widget.existingMovies.insert(
                                    0, // Listenin en başına ekle
                                    CollectionMovie(
                                      id: movieId,
                                      name: movieName,
                                      genre: movieGenre,
                                      posterPath: moviePosterPath,
                                      userRating: userRating,
                                      voteAverage: voteAverage,
                                    ),
                                  );
                                });

                                // 2. Call backend
                                final provider = context.read<CollectionsProvider>();
                                await provider.addMovieToCollection(widget.collectionId, movieId);

                                // 3. Notify parent to update the background page
                                widget.onMovieAdded(
                                  CollectionMovie(
                                    id: movieId,
                                    name: movieName,
                                    genre: movieGenre,
                                    posterPath: moviePosterPath,
                                    userRating: userRating,
                                    voteAverage: voteAverage,
                                  ),
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$movieName eklendi!'),
                                      backgroundColor: const Color(0xFF4CAF50),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEC4899) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
