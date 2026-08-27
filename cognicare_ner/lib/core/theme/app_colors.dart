import 'package:flutter/material.dart';

/// Warm, calm, high-contrast palette for elderly / dementia users.
///
/// There is deliberately no harsh saturated red anywhere — warnings use a
/// gentle amber so nothing feels alarming.
class AppColors {
  AppColors._();

  // Base / brand.
  static const Color primary = Color(0xFF2E5AAC); // calm blue
  static const Color secondary = Color(0xFF0F6E56); // teal
  static const Color success = Color(0xFF1D9E75); // gentle green
  static const Color gentleWarning = Color(0xFFC0894B); // warm amber, never red

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF3F6FB);
  static const Color text = Color(0xFF1E2430); // near-black on light
  static const Color textMuted = Color(0xFF55607A); // secondary text (AA)
  static const Color border = Color(0xFFD5DEEC);

  // Soft brand tints (button/icon washes).
  static const Color primarySoft = Color(0xFFE7EEFA);
  static const Color secondarySoft = Color(0xFFE0EFE9);

  // Large-format semantic set — game feedback & rewards.
  static const Color correct = success; // green check
  static const Color correctSurface = Color(0xFFE3F5EE);
  static const Color tryAgain = gentleWarning; // kind amber
  static const Color tryAgainSurface = Color(0xFFF6ECDC);
  static const Color reward = Color(0xFFCB9A2E); // warm gold star
  static const Color rewardSurface = Color(0xFFF6EFD8);

  // Gentle, never-harsh shadow (~8% black).
  static const Color shadow = Color(0x14000000);

  /// A high-contrast on-color (white or near-black) for text/icons on [bg].
  static Color onColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? text : Colors.white;
}
