import 'package:flutter/material.dart';

/// Predefined premium gradient presets for the profile cover.
class CoverPreset {
  final String id;
  final String name;
  final List<Color> colors;

  const CoverPreset({
    required this.id,
    required this.name,
    required this.colors,
  });
}

final List<CoverPreset> coverPresets = [
  const CoverPreset(
    id: 'preset_default',
    name: 'Midnight',
    colors: [Color(0xFF0F0F1E), Color(0xFF1A1A2E)],
  ),
  const CoverPreset(
    id: 'preset_sunset',
    name: 'Neon Sunset',
    colors: [Color(0xFFE94560), Color(0xFF533483)],
  ),
  const CoverPreset(
    id: 'preset_ocean',
    name: 'Deep Ocean',
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  ),
  const CoverPreset(
    id: 'preset_cyber',
    name: 'Cyberpunk',
    colors: [Color(0xFF833ab4), Color(0xFFfd1d1d), Color(0xFFfcb045)],
  ),
  const CoverPreset(
    id: 'preset_aurora',
    name: 'Northern Lights',
    colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
  ),
  const CoverPreset(
    id: 'preset_lavender',
    name: 'Lavender Mist',
    colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
  ),
];

class CoverSelectionSheet extends StatelessWidget {
  final String? currentPresetId;
  final Function(String) onSelected;

  const CoverSelectionSheet({
    super.key,
    this.currentPresetId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kapak Stili Seç',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Profilin için premium bir görünüm seç.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          
          // Grid of Presets
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemCount: coverPresets.length,
            itemBuilder: (context, index) {
              final preset = coverPresets[index];
              final isSelected = currentPresetId == preset.id || 
                               (currentPresetId == null && preset.id == 'preset_default');
              
              return GestureDetector(
                onTap: () {
                  onSelected(preset.id);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: preset.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: preset.colors.first.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ] : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          preset.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
