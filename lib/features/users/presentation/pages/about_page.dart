import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:movieswipe/core/theme/app_theme.dart';

/// Premium "Hakkında" (About) page with app info and developer credits
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appVersion = '1.0.0';
  static const String _buildDate = 'Mayıs 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 220,
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
                  // Gradient background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A1A2E),
                          Color(0xFF16213E),
                          Color(0xFF0F3460),
                        ],
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Logo + App Name
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // App Logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                          ).createShader(bounds),
                          child: const Text(
                            'MovieSwipe',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$_appVersion',
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

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // App description
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.info_outline_rounded,
                                  color: AppTheme.accent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Uygulama Hakkında',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MovieSwipe, yapay zeka destekli kişiselleştirilmiş film keşif platformudur. '
                          'Swipe mekanizması ile filmleri beğenin veya geçin, '
                          'AI sizin film zevkinizi öğrensin ve mükemmel öneriler sunsun.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Developers section
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.code_rounded,
                                  color: Color(0xFF7C4DFF), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Geliştiriciler',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DeveloperTile(
                          name: 'Ali DABANCA',
                          role: 'Full-Stack Developer',
                          icon: Icons.person_rounded,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(height: 10),
                        _DeveloperTile(
                          name: 'Mustafa Onur BAYRAM',
                          role: 'Full-Stack Developer',
                          icon: Icons.person_rounded,
                          color: const Color(0xFF7C4DFF),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tech stack section
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.layers_rounded,
                                  color: Color(0xFF27AE60), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Teknoloji Stack',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _TechItem(label: 'Frontend', value: 'Flutter & Dart'),
                        _TechItem(label: 'Backend', value: 'Python FastAPI'),
                        _TechItem(label: 'Veritabanı', value: 'Supabase (PostgreSQL)'),
                        _TechItem(label: 'AI / ML', value: 'pgvector + Embeddings'),
                        _TechItem(label: 'Film Verisi', value: 'TMDB API'),
                        _TechItem(label: 'Mimari', value: 'Clean Architecture'),
                        _TechItem(label: 'State Yönetimi', value: 'BLoC + Provider'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Features section
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Color(0xFFF39C12), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Özellikler',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _FeatureItem(
                          icon: Icons.swipe_rounded,
                          text: 'Swipe ile Film Keşfi',
                          color: AppTheme.accent,
                        ),
                        _FeatureItem(
                          icon: Icons.auto_awesome,
                          text: 'AI Destekli Mood Tabanlı Öneriler',
                          color: const Color(0xFFE040FB),
                        ),
                        _FeatureItem(
                          icon: Icons.group_rounded,
                          text: 'Sosyal Özellikler & Arkadaş Sistemi',
                          color: const Color(0xFF7C4DFF),
                        ),
                        _FeatureItem(
                          icon: Icons.local_play_rounded,
                          text: 'Film DM & Paylaşım',
                          color: const Color(0xFF27AE60),
                        ),
                        _FeatureItem(
                          icon: Icons.collections_bookmark_rounded,
                          text: 'Kişisel Film Koleksiyonları',
                          color: const Color(0xFFF39C12),
                        ),
                        _FeatureItem(
                          icon: Icons.fingerprint_rounded,
                          text: 'Film DNA & Tür Analizi',
                          color: const Color(0xFF4361EE),
                        ),
                        _FeatureItem(
                          icon: Icons.local_fire_department_rounded,
                          text: 'Streak & Başarım Sistemi',
                          color: const Color(0xFFE74C3C),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Build info
                  _GlassCard(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Versiyon', value: _appVersion),
                        _InfoRow(label: 'Build Tarihi', value: _buildDate),
                        _InfoRow(label: 'Platform', value: 'Flutter ${_getPlatformName()}'),
                        _InfoRow(label: 'Proje Türü', value: 'Bitirme Projesi'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '❤️ ile yapıldı',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© 2026 MovieSwipe',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getPlatformName() {
    return 'Multi-Platform';
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  final String name;
  final String role;
  final IconData icon;
  final Color color;

  const _DeveloperTile({
    required this.name,
    required this.role,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechItem extends StatelessWidget {
  final String label;
  final String value;
  const _TechItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _FeatureItem({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
