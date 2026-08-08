import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

ThemeData buildPremiumTheme() {
  final titleFont = GoogleFonts.plusJakartaSans;
  final bodyFont = GoogleFonts.inter;

  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    tertiary: AppColors.accent,
    onTertiary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    error: AppColors.danger,
    outline: AppColors.glassBorder,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      foregroundColor: AppColors.text,
      titleTextStyle: titleFont(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: titleFont(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.text,
      ),
      titleLarge: titleFont(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      titleMedium: titleFont(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: bodyFont(fontSize: 16, color: AppColors.text, height: 1.45),
      bodyMedium: bodyFont(fontSize: 14, color: AppColors.textMuted, height: 1.45),
      bodySmall: bodyFont(fontSize: 12, color: AppColors.textMuted, height: 1.35),
      labelLarge: bodyFont(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: bodyFont(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primary,
      labelStyle: bodyFont(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: bodyFont(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.cardRouteNormal,
      checkmarkColor: AppColors.primary,
      side: const BorderSide(color: AppColors.glassBorder),
      labelStyle: bodyFont(fontSize: 13, color: AppColors.text),
    ),
  );
}
