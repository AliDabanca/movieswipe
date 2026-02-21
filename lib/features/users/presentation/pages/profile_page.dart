import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';

/// Redesigned profile page — minimal with popup menu and genre badges
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Genre color mapping
  static const Map<String, Color> _genreColors = {
    'Action': Color(0xFFE53935),
    'Adventure': Color(0xFFFF8F00),
    'Animation': Color(0xFF8E24AA),
    'Comedy': Color(0xFFFDD835),
    'Crime': Color(0xFF546E7A),
    'Documentary': Color(0xFF43A047),
    'Drama': Color(0xFF1E88E5),
    'Family': Color(0xFFEC407A),
    'Fantasy': Color(0xFF7E57C2),
    'History': Color(0xFF8D6E63),
    'Horror': Color(0xFF212121),
    'Music': Color(0xFFD81B60),
    'Mystery': Color(0xFF5C6BC0),
    'Romance': Color(0xFFE91E63),
    'Science Fiction': Color(0xFF00ACC1),
    'Sci-Fi': Color(0xFF00ACC1),
    'Thriller': Color(0xFFFF6F00),
    'War': Color(0xFF6D4C41),
    'Western': Color(0xFFD4A056),
    'General': Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Consumer<LikedMoviesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final topGenres = provider.topGenres;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar with popup menu
                  _buildTopBar(context, auth),
                  // Profile content
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Avatar
                            _buildAvatar(auth),
                            const SizedBox(height: 20),
                            // Username
                            Text(
                              '@${auth.username ?? 'user'}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Email
                            Text(
                              auth.userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Favorite genres
                            if (topGenres.isNotEmpty)
                              _buildGenreBadges(topGenres),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white),
            ),
            color: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            itemBuilder: (context) => [
              _buildMenuItem(
                icon: Icons.bar_chart_rounded,
                label: 'İstatistiklerim',
                value: 'stats',
              ),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                label: 'Ayarlar',
                value: 'settings',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.logout,
                label: 'Çıkış Yap',
                value: 'logout',
                color: const Color(0xFFe94560),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'stats':
                  _showStatsSheet(context);
                  break;
                case 'settings':
                  // TODO: Settings page
                  break;
                case 'logout':
                  auth.signOut();
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AuthProvider auth) {
    final initial = (auth.username ?? 'U')[0].toUpperCase();
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFe94560), Color(0xFFc62d42)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFe94560).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreBadges(List<dynamic> topGenres) {
    return Column(
      children: [
        Text(
          'Favori Türler',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: topGenres.take(3).map((genre) {
            final name = genre[0] as String;
            final percentage = (genre[1] as num).toDouble();
            final color = _genreColors[name] ?? const Color(0xFF78909C);

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showStatsSheet(BuildContext context) {
    final provider = Provider.of<LikedMoviesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'İstatistiklerim',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Stats grid
              Row(
                children: [
                  _buildStatTile(
                    'Toplam Swipe',
                    provider.totalSwipes.toString(),
                    Icons.swipe,
                    const Color(0xFF42A5F5),
                  ),
                  const SizedBox(width: 12),
                  _buildStatTile(
                    'Beğeni Oranı',
                    '${(provider.likeRatio * 100).toStringAsFixed(0)}%',
                    Icons.percent,
                    const Color(0xFFAB47BC),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatTile(
                    'Beğeniler',
                    provider.totalLikes.toString(),
                    Icons.favorite,
                    const Color(0xFF66BB6A),
                  ),
                  const SizedBox(width: 12),
                  _buildStatTile(
                    'Geçilenler',
                    provider.totalPasses.toString(),
                    Icons.close,
                    const Color(0xFFEF5350),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
