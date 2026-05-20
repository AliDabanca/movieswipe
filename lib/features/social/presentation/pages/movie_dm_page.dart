import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/presentation/widgets/logo_loader.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/core/theme/app_theme.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import '../../domain/entities/dm_entities.dart';
import '../../domain/entities/social_entities.dart';
import '../bloc/dm_bloc.dart';
import '../bloc/dm_event.dart';
import '../bloc/dm_state.dart';
import '../widgets/movie_search_select_sheet.dart';

class MovieDmPage extends StatefulWidget {
  final FriendEntity friend;

  const MovieDmPage({
    super.key,
    required this.friend,
  });

  @override
  State<MovieDmPage> createState() => _MovieDmPageState();
}

class _MovieDmPageState extends State<MovieDmPage> {
  final ScrollController _scrollController = ScrollController();
  String? _activeReactionShareId;

  @override
  void initState() {
    super.initState();
    // Load history
    context.read<DmBloc>().add(LoadDmHistoryEvent(widget.friend.id));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showMovieSearchSelect() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MovieSearchSelectSheet(
        onSelect: (Movie movie) {
          context.read<DmBloc>().add(ShareMovieEvent(
                receiverId: widget.friend.id,
                movieId: movie.id,
              ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId ?? '';

    return GestureDetector(
      onTap: () {
        if (_activeReactionShareId != null) {
          setState(() => _activeReactionShareId = null);
        }
      },
      child: Scaffold(
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
                title: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                        color: Colors.white.withValues(alpha: 0.05),
                        image: (widget.friend.avatarUrl != null &&
                                widget.friend.avatarUrl!.startsWith('http'))
                            ? DecorationImage(
                                image: NetworkImage(widget.friend.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Center(
                        child: widget.friend.avatarUrl == null
                            ? const Icon(Icons.person, size: 20, color: Colors.white54)
                            : (!widget.friend.avatarUrl!.startsWith('http')
                                ? Text(widget.friend.avatarUrl!,
                                    style: const TextStyle(fontSize: 20))
                                : null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.friend.displayName ?? widget.friend.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '@${widget.friend.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
            // Background ambient gradients
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.1),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: BlocConsumer<DmBloc, DmState>(
                      listener: (context, state) {
                        if (state is DmHistoryLoaded || state is DmShareSuccess) {
                          _scrollToBottom();
                        }
                      },
                      builder: (context, state) {
                        if (state is DmLoading && state is! DmHistoryLoaded) {
                          return const Center(child: LogoLoader(size: 80));
                        }

                        if (state is DmError) {
                          return _buildErrorState(
                            context,
                            state.message,
                            () => context
                                .read<DmBloc>()
                                .add(LoadDmHistoryEvent(widget.friend.id)),
                          );
                        }

                        List<MovieShareEntity> history = [];
                        if (state is DmHistoryLoaded) {
                          history = state.history;
                        } else if (state is DmShareSuccess) {
                          // While waiting for reload, if any
                        }

                        if (history.isEmpty) {
                          return _buildEmptyTimeline();
                        }

                        // Mark unread received shares as viewed
                        for (final share in history) {
                          if (share.receiverId == currentUserId && !share.isViewed) {
                            context.read<DmBloc>().add(MarkAsViewedEvent(
                                  shareId: share.id,
                                  friendId: widget.friend.id,
                                ));
                          }
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final share = history[index];
                            final isSentByMe = share.senderId == currentUserId;
                            return _buildTicketTimelineItem(share, isSentByMe);
                          },
                        );
                      },
                    ),
                  ),

                  // Floating Footer Bar with cinema vibe
                  _buildFooterAction(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTimeline() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.local_movies_outlined,
                size: 48,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'İlk Bileti Sen Gönder!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arkadaşınla film önerileri paylaşıp film streaklerinizi başlatın 🍿🔥',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketTimelineItem(MovieShareEntity share, bool isSentByMe) {
    final movie = share.movie;
    if (movie == null) return const SizedBox();

    final posterUrl = movie.posterPath != null && movie.posterPath!.isNotEmpty
        ? (movie.posterPath!.startsWith('http')
            ? movie.posterPath!
            : 'https://image.tmdb.org/t/p/w300${movie.posterPath}')
        : null;

    final hasReaction = share.reaction != null && share.reaction!.isNotEmpty;
    final isReactionPanelOpen = _activeReactionShareId == share.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: Column(
            crossAxisAlignment:
                isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Hover Reaction Panel
              if (isReactionPanelOpen) ...[
                _buildReactionPanel(share),
                const SizedBox(height: 6),
              ],

              // Glassmorphic Cinema Ticket
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_activeReactionShareId == share.id) {
                      _activeReactionShareId = null;
                    } else {
                      _activeReactionShareId = share.id;
                    }
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isSentByMe
                                ? AppTheme.accent.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSentByMe
                                  ? AppTheme.accent.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSentByMe
                                    ? AppTheme.accent.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Ticket Top half (Movie Info & Poster)
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Movie Poster
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 70,
                                          height: 105,
                                          color: Colors.white.withValues(alpha: 0.05),
                                          child: posterUrl != null
                                              ? Image.network(
                                                  posterUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.image_not_supported_rounded,
                                                    color: Colors.white24,
                                                    size: 24,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.image_not_supported_rounded,
                                                  color: Colors.white24,
                                                  size: 24,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ADMİT ONE • FİLM BİLETİ',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.secondary,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              movie.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              movie.genre,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (movie.voteAverage != null) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded,
                                                      size: 14,
                                                      color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    movie.voteAverage!
                                                        .toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Ticket perforation dotted divider
                                _buildDottedDivider(),

                                // Ticket Bottom half (Barcode & Date)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Column(
                                    children: [
                                      _buildBarcode(),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'SEAT: L-KUTUSU',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(share.createdAt),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Reaction Floating Badge
                    if (hasReaction)
                      Positioned(
                        bottom: -10,
                        right: isSentByMe ? null : -10,
                        left: isSentByMe ? -10 : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            share.reaction!,
                            style: const TextStyle(fontSize: 16),
                          ),
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

  Widget _buildReactionPanel(MovieShareEntity share) {
    final emojis = ['❤️', '🍿', '🔥', '👍'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          final isSelected = share.reaction == emoji;
          return GestureDetector(
            onTap: () {
              context.read<DmBloc>().add(UpdateReactionEvent(
                    shareId: share.id,
                    reaction: isSelected ? null : emoji,
                    friendId: widget.friend.id,
                  ));
              setState(() => _activeReactionShareId = null);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedScale(
                scale: isSelected ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Row(
      children: List.generate(30, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 1,
            color: index % 2 == 0
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
        );
      }),
    );
  }

  Widget _buildBarcode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(24, (index) {
        final widths = [
          1, 2, 3, 1, 4, 2, 1, 3, 2, 1, 2, 4, 1, 3, 1, 2, 1, 4, 2, 1, 3, 2, 1, 2
        ];
        final isLine = index % 2 == 0;
        return Container(
          width: widths[index % widths.length].toDouble(),
          height: 24,
          color: isLine ? Colors.white.withValues(alpha: 0.3) : Colors.transparent,
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    // Return standard visual short date format
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute';
  }

  Widget _buildFooterAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _showMovieSearchSelect,
              icon: const Icon(Icons.local_play_rounded, size: 20),
              label: const Text(
                'BİLET GÖNDER',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
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
}
