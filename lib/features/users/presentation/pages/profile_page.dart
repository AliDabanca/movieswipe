import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';

/// Profile page showing user stats and preferences
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LikedMoviesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final topGenres = provider.topGenres;
        final totalSwipes = provider.totalSwipes;
        final totalLikes = provider.totalLikes;
        final totalPasses = provider.totalPasses;
        final likeRatio = provider.likeRatio;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Icon(Icons.person, size: 80, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Profile',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Provider.of<AuthProvider>(context).userEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Stats Cards
                    _buildStatCard(
                      'Total Swipes',
                      totalSwipes.toString(),
                      Icons.swipe,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Likes',
                            totalLikes.toString(),
                            Icons.favorite,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Passes',
                            totalPasses.toString(),
                            Icons.close,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Like Ratio
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Like Ratio',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: likeRatio,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(likeRatio * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Top Genres
                    Text(
                      'Top Genres',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...topGenres.take(3).map((genre) {
                      final genreName = genre[0] as String;
                      final percentage = (genre[1] as num).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGenreBar(context, genreName, percentage),
                      );
                    }),
                    const SizedBox(height: 32),

                    // Sign Out
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Provider.of<AuthProvider>(context, listen: false).signOut();
                        },
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        label: const Text(
                          'Çıkış Yap',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreBar(BuildContext context, String genre, double percentage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  genre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
