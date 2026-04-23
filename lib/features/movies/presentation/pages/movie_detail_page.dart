import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';

/// Premium movie detail page with hero poster, credits, and similar movies
class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  static const String tmdbImageBase = 'https://image.tmdb.org/t/p';
  static const String posterSize = '/w500';
  static const String backdropSize = '/w780';
  static const String profileSize = '/w185';

  MovieDetailModel? _detail;
  Map<String, dynamic>? _watchProvidersData;
  bool _isLoading = true;
  String? _error;
  int? _localRating;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    // Check LikedMoviesProvider for the most up-to-date rating first,
    // since widget.movie.userRating may be stale (e.g. from AI results list).
    final providerRating = Provider.of<LikedMoviesProvider>(context, listen: false)
        .getMovieRating(widget.movie.id);
    _localRating = providerRating ?? widget.movie.userRating;
  }

  Future<void> _loadDetails() async {
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final datasource = MovieRemoteDataSourceImpl(apiClient: apiClient);

      // Unified call: Watch providers now come embedded in movie details
      final detail = await datasource.getMovieDetails(widget.movie.id);

      if (mounted) {
        setState(() {
          _detail = detail;
          _watchProvidersData = detail.watchProviders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRating(int rating) async {
    final originalRating = _localRating;
    setState(() => _localRating = rating);

    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/movies/${widget.movie.id}/swipe',
        body: {'isLike': true, 'rating': rating},
      );
      
      if (mounted) {
        final likedProvider = context.read<LikedMoviesProvider>();
        // Pass a movie copy with the correct rating so it's stored correctly from the start
        final ratedMovie = widget.movie.copyWith(userRating: rating);
        likedProvider.addLikedMovie(ratedMovie);
        
        // MoviesBloc may not be available if we navigated from SmartDiscoveryPage
        try {
          context.read<MoviesBloc>().add(UpdateMovieRatingEvent(
            movieId: widget.movie.id,
            rating: rating,
          ));
        } catch (_) {
          // MoviesBloc not in widget tree — swipe page sync skipped, that's OK
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Puan güncellenemedi';
        if (e.toString().contains('401')) {
          errorMessage = 'Oturum süresi dolmuş, lütfen tekrar giriş yapın.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Sunucu hatası, lütfen daha sonra tekrar deneyin.';
        } else {
          errorMessage = 'Hata: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        setState(() => _localRating = originalRating);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFE50914)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Film detayları yüklenemedi',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadDetails();
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    return CustomScrollView(
      slivers: [
        // Hero Image + App Bar
        _buildSliverAppBar(d),
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildTitleRow(d),
                const SizedBox(height: 12),
                _buildMetadataChips(d),
                const SizedBox(height: 16),
                _buildStarRating(),
                if (d.tagline != null && d.tagline!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildTagline(d.tagline!),
                ],
                const SizedBox(height: 20),
                _buildOverview(d),
                const SizedBox(height: 24),
                _buildWatchProviders(),
                if (d.director != null) ...[
                  const SizedBox(height: 24),
                  _buildDirector(d.director!),
                ],
                if (d.castDetails.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildCastSection(d.castDetails),
                ],
              ],
            ),
          ),
        ),
        // Similar Movies - separate sliver so it can center properly
        if (d.similarMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSimilarMovies(d.similarMovies),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSliverAppBar(MovieDetailModel d) {
    final backdropUrl = d.backdropPath != null
        ? '$tmdbImageBase$backdropSize${d.backdropPath}'
        : d.posterPath != null
            ? '$tmdbImageBase$posterSize${d.posterPath}'
            : null;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFF0A0E21),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop Image
            if (backdropUrl != null)
              CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Icon(Icons.movie, size: 80, color: Colors.grey),
                ),
              )
            else
              Container(
                color: const Color(0xFF1A1A2E),
                child: const Icon(Icons.movie, size: 80, color: Colors.grey),
              ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC0A0E21),
                    Color(0xFF0A0E21),
                  ],
                  stops: [0.3, 0.75, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(MovieDetailModel d) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            d.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (d.voteAverage != null && d.voteAverage! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _ratingColor(d.voteAverage!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  d.voteAverage!.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _ratingColor(double rating) {
    if (rating >= 8.0) return const Color(0xFF27AE60);
    if (rating >= 6.5) return const Color(0xFFF39C12);
    if (rating >= 4.0) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }

  Widget _buildStarRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Senin Puanın',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isFilled = _localRating != null && starIndex <= _localRating!;
            
            return GestureDetector(
              onTap: () => _updateRating(starIndex),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('star_${starIndex}_${isFilled}_$_localRating'),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  // "Burst" effect: scales up and glows peak at 30% of animation, then settles
                  const peak = 0.3;
                  double scale;
                  double blur;
                  
                  if (!isFilled) {
                    scale = 1.0;
                    blur = 0.0;
                  } else {
                    if (value < peak) {
                      // Climb: 1.0 -> 1.5
                      scale = 1.0 + (value / peak) * 0.5;
                      blur = (value / peak) * 40.0;
                    } else {
                      // Settle: 1.5 -> 1.15
                      final settleValue = (value - peak) / (1.0 - peak);
                      scale = 1.5 - (settleValue * 0.35);
                      blur = 40.0 - (settleValue * 28.0);
                    }
                  }

                  return Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        color: isFilled ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.3),
                        size: 32,
                        shadows: isFilled ? [
                          Shadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                            blurRadius: blur,
                          ),
                          Shadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                            blurRadius: blur * 1.8,
                          ),
                        ] : null,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMetadataChips(MovieDetailModel d) {
    final items = <String>[];
    if (d.genres.isNotEmpty) {
      items.add(d.genres.take(2).join(' · '));
    } else {
      items.add(d.genre);
    }
    if (d.releaseDate != null && d.releaseDate!.length >= 4) {
      items.add(d.releaseDate!.substring(0, 4));
    }
    if (d.runtime != null && d.runtime! > 0) {
      final hours = d.runtime! ~/ 60;
      final mins = d.runtime! % 60;
      items.add(hours > 0 ? '${hours}h ${mins}m' : '${mins}m');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items
          .map((text) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTagline(String tagline) {
    return Text(
      '"$tagline"',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 15,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildOverview(MovieDetailModel d) {
    final overview = d.overview ?? d.overviewEn ?? '';
    if (overview.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          overview,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWatchProviders() {
    final providers = (_watchProvidersData?['providers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final tmdbLink = _watchProvidersData?['tmdb_link'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nereden İzleyebilirim?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tmdbLink != null && tmdbLink.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(tmdbLink);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: const Text(
                  'JustWatch',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (providers.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: providers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = providers[index];
                return _buildProviderChip(p);
              },
            ),
          )
        else
          Text(
            'Bu film için izleme bilgisi bulunamadı.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildProviderChip(Map<String, dynamic> provider) {
    final logoPath = provider['logo_path'];
    return Container(
      padding: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: logoPath != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w200$logoPath',
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, size: 20, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider['provider_name'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _getProviderTypeName(provider['provider_type']),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getProviderTypeName(String? type) {
    if (type == 'flatrate') return 'Abonelik';
    if (type == 'rent') return 'Kiralama';
    if (type == 'buy') return 'Satın Alma';
    return 'İzleme';
  }

  Widget _buildDirector(String director) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE50914).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.movie_creation_outlined,
            color: Color(0xFFE50914),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yönetmen',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            Text(
              director,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCastSection(List<CastMemberModel> castDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Oyuncular',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: castDetails.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final actor = castDetails[index];
              return _buildCastCard(actor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCastCard(CastMemberModel actor) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          // Profile image
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: actor.profilePath != null
                ? CachedNetworkImageProvider(
                    '$tmdbImageBase$profileSize${actor.profilePath}')
                : null,
            child: actor.profilePath == null
                ? Icon(Icons.person, color: Colors.white.withValues(alpha: 0.5))
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            actor.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (actor.character.isNotEmpty)
            Text(
              actor.character,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildSimilarMovies(List<MovieModel> movies) {
    return Column(
      children: [
        const SizedBox(height: 28),
        const Text(
          'Benzer Filmler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        movies.length > 4
            ? SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _buildSimilarMovieCard(movie);
                  },
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    movies.map((m) => _buildSimilarMovieCard(m)).toList(),
              ),
      ],
    );
  }

  Widget _buildSimilarMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        // MoviesBloc may not be available (e.g. from SmartDiscoveryPage)
        MoviesBloc? bloc;
        try {
          bloc = context.read<MoviesBloc>();
        } catch (_) {}

        Widget destination = MovieDetailPage(movie: movie.toEntity());
        if (bloc != null) {
          destination = BlocProvider.value(
            value: bloc,
            child: destination,
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: movie.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '$tmdbImageBase$posterSize${movie.posterPath}',
                      height: 150,
                      width: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 150,
                        width: 120,
                        color: Colors.grey[800],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 150,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.grey,
                          size: 36,
                        ),
                      ),
                    )
                  : Container(
                      height: 150,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.movie,
                        color: Colors.grey,
                        size: 36,
                      ),
                    ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                movie.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
