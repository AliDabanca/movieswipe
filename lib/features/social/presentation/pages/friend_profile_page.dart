import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/social_bloc.dart';
import '../bloc/social_event.dart';
import '../bloc/social_state.dart';
import '../../domain/entities/social_entities.dart';
import '../widgets/compatibility_gauge.dart';
import '../widgets/movie_showcase_card.dart';

class FriendProfilePage extends StatefulWidget {
  final String friendId;

  const FriendProfilePage({super.key, required this.friendId});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<SocialBloc>().add(LoadFriendProfileEvent(widget.friendId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
          ),
          BlocBuilder<SocialBloc, SocialState>(
            buildWhen: (prev, current) =>
                current is FriendProfileLoaded ||
                current is SocialLoading ||
                current is SocialError,
            builder: (context, state) {
              if (state is SocialLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is SocialError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 16),
                      Text(state.message,
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }
              if (state is FriendProfileLoaded) {
                return _buildProfileContent(state.profile);
              }
              return const SizedBox();
            },
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(FriendProfileEntity profile) {
    final friend = profile.friend;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header area
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60),
            child: _buildHeader(friend),
          ),
        ),
        // Genre badges
        if (profile.topGenres.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildGenreBadges(profile.topGenres),
            ),
          ),
        // Compatibility
        if (profile.compatibility != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: CompatibilityGauge(
                score: profile.compatibility!.score,
                commonMovieCount: profile.compatibility!.commonMovieCount,
              ),
            ),
          ),
        // Showcase movies
        if (profile.showcaseMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: MovieShowcaseCard(movies: profile.showcaseMovies),
            ),
          ),
        // Common movies
        if (profile.compatibility != null &&
            profile.compatibility!.commonMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: MovieShowcaseCard(
                movies: profile.compatibility!.commonMovies,
                title: 'Ortak Beğeniler',
              ),
            ),
          ),
        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeader(FriendEntity friend) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          const Color(0xFFE94560).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    color: Colors.white.withValues(alpha: 0.05),
                    image: (friend.avatarUrl != null &&
                            friend.avatarUrl!.startsWith('http'))
                        ? DecorationImage(
                            image: NetworkImage(friend.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Center(
                    child: friend.avatarUrl == null
                        ? const Icon(Icons.person,
                            size: 36, color: Colors.white54)
                        : (!friend.avatarUrl!.startsWith('http')
                            ? Text(friend.avatarUrl!,
                                style: const TextStyle(fontSize: 36))
                            : null),
                  ),
                ),
                const SizedBox(width: 20),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName ?? friend.username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${friend.username}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreBadges(List<String> genres) {
    final genreEmojis = <String, String>{
      'Action': '🔥',
      'Comedy': '😄',
      'Drama': '🎭',
      'Horror': '😈',
      'Romance': '💕',
      'Science Fiction': '🚀',
      'Thriller': '😰',
      'Animation': '🎉',
      'Adventure': '⚔️',
      'Fantasy': '🧙',
      'Crime': '🔍',
      'Documentary': '📚',
      'Mystery': '🕵️',
      'Family': '👨‍👩‍👧‍👦',
      'War': '⚔️',
      'History': '📜',
      'Music': '🎵',
      'Western': '🤠',
    };

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
                      color:
                          const Color(0xFF4361EE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint_rounded,
                        color: Color(0xFF4361EE), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Film Zevki',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.map((genre) {
                  final emoji = genreEmojis[genre] ?? '🎬';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4361EE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF4361EE)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$emoji $genre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
