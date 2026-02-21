import 'package:flutter/material.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/data/models/movie_model.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:movieswipe/core/network/api_client.dart';

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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final apiClient = ApiClient();
      final datasource = MovieRemoteDataSourceImpl(apiClient: apiClient);

      final detail = await datasource.getMovieDetails(widget.movie.id);
      if (mounted) {
        setState(() {
          _detail = detail;
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
                if (d.tagline != null && d.tagline!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildTagline(d.tagline!),
                ],
                const SizedBox(height: 20),
                _buildOverview(d),
                if (d.director != null) ...[
                  const SizedBox(height: 24),
                  _buildDirector(d.director!),
                ],
                if (d.castDetails.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildCastSection(d.castDetails),
                ],
                if (d.similarMovies.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildSimilarMovies(d.similarMovies),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
              Image.network(
                backdropUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
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
            separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                ? NetworkImage('$tmdbImageBase$profileSize${actor.profilePath}')
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Benzer Filmler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildSimilarMovieCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailPage(movie: movie.toEntity()),
          ),
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
                  ? Image.network(
                      '$tmdbImageBase$posterSize${movie.posterPath}',
                      height: 150,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
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
