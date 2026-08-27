import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Large, highly-legible type scale for elderly users.
///
/// Font: Inter (weights 400 / 500 only). Atkinson Hyperlegible is the ideal
/// low-vision face, but Google Fonts ships it only at 400/700 — no 500 — so
/// Inter is used to honour the "regular(400)/medium(500) only" rule while
/// staying highly legible. Swap `GoogleFonts.inter` below for
/// `GoogleFonts.atkinsonHyperlegible` if 400/700 weights are acceptable.
class AppText {
  AppText._();

  static const double bodySize = 24;
  static const double buttonSize = 28;
  static const double titleSize = 34;
  static const double gameQuestionSize = 40;

  static TextStyle _style(double size, FontWeight weight, Color? color) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: 1.3,
      );

  static TextStyle body({Color? color}) =>
      _style(bodySize, FontWeight.w400, color);
  static TextStyle bodyMedium({Color? color}) =>
      _style(bodySize, FontWeight.w500, color);
  static TextStyle button({Color? color}) =>
      _style(buttonSize, FontWeight.w500, color);
  static TextStyle title({Color? color}) =>
      _style(titleSize, FontWeight.w500, color);
  static TextStyle gameQuestion({Color? color}) =>
      _style(gameQuestionSize, FontWeight.w500, color);

  /// Text theme wired into [ThemeData]. Sizes map to the elderly-first scale.
  static TextTheme textTheme() => TextTheme(
        headlineLarge: gameQuestion(),
        headlineMedium: gameQuestion(),
        titleLarge: title(),
        titleMedium: title(),
        labelLarge: button(),
        bodyLarge: body(),
        bodyMedium: body(),
      );
}
