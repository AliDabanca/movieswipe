import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium glass-morphism streak card that shows the user's
/// consecutive swipe days with animated fire effects.
class StreakCard extends StatefulWidget {
  final int currentStreak;
  final int bestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Dynamic fire color based on streak length
  Color get _streakColor {
    if (widget.currentStreak >= 30) return const Color(0xFFFF0000); // Red hot!
    if (widget.currentStreak >= 14) return const Color(0xFFFF4500); // Deep orange
    if (widget.currentStreak >= 7) return const Color(0xFFFF6B35);  // Orange
    if (widget.currentStreak >= 3) return const Color(0xFFFFAB00);  // Amber
    return const Color(0xFFFFD93D); // Warm yellow
  }

  String get _streakMessage {
    if (widget.currentStreak == 0) return 'Bugün henüz kaydırma yapmadın!';
    if (widget.currentStreak == 1) return 'İlk gün! Seriyi başlattın 💪';
    if (widget.currentStreak < 3) return 'Güzel başlangıç! Devam et!';
    if (widget.currentStreak < 7) return 'Harika gidiyorsun! 🔥';
    if (widget.currentStreak < 14) return 'Film maratonu! Muhteşem 🎬';
    if (widget.currentStreak < 30) return 'Efsanevi seri! Durdurulamaz 🏆';
    return 'Mutlak şampiyon! 👑';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentStreak > 0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? _streakColor.withValues(alpha: _glowAnimation.value * 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _streakColor.withValues(alpha: _glowAnimation.value * 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isActive
                      ? _streakColor.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    // Fire icon with pulse animation
                    _buildFireIcon(isActive),
                    const SizedBox(width: 16),

                    // Streak info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${widget.currentStreak}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isActive ? _streakColor : Colors.white.withValues(alpha: 0.3),
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'günlük seri',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _streakMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          if (widget.bestStreak > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events_rounded,
                                    size: 12,
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'En iyi: ${widget.bestStreak} gün',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFireIcon(bool isActive) {
    return Transform.scale(
      scale: isActive ? _pulseAnimation.value : 1.0,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive
              ? RadialGradient(
                  colors: [
                    _streakColor.withValues(alpha: 0.3),
                    _streakColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                )
              : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isActive
                ? _streakColor.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _streakColor.withValues(alpha: _glowAnimation.value * 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            isActive ? '🔥' : '❄️',
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}
