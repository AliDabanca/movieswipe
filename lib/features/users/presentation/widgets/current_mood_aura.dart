import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// A minimalist, premium glowing aura widget that displays the user's current mood.
class CurrentMoodAura extends StatefulWidget {
  final String? currentMood;
  final String? currentEmoji;

  const CurrentMoodAura({
    super.key,
    this.currentMood,
    this.currentEmoji,
  });

  @override
  State<CurrentMoodAura> createState() => _CurrentMoodAuraState();
}

class _CurrentMoodAuraState extends State<CurrentMoodAura>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  // Local color mapping based on mood string
  Color _getMoodColor(String? mood) {
    if (mood == null) return const Color(0xFFE8A87C);

    switch (mood) {
      case 'Neşeli':
        return const Color(0xFFFFD93D);
      case 'Romantik':
        return const Color(0xFFFF6B8A);
      case 'Heyecanlı':
        return const Color(0xFFFF6B35);
      case 'Gerilimci':
        return const Color(0xFF8B5CF6);
      case 'Düşünceli':
        return const Color(0xFF4361EE);
      case 'Hayalperest':
        return const Color(0xFF06D6A0);
      case 'Eğlenceli':
        return const Color(0xFFFF9F1C);
      case 'Meraklı':
        return const Color(0xFF2EC4B6);
      case 'Karanlık':
        return const Color(0xFF6C757D);
      case 'Keşifçi':
      default:
        return const Color(0xFFE8A87C);
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_rotateController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMood = widget.currentMood != null && widget.currentMood!.isNotEmpty;
    final moodTitle = hasMood ? widget.currentMood! : 'Keşifçi';
    final moodEmoji = hasMood && widget.currentEmoji != null ? widget.currentEmoji! : '🎭';
    final glowColor = _getMoodColor(moodTitle);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Glowing Aura
          SizedBox(
            width: 140,
            height: 140,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Soft Glow Shell
                    Transform.scale(
                      scale: _pulseAnimation.value * 1.2,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: glowColor.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Rotating Gradient Core
                    Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                glowColor.withValues(alpha: 0.6),
                                glowColor.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Center Glass Container with Emoji
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              moodEmoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Mood Text
          Text(
            'Şu Anki Modun',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            moodTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: glowColor,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                )
              ],
            ),
          ),
          
          if (!hasMood) ...[
            const SizedBox(height: 8),
            Text(
              'Biraz daha film beğenerek ruh halini keşfet!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
