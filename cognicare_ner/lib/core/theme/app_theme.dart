import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Elderly-first [ThemeData] and the hard layout constants every screen uses.
class AppTheme {
  AppTheme._();

  /// Minimum tap-target size (dp). Every interactive element must be >= this.
  static const double minTapTarget = 72;

  /// Standard screen / control padding (dp).
  static const double screenPadding = 20;

  /// Corner radius for buttons and cards (dp).
  static const double cardRadius = 16;

  /// Standard large icon size (dp).
  static const double iconSize = 40;

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.gentleWarning,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppText.textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.title(),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: screenPadding,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: AppText.button(),
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
