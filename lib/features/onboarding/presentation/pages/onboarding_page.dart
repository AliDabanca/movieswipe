import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/network/api_client.dart';

/// Onboarding page for new users — collects genre & movie preferences
/// to seed the recommendation engine with meaningful data.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1: Genre selection
  final Set<String> _selectedGenres = {};

  // Step 2: Movie selection
  final Set<int> _selectedMovieIds = {};
  List<Map<String, dynamic>> _moviePool = [];
  bool _isLoadingMovies = false;
  bool _isSaving = false;

  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/w342';

  // Genre data with emojis
  static const List<Map<String, String>> _genres = [
    {'name': 'Action', 'emoji': '💥', 'label': 'Aksiyon'},
    {'name': 'Comedy', 'emoji': '😂', 'label': 'Komedi'},
    {'name': 'Drama', 'emoji': '🎭', 'label': 'Dram'},
    {'name': 'Science Fiction', 'emoji': '🚀', 'label': 'Bilim Kurgu'},
    {'name': 'Horror', 'emoji': '👻', 'label': 'Korku'},
    {'name': 'Romance', 'emoji': '💕', 'label': 'Romantik'},
    {'name': 'Thriller', 'emoji': '🔪', 'label': 'Gerilim'},
    {'name': 'Animation', 'emoji': '🎬', 'label': 'Animasyon'},
    {'name': 'Fantasy', 'emoji': '🧙', 'label': 'Fantastik'},
    {'name': 'Adventure', 'emoji': '🗺️', 'label': 'Macera'},
    {'name': 'Crime', 'emoji': '🔍', 'label': 'Suç'},
    {'name': 'Documentary', 'emoji': '📚', 'label': 'Belgesel'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToMovieSelection() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 1);
    _loadMoviesForGenres();
  }

  Future<void> _loadMoviesForGenres() async {
    setState(() => _isLoadingMovies = true);
    try {
      final apiClient = ApiClient();
      // Use recommendations endpoint which returns popular/quality movies
      final response = await apiClient.get('/recommendations?limit=60');

      List<Map<String, dynamic>> movies = [];
      if (response is Map<String, dynamic>) {
        final moviesList = response['movies'] as List<dynamic>? ?? [];
        movies = moviesList.cast<Map<String, dynamic>>();
      }

      // Filter to selected genres and ensure they have posters
      final filtered = movies.where((m) {
        final genre = m['genre'] as String? ?? '';
        final posterPath = m['poster_path'] as String?;
        return _selectedGenres.contains(genre) && posterPath != null;
      }).toList();

      // If we don't have enough from selected genres, add high-rated ones
      if (filtered.length < 15) {
        final remaining = movies.where((m) {
          final posterPath = m['poster_path'] as String?;
          final id = m['id'] as int;
          return posterPath != null &&
              !filtered.any((f) => f['id'] == id);
        }).toList();
        filtered.addAll(remaining.take(20 - filtered.length));
      }

      setState(() {
        _moviePool = filtered;
        _isLoadingMovies = false;
      });
    } catch (e) {
      debugPrint('Failed to load movies for onboarding: $e');
      setState(() => _isLoadingMovies = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isSaving = true);

    try {
      final apiClient = ApiClient();

      // Save each selected movie as a "like" swipe
      for (final movieId in _selectedMovieIds) {
        try {
          await apiClient.post(
            '/movies/$movieId/swipe',
            body: {'isLike': true},
          );
        } catch (e) {
          debugPrint('Failed to save swipe for movie $movieId: $e');
        }
      }

      // Mark onboarding as completed
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false)
            .completeOnboarding();
      }
    } catch (e) {
      debugPrint('Onboarding completion error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1a3e),
                    Color(0xFF0F0F1E),
                    Color(0xFF0a0a1a),
                  ],
                ),
              ),
            ),
          ),
          // Decorative blur spheres
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFe94560).withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // Back button (only on page 2)
                      if (_currentPage == 1)
                        IconButton(
                          onPressed: () {
                            _pageController.animateToPage(0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut);
                            setState(() => _currentPage = 0);
                          },
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      // Step indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          '${_currentPage + 1} / 2',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildGenreSelection(),
                      _buildMovieSelection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Saving overlay
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFe94560)),
                      SizedBox(height: 16),
                      Text(
                        'Film zevklerin kaydediliyor...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── STEP 1: Genre Selection ──────────────────────────────

  Widget _buildGenreSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Hoş Geldin! 🎬',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sana en iyi filmleri önermemiz için en az 3 tür seç.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          // Selection counter
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              '${_selectedGenres.length} / 3 seçildi',
              key: ValueKey(_selectedGenres.length),
              style: TextStyle(
                color: _selectedGenres.length >= 3
                    ? const Color(0xFF00BFA5)
                    : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Genre grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _genres.length,
              itemBuilder: (context, index) {
                final genre = _genres[index];
                final isSelected = _selectedGenres.contains(genre['name']);
                return _buildGenreChip(genre, isSelected);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedOpacity(
              opacity: _selectedGenres.length >= 3 ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _selectedGenres.length >= 3 ? _goToMovieSelection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Devam →',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGenreChip(Map<String, String> genre, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedGenres.remove(genre['name']);
          } else {
            _selectedGenres.add(genre['name']!);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFe94560).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFe94560)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFe94560).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              genre['emoji']!,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              genre['label']!,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle, color: Color(0xFFe94560), size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: Movie Selection ──────────────────────────────

  Widget _buildMovieSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Favori Filmlerini Seç 🍿',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu filmleri beğenene dokunarak seç. En az 5 film seç.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          // Selection counter
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              '${_selectedMovieIds.length} / 5 seçildi',
              key: ValueKey(_selectedMovieIds.length),
              style: TextStyle(
                color: _selectedMovieIds.length >= 5
                    ? const Color(0xFF00BFA5)
                    : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Movie grid
          Expanded(
            child: _isLoadingMovies
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFe94560)),
                  )
                : _moviePool.isEmpty
                    ? Center(
                        child: Text(
                          'Film yüklenemedi. Lütfen tekrar dene.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _moviePool.length,
                        itemBuilder: (context, index) {
                          final movie = _moviePool[index];
                          final movieId = movie['id'] as int;
                          final isSelected = _selectedMovieIds.contains(movieId);
                          return _buildMoviePoster(movie, isSelected);
                        },
                      ),
          ),
          const SizedBox(height: 16),
          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedOpacity(
              opacity: _selectedMovieIds.length >= 5 ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _selectedMovieIds.length >= 5 && !_isSaving
                    ? _completeOnboarding
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Keşfetmeye Başla 🚀',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMoviePoster(Map<String, dynamic> movie, bool isSelected) {
    final posterPath = movie['poster_path'] as String?;
    final name = movie['name'] as String? ?? '';
    final movieId = movie['id'] as int;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedMovieIds.remove(movieId);
          } else {
            _selectedMovieIds.add(movieId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFe94560)
                : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFe94560).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 9 : 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '$_tmdbImageBase$posterPath',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF1a1a2e),
                        child: const Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1a1a2e),
                        child: Center(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1a1a2e),
                      child: Center(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
              // Selected overlay
              if (isSelected)
                Container(
                  color: const Color(0xFFe94560).withValues(alpha: 0.3),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              // Movie name at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
