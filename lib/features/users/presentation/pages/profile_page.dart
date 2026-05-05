import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/features/users/presentation/widgets/avatar_selection_sheet.dart';
import 'package:movieswipe/features/users/presentation/widgets/genre_dna_chart.dart';
import 'package:movieswipe/features/users/presentation/widgets/current_mood_aura.dart';
import 'package:movieswipe/features/users/presentation/widgets/cover_selection_sheet.dart';
import 'package:movieswipe/features/social/presentation/pages/social_dashboard_page.dart';
import 'package:movieswipe/features/social/presentation/bloc/social_bloc.dart';
import 'package:movieswipe/features/social/presentation/bloc/social_event.dart';
import 'package:movieswipe/features/social/presentation/bloc/social_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _pendingRequestsCount = 0;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUserId != null) {
        context.read<SocialBloc>().add(LoadFriendCountEvent(auth.currentUserId!));
        context.read<SocialBloc>().add(LoadIncomingRequestsEvent());
        context.read<SocialBloc>().add(LoadNotificationsEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final likedProvider = Provider.of<LikedMoviesProvider>(context);

    if (likedProvider.isLoading && !likedProvider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return BlocListener<SocialBloc, SocialState>(
      listener: (context, state) {
        if (state is IncomingRequestsLoaded) {
          setState(() => _pendingRequestsCount = state.requests.length);
        } else if (state is NotificationsLoaded) {
          final unread = state.notifications.any((n) => !n.isRead);
          setState(() => _hasUnreadNotifications = unread);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
      endDrawer: _buildDrawer(context, auth, likedProvider),
      body: Stack(
        children: [

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Bar
                SliverToBoxAdapter(child: _buildTopBar(context)),

                // Profile Header Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildGlassHeader(context, auth, likedProvider),
                  ),
                ),

                // Mood Aura Section
                if (likedProvider.currentMood != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _buildMoodSection(likedProvider),
                    ),
                  ),

                // Movie DNA Section
                if (likedProvider.moviesByGenre.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildDnaSection(likedProvider),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ─── Drawer ──────────────────────────────────────────────────────────

  Widget _buildDrawer(
      BuildContext context, AuthProvider auth, LikedMoviesProvider liked) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E).withValues(alpha: 0.85),
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drawer Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menü',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 22),
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.white.withValues(alpha: 0.06)),

                // Scrollable Content area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        
                        // Notifications Section
                        if (_pendingRequestsCount > 0)
                          Column(
                            children: [
                              _buildDrawerItem(
                                icon: Icons.notifications_active_rounded,
                                label: 'Bekleyen İstekler ($_pendingRequestsCount)',
                                onTap: () {
                                  Navigator.pop(context); // Close drawer
                                  _showSocialDashboard(context, initialTab: 1); // Open social modal
                                },
                              ),
                              Divider(color: Colors.white.withValues(alpha: 0.06)),
                            ],
                          ),

                        // Stats - collapsible
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.bar_chart_rounded,
                                  color: Colors.white70, size: 20),
                            ),
                            title: const Text(
                              'İstatistikler',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(Icons.expand_more_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 20),
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 2),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              _buildDrawerStats(liked),
                            ],
                          ),
                        ),

                        Divider(color: Colors.white.withValues(alpha: 0.06)),

                        // Achievements - collapsible
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.emoji_events_rounded,
                                  color: Colors.white70, size: 20),
                            ),
                            title: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Başarımlar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE94560)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${liked.achievements.where((a) => a['isUnlocked'] == true).length}/${liked.achievements.length}',
                                    style: const TextStyle(
                                      color: Color(0xFFE94560),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.expand_more_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 20),
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 2),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              _buildDrawerAchievementsGrid(liked),
                            ],
                          ),
                        ),

                        Divider(color: Colors.white.withValues(alpha: 0.06)),

                        // Menu Items
                        const SizedBox(height: 4),

                        _buildDrawerItem(
                          icon: Icons.settings_rounded,
                          label: 'Ayarlar',
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to settings page
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Logout button stays at the bottom
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        auth.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Çıkış Yap'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE94560),
                        side: BorderSide(
                          color:
                              const Color(0xFFE94560).withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerStats(LikedMoviesProvider liked) {
    return Column(
      children: [
        _buildDrawerStatTile(
          icon: Icons.swipe_rounded,
          label: 'Toplam Swipe',
          value: liked.totalSwipes.toString(),
          color: const Color(0xFF4361EE),
        ),
        const SizedBox(height: 8),
        _buildDrawerStatTile(
          icon: Icons.favorite_rounded,
          label: 'Beğeni Oranı',
          value: '${(liked.likeRatio * 100).toInt()}%',
          color: const Color(0xFFE94560),
        ),
        const SizedBox(height: 8),
        _buildDrawerStatTile(
          icon: Icons.movie_rounded,
          label: 'Beğenilen Film',
          value: liked.totalLikes.toString(),
          color: const Color(0xFF27AE60),
        ),
      ],
    );
  }

  Widget _buildDrawerStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.3), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              if (_pendingRequestsCount > 0 || _hasUnreadNotifications)
                IconButton(
                  onPressed: () => _showSocialDashboard(context, initialTab: 2),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE94560).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Color(0xFFE94560), size: 20),
                  ),
                ),
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassHeader(
      BuildContext context, AuthProvider auth, LikedMoviesProvider liked) {
    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => _showAvatarSelection(context, auth),
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE94560).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        color: Colors.white.withValues(alpha: 0.05),
                        image: (auth.avatarUrl != null && auth.avatarUrl!.startsWith('http'))
                            ? DecorationImage(
                                image: NetworkImage(auth.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Center(
                        child: auth.avatarUrl == null
                            ? const Icon(Icons.person, size: 40, color: Colors.white54)
                            : (!auth.avatarUrl!.startsWith('http')
                                ? Text(auth.avatarUrl!, style: const TextStyle(fontSize: 40))
                                : null),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE94560),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showNameEditDialog(context, auth),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              auth.displayName ?? auth.username ?? 'Film Sever',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                    Text(
                      '@${auth.username ?? 'yeni_uye'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showSocialDashboard(context),
                      child: BlocBuilder<SocialBloc, SocialState>(
                        buildWhen: (prev, current) => current is FriendCountLoaded,
                        builder: (context, state) {
                          int count = 0;
                          if (state is FriendCountLoaded) {
                            count = state.count;
                          }
                          return Row(
                            children: [
                              Icon(Icons.group_rounded, size: 14, color: const Color(0xFFE94560).withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                '$count Arkadaş',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFE94560),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Notification dot for pending requests or unread notifications
                              if (_pendingRequestsCount > 0 || _hasUnreadNotifications)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE94560),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 14, color: const Color(0xFFE94560).withValues(alpha: 0.5)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Cover Edit Button
              IconButton(
                onPressed: () => _showCoverSelection(context, auth),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.brush_rounded,
                      color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // DNA Title Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE94560).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFE94560).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 14, color: Color(0xFFE94560)),
                const SizedBox(width: 8),
                Text(
                  liked.movieDnaTitle,
                  style: const TextStyle(
                    color: Color(0xFFE94560),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSocialDashboard(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<SocialBloc>(),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(child: SocialDashboardPage(initialTab: initialTab)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCoverSelection(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CoverSelectionSheet(
        currentPresetId: auth.coverPhotoUrl,
        onSelected: (presetId) {
          auth.updateProfile(coverPhotoUrl: presetId);
        },
      ),
    );
  }

  Widget _buildMoodSection(LikedMoviesProvider liked) {
    return _GlassCard(
      padding: EdgeInsets.zero, // The aura widget handles its own spacing
      child: CurrentMoodAura(
        currentMood: liked.currentMood,
        currentEmoji: liked.currentEmoji,
      ),
    );
  }

  Widget _buildDnaSection(LikedMoviesProvider liked) {
    // Build genre count data from moviesByGenre
    final genreData = <String, int>{};
    for (final entry in liked.moviesByGenre.entries) {
      genreData[entry.key] = entry.value.length;
    }

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4361EE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint_rounded,
                    color: Color(0xFF4361EE), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Film DNA\'n',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GenreDnaChart(genreData: genreData),
        ],
      ),
    );
  }

  Widget _buildDrawerAchievementsGrid(LikedMoviesProvider liked) {
    final allAchievements = liked.achievements;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final badge = allAchievements[index];
        final isUnlocked = badge['isUnlocked'] as bool;
        return GestureDetector(
          onTap: () => _showAchievementDetail(context, badge),
          child: _buildAchievementTile(badge, isUnlocked),
        );
      },
    );
  }

  Widget _buildAchievementTile(Map<String, dynamic> badge, bool isUnlocked) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked ? LinearGradient(
                colors: [
                  const Color(0xFFE94560).withValues(alpha: 0.2),
                  const Color(0xFFE94560).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: isUnlocked
                  ? null
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: isUnlocked
                    ? const Color(0xFFE94560).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE94560).withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isUnlocked
                  ? Text(
                      badge['icon'],
                      style: const TextStyle(fontSize: 28),
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: Text(
                        badge['icon'],
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge['title'],
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
              color: isUnlocked
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail(
      BuildContext context, Map<String, dynamic> badge) {
    final isUnlocked = badge['isUnlocked'] as bool;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge icon large
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? const Color(0xFFE94560).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFFE94560).withValues(alpha: 0.5)
                        : Colors.white12,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isUnlocked
                      ? Text(badge['icon'],
                          style: const TextStyle(fontSize: 40))
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: Text(badge['icon'],
                              style: const TextStyle(fontSize: 40)),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge['description'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF27AE60).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFF27AE60).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                      size: 14,
                      color: isUnlocked
                          ? const Color(0xFF27AE60)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUnlocked ? 'Kazanıldı' : 'Kilit Açma Şartı',
                      style: TextStyle(
                        color: isUnlocked
                            ? const Color(0xFF27AE60)
                            : Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNameEditDialog(BuildContext context, AuthProvider auth) {
    final controller = TextEditingController(text: auth.displayName ?? '');

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('İsim Güncelle',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Adını yaz...',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE94560))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                await auth.updateProfile(
                    displayName: controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kaydet',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarSelection(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AvatarSelectionSheet(),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
