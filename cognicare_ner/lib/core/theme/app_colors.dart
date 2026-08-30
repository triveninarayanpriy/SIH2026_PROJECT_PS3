import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Rich, warm brand colors
  static const Color primary = Color(0xFF1A73E8);      // Vibrant blue
  static const Color primaryDark = Color(0xFF0D47A1);   // Deep blue
  static const Color secondary = Color(0xFF00897B);     // Rich teal
  static const Color secondaryDark = Color(0xFF00695C); // Deep teal
  static const Color success = Color(0xFF43A047);       // Warm green
  static const Color gentleWarning = Color(0xFFEF6C00); // Warm orange (not red)

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);
  static const Color text = Color(0xFF1A1A2E);          // Rich near-black
  static const Color textMuted = Color(0xFF6B7280);     // Softer muted
  static const Color border = Color(0xFFE5E7EB);

  // Soft brand tints
  static const Color primarySoft = Color(0xFFE3F2FD);
  static const Color secondarySoft = Color(0xFFE0F2F1);
  static const Color successSoft = Color(0xFFE8F5E9);
  static const Color warningSoft = Color(0xFFFFF3E0);

  // Gradients
  static const List<Color> primaryGradient = [Color(0xFF1A73E8), Color(0xFF5C9CE6)];
  static const List<Color> secondaryGradient = [Color(0xFF00897B), Color(0xFF4DB6AC)];
  static const List<Color> successGradient = [Color(0xFF43A047), Color(0xFF81C784)];
  static const List<Color> warmGradient = [Color(0xFFFF8A65), Color(0xFFFFAB91)];
  static const List<Color> calmGradient = [Color(0xFFE3F2FD), Color(0xFFE0F2F1)];
  static const List<Color> sunsetGradient = [Color(0xFFFF6F61), Color(0xFFFFB74D)];

  // Role-specific accents
  static const Color patientAccent = Color(0xFF66BB6A);   // Warm green
  static const Color caregiverAccent = Color(0xFF42A5F5); // Bright blue
  static const Color doctorAccent = Color(0xFF26A69A);    // Teal

  // Game feedback
  static const Color correct = success;
  static const Color correctSurface = Color(0xFFE8F5E9);
  static const Color tryAgain = gentleWarning;
  static const Color tryAgainSurface = Color(0xFFFFF3E0);
  static const Color reward = Color(0xFFFFC107);    // Gold
  static const Color rewardSurface = Color(0xFFFFF8E1);

  // Shadows
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  static Color onColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? text : Colors.white;
}
