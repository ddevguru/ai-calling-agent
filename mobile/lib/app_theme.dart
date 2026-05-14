import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Muted slate palette — soft motion, no loud accents.
ThemeData buildAuraTheme() {
  const bg = Color(0xFF0F1419);
  const surface = Color(0xFF151C24);
  const surface2 = Color(0xFF1B2430);
  const outline = Color(0xFF2A3441);
  const text = Color(0xFFE6EAF0);
  const muted = Color(0xFF9AA4B2);
  const accent = Color(0xFF6B8A7A); // dusty sage

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: accent,
      onPrimary: Color(0xFF0F1419),
      secondary: Color(0xFF7D8C9A),
      onSurface: text,
      outline: outline,
    ),
    dividerColor: outline.withValues(alpha: 0.45),
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline.withValues(alpha: 0.55)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF0F1419),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: outline.withValues(alpha: 0.85)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
