import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stitch / DESIGN.md renkleri.
abstract final class AppColors {
  static const background = Color(0xFFFCF9F8);
  static const surface = Color(0xFFFCF9F8);
  static const surfaceLow = Color(0xFFF6F3F2);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFF0EDED);
  static const onSurface = Color(0xFF1B1C1C);
  static const onSurfaceVariant = Color(0xFF414944);
  static const outline = Color(0xFF717974);
  static const outlineVariant = Color(0xFFC0C8C3);
  static const primary = Color(0xFF1F4E3D);
  static const primaryDeep = Color(0xFF023727);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF1F4E3D);
  static const secondary = Color(0xFF4C6455);
  static const secondaryContainer = Color(0xFFCBE6D4);
  static const sageSoft = Color(0xFFE8EDE8);
  static const sageNav = Color(0xFFD6E8DB);
  static const amber = Color(0xFFF0B429);
  static const amberSoft = Color(0xFFFDE4B4);
  static const amberBorder = Color(0xFFE8B86D);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const peachCta = Color(0xFFF9D9A2);
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
    );

    final textTheme = _textTheme(base);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryDeep,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDeep,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.hankenGrotesk(
          color: AppColors.outline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLowest,
        indicatorColor: AppColors.sageNav,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.outline,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.outline,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: GoogleFonts.montserrat(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.primaryDeep,
      ),
      headlineLarge: GoogleFonts.montserrat(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDeep,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDeep,
      ),
      headlineSmall: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDeep,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDeep,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.outline,
      ),
      labelLarge: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant,
      ),
      labelMedium: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.outline,
      ),
    );
  }
}
