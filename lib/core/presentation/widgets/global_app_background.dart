import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/features/users/presentation/widgets/cover_selection_sheet.dart';

class GlobalAppBackground extends StatelessWidget {
  final Widget child;

  const GlobalAppBackground({super.key, required this.child});

  Widget _buildBlurSphere(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    // Determine gradient based on current coverPhotoUrl (which stores preset id)
    final presetId = auth.coverPhotoUrl ?? 'preset_default';
    final preset = coverPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => coverPresets.first,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Main gradient background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    preset.colors.first.withValues(alpha: 0.8),
                    const Color(0xFF0F0F1E),
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),
          
          // Blurred accent spheres to keep the premium "aura" feel
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlurSphere(preset.colors.first.withValues(alpha: 0.3), 300),
          ),
          Positioned(
            top: 200,
            left: -100,
            child: _buildBlurSphere(preset.colors.last.withValues(alpha: 0.2), 400),
          ),

          // The child content over the background
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
