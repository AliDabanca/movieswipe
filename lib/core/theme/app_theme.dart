import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CineSwipe Design System
///
/// Central theme configuration providing a cohesive, premium visual identity.
/// All colors, typography, and component styles are defined here.
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ───────────────────────────────────────────────────

  /// Deep midnight background — replaces generic black
  static const Color midnight = Color(0xFF0F111A);

  /// Card / elevated surface color
  static const Color surface = Color(0xFF1A1D2E);

  /// Slightly elevated surface for nested cards
  static const Color surfaceLight = Color(0xFF232740);

  /// Primary accent — electric purple
  static const Color accent = Color(0xFF8E5AF7);

  /// Secondary accent — sunset coral/orange
  static const Color secondary = Color(0xFFFF6B6B);

  /// Tertiary accent — cyan/teal for info states
  static const Color tertiary = Color(0xFF00D4AA);

  /// Legacy brand red (kept for backward compat)
  static const Color brandRed = Color(0xFFE94560);

  /// Success green
  static const Color success = Color(0xFF27AE60);

  /// Warning amber
  static const Color warning = Color(0xFFFFB800);

  /// Like action color — warm green
  static const Color likeGreen = Color(0xFF00E676);

  /// Pass action color — soft red
  static const Color passRed = Color(0xFFFF5252);

  // ─── Gradient Presets ───────────────────────────────────────────────

  /// Primary brand gradient (purple → coral)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle card shimmer gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Like button glow gradient
  static const LinearGradient likeGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Pass button glow gradient
  static const LinearGradient passGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFD50000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Border Radius Tokens ──────────────────────────────────────────

  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXL = 32.0;

  // ─── Typography ─────────────────────────────────────────────────────

  /// Build the app's text theme using the Outfit font family.
  static TextTheme get _textTheme {
    return GoogleFonts.outfitTextTheme(
      const TextTheme(
        // Display
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -1.5),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),

        // Headline
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),

        // Title
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),

        // Body
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),

        // Label
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }

  // ─── ThemeData ──────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: tertiary,
        surface: surface,
        onSurface: Colors.white,
        error: passRed,
        outline: Colors.white.withValues(alpha: 0.12),
      ),

      // Scaffold
      scaffoldBackgroundColor: midnight,

      // Typography
      textTheme: textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: accent.withValues(alpha: 0.12),
        labelStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Navigation Bar (Bottom)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accent, size: 24);
          }
          return IconThemeData(
            color: Colors.white.withValues(alpha: 0.5),
            size: 24,
          );
        }),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    );
  }
}
