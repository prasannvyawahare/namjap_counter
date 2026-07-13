import 'package:flutter/material.dart';

/// Central Material 3 theme for the spiritual, saffron-forward look.
class AppTheme {
  AppTheme._();

  // Brand palette.
  static const Color saffron = Color(0xFFFF9800);
  static const Color deepOrange = Color(0xFFFF5722);
  static const Color darkBackground = Color(0xFF141B2D);
  static const Color darkSurface = Color(0xFF1E2740);
  static const Color darkCard = Color(0xFF232D4A);

  static const Color lightBackground = Color(0xFFFDF7F0);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: saffron,
      brightness: Brightness.dark,
    ).copyWith(
      primary: saffron,
      secondary: deepOrange,
      surface: darkSurface,
    );
    return _base(scheme, darkBackground, darkCard);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: saffron,
      brightness: Brightness.light,
    ).copyWith(
      primary: deepOrange,
      secondary: saffron,
      surface: lightSurface,
    );
    return _base(scheme, lightBackground, lightSurface);
  }

  static ThemeData _base(ColorScheme scheme, Color background, Color card) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : const Color(0xFF20242E),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF20242E),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: card,
        contentTextStyle:
            TextStyle(color: isDark ? Colors.white : Colors.black87),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Reusable gradient used behind hero numbers and buttons.
const kSaffronGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTheme.saffron, AppTheme.deepOrange],
);
