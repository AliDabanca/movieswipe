import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/presentation/widgets/logo_loader.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
import '../bloc/dm_bloc.dart';
import '../bloc/dm_event.dart';
import '../bloc/dm_state.dart';
import 'movie_dm_page.dart';

class MovieDmListPage extends StatefulWidget {
  const MovieDmListPage({super.key});

  @override
  State<MovieDmListPage> createState() => _MovieDmListPageState();
}

class _MovieDmListPageState extends State<MovieDmListPage> {
  @override
  void initState() {
    super.initState();
    // Load the DM list on start
    context.read<DmBloc>().add(LoadDmListEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.2),
              elevation: 0,
              title: const Text(
                'Film Tavsiyeleri',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: BlocBuilder<DmBloc, DmState>(
              builder: (context, state) {
                if (state is DmLoading) {
                  return const Center(child: LogoLoader(size: 80));
                }

                if (state is DmError) {
                  return _buildErrorState(
                    context,
                    state.message,
                    () => context.read<DmBloc>().add(LoadDmListEvent()),
                  );
                }

                if (state is DmListLoaded) {
                  final list = state.dmList;
                  if (list.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<DmBloc>().add(LoadDmListEvent());
                    },
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.surface,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _buildDmItemCard(context, item);
                      },
                    ),
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.local_play_outlined,
                size: 64,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Film Tavsiye Kutun Boş',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arkadaşlarına film tavsiye etmek için profillerine git veya onlardan tavsiye biletleri al!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.read<DmBloc>().add(LoadDmListEvent()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Listeyi Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, String message, VoidCallback onRetry) {
    String userMessage = 'İşlem sırasında bir hata oluştu.';
    String? technicalDetails;

    if (message.contains(':') ||
        message.contains('Exception') ||
        message.contains('Error') ||
        message.contains('\n')) {
      final parts = message.split('\n');
      userMessage = parts.first;
      technicalDetails = message;
    } else {
      userMessage = message;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (technicalDetails != null) ...[
              const SizedBox(height: 16),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: const ExpansionTileThemeData(
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                  ),
                ),
                child: ExpansionTile(
                  title: const Text(
                    'Hata Detayları',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  iconColor: Colors.white54,
                  collapsedIconColor: Colors.white54,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          technicalDetails,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: AppTheme.secondary.withValues(alpha: 0.3),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDmItemCard(BuildContext context, dynamic item) {
    final friend = item.friend;
    final lastShare = item.lastShare;
    final unreadCount = item.unreadCount;
    final shareStreak = item.shareStreak;

    // Determine subtitle
    String subtitle = 'Bir film tavsiyesi gönder!';
    bool isSender = false;
    if (lastShare != null) {
      isSender = lastShare.senderId != friend.id;
      final movieName = lastShare.movie?.name ?? 'Bir film';
      subtitle = isSender ? 'Sen gönderdin: 🎬 $movieName' : '🎬 $movieName';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unreadCount > 0
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                width: unreadCount > 0 ? 1.5 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<DmBloc>(),
                        child: MovieDmPage(friend: friend),
                      ),
                    ),
                  ).then((_) {
                    // Reload list on coming back to ensure unread counts are updated
                    context.read<DmBloc>().add(LoadDmListEvent());
                  });
                },
                leading: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unreadCount > 0
                          ? AppTheme.accent
                          : Colors.white.withValues(alpha: 0.1),
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
                        ? const Icon(Icons.person, size: 28, color: Colors.white54)
                        : (!friend.avatarUrl!.startsWith('http')
                            ? Text(friend.avatarUrl!,
                                style: const TextStyle(fontSize: 28))
                            : null),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        friend.displayName ?? friend.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shareStreak > 0) ...[
                      const SizedBox(width: 8),
                      // Neon glass streak badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🍿🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$shareStreak',
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: unreadCount > 0
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
