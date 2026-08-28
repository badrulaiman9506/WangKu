import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Four sizes, two families, and nothing else.
///
/// Fraunces carries amounts and screen titles. Inter carries every piece
/// of running text. Mixing more than this is what makes a student
/// project look assembled rather than designed.
class AppTypography {
  AppTypography._();

  /// The one number that matters on a screen. Tabular figures keep the
  /// decimal point from jumping as the amount changes.
  static TextStyle amountHero = GoogleFonts.fraunces(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -0.8,
    color: AppColors.navy900,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle amountMedium = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -0.3,
    color: AppColors.navy900,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle amountSmall = GoogleFonts.fraunces(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.navy900,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle screenTitle = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.navy900,
  );

  static TextStyle greeting = GoogleFonts.fraunces(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.navy900,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.navy900,
  );

  static TextStyle bodyRegular = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.navy500,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  /// Uppercase section label, e.g. SPENT THIS MONTH.
  static TextStyle label = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
    color: AppColors.muted,
  );

  static TextStyle button = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextTheme get textTheme => TextTheme(
        displayLarge: amountHero,
        headlineSmall: greeting,
        titleLarge: screenTitle,
        titleMedium: amountMedium,
        bodyLarge: body,
        bodyMedium: bodyRegular,
        bodySmall: caption,
        labelLarge: button,
        labelSmall: label,
      );
}
