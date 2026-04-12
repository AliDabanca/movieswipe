import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';

/// Smart AI Discovery — persistent full-screen mood questionnaire and results
class SmartDiscoveryPage extends StatefulWidget {
  const SmartDiscoveryPage({super.key});

  @override
  State<SmartDiscoveryPage> createState() => _SmartDiscoveryPageState();
}

class _SmartDiscoveryPageState extends State<SmartDiscoveryPage>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0,1,2 = questions, 3 = loading, 4 = results
  final List<String> _answers = [];
  List<MovieModel> _results = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final Set<int> _locallyLikedIds = {};

  static const _questions = [
    _Question(
      title: 'Ruh halin nasıl?',
      subtitle: 'Şu anki modunu en iyi tanımlayan seçeneği seç',
      icon: Icons.mood,
      options: [
        _Option(tag: 'happy', label: 'Neşelenmeye ihtiyacım var', emoji: '😃'),
        _Option(tag: 'dark', label: 'Biraz gerilmek istiyorum', emoji: '🌑'),
        _Option(tag: 'emotional', label: 'Duygusal bir bağ kurayım', emoji: '🥺'),
        _Option(tag: 'adrenaline', label: 'Adrenalin ve macera', emoji: '🔥'),
        _Option(tag: 'thoughtful', label: 'Düşüncelere dalmak', emoji: '🧠'),
        _Option(tag: 'chill', label: 'Kafamı boşaltacak bir şey', emoji: '🍿'),
      ],
    ),
    _Question(
      title: 'Nasıl bir tempo?',
      subtitle: 'Filmin akışı nasıl olsun?',
      icon: Icons.speed,
      options: [
        _Option(tag: 'fast', label: 'Hızlı, yerimde duramayayım', emoji: '⚡'),
        _Option(tag: 'calm', label: 'Sakin ve huzurlu', emoji: '🌿'),
        _Option(tag: 'twisty', label: 'Beyin yakan, ters köşeli', emoji: '🌀'),
        _Option(tag: 'visual', label: 'Görsel olarak büyüleyici', emoji: '✨'),
        _Option(tag: 'grounded', label: 'Gerçekçi, ayakları yerde', emoji: '🏢'),
      ],
    ),
    _Question(
      title: 'Ne tür bir dünya?',
      subtitle: 'Hangi atmosferde kaybolmak istersin?',
      icon: Icons.public,
      options: [
        _Option(tag: 'classic', label: 'Zamansız klasikler', emoji: '🎞️'),
        _Option(tag: 'modern', label: 'Modern ve güncel', emoji: '🆕'),
        _Option(tag: 'fantasy', label: 'Başka dünyalar, fantastik', emoji: '🚀'),
        _Option(tag: 'true_story', label: 'Gerçek hayattan hikayeler', emoji: '📖'),
        _Option(tag: 'cult', label: 'Kült ve sıra dışı', emoji: '🎭'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectAnswer(String tag) {
    _answers.add(tag);

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      setState(() => _currentStep = 3);
      _fetchResults();
    }
  }

  Future<void> _fetchResults() async {
    try {
      final datasource = MovieRemoteDataSourceImpl(apiClient: ApiClient());
      final movies = await datasource.getMoodRecommendations(_answers);
      if (mounted) {
        // Increment achievement counter
        Provider.of<LikedMoviesProvider>(context, listen: false).incrementSmartDiscovery();
        
        setState(() {
          _results = movies;
          _currentStep = 4;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentStep = 4);
      }
    }
  }

  Future<void> _toggleLikeMovie(MovieModel movie) async {
    final isCurrentlyLiked = _locallyLikedIds.contains(movie.id);
    final datasource = MovieRemoteDataSourceImpl(apiClient: ApiClient());
    final likedMoviesProvider = Provider.of<LikedMoviesProvider>(context, listen: false);

    if (isCurrentlyLiked) {
      // 💔 UNLIKE logic
      setState(() => _locallyLikedIds.remove(movie.id));
      likedMoviesProvider.removeLikedMovie(movie.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${movie.name} listeden çıkarıldı. 💔'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.withValues(alpha: 0.9),
        ),
      );

      try {
        await datasource.deleteSwipe(movie.id);
      } catch (e) {
        // Rollback on error
        if (mounted) {
          setState(() => _locallyLikedIds.add(movie.id));
          likedMoviesProvider.addLikedMovie(movie);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İşlem başarısız oldu, tekrar dene.')),
          );
        }
      }
    } else {
      // ❤️ LIKE logic
      setState(() => _locallyLikedIds.add(movie.id));
      likedMoviesProvider.addLikedMovie(movie);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${movie.name} listene eklendi! ❤️'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.9),
        ),
      );

      try {
        final userId = Provider.of<AuthProvider>(context, listen: false).currentUserId!;
        await datasource.swipeMovie(movie.id, true, userId);
      } catch (e) {
        // Rollback on error
        if (mounted) {
          setState(() => _locallyLikedIds.remove(movie.id));
          likedMoviesProvider.removeLikedMovie(movie.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İşlem başarısız oldu, tekrar dene.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                      ).createShader(bounds),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Akıllı Keşif',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_currentStep < 3)
                      Text(
                        '${_currentStep + 1}/3',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                  ],
                ),
              ),
              // Progress bar
              if (_currentStep < 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                      minHeight: 3,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _currentStep < 3
                      ? _buildQuestion(_questions[_currentStep])
                      : _currentStep == 3
                          ? _buildLoading()
                          : _buildResults(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(_Question question) {
    return Padding(
      key: ValueKey('q_$_currentStep'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(question.icon, color: const Color(0xFFE040FB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(question.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = question.options[index];
                return _OptionTile(
                  option: option,
                  onTap: () => _selectAnswer(option.tag),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                  ).createShader(bounds),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 80),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text('Yapay zeka senin için film arıyor...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Modun analiz ediliyor ✨', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Uygun film bulunamadı', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() { _currentStep = 0; _answers.clear(); }),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final movie = _results[index];
              return _MovieResultTile(
                movie: movie,
                index: index,
                isLiked: _locallyLikedIds.contains(movie.id),
                onLike: () => _toggleLikeMovie(movie),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovieDetailPage(movie: movie.toEntity()),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: OutlinedButton.icon(
            onPressed: () => setState(() { _currentStep = 0; _answers.clear(); }),
            icon: const Icon(Icons.refresh),
            label: const Text('Yeni Farklı Mod Dene'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE040FB),
              side: const BorderSide(color: Color(0xFFE040FB)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _Option option;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(child: Text(option.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieResultTile extends StatelessWidget {
  final MovieModel movie;
  final int index;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onTap;

  const _MovieResultTile({
    required this.movie,
    required this.index,
    required this.isLiked,
    required this.onLike,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)]),
                ),
                child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: movie.posterPath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w200${movie.posterPath}',
                        width: 50, height: 75, fit: BoxFit.cover,
                      )
                    : Container(width: 50, height: 75, color: Colors.grey.shade800, child: const Icon(Icons.movie, color: Colors.white38)),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 2),
                    const SizedBox(height: 4),
                    Text(movie.genre, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  ],
                ),
              ),
              // Actions: Like + Navigate
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.3),
                    ),
                    onPressed: onLike, // Always enabled for toggle
                  ),
                  Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_Option> options;
  const _Question({required this.title, required this.subtitle, required this.icon, required this.options});
}

class _Option {
  final String tag;
  final String label;
  final String emoji;
  const _Option({required this.tag, required this.label, required this.emoji});
}
