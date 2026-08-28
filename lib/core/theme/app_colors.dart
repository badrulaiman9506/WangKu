import 'package:flutter/material.dart';

/// Every colour in the app, taken from the approved mockup.
///
/// Nothing outside this file writes a hex value. If a colour is needed
/// and it is not here, the design does not have it yet.
class AppColors {
  AppColors._();

  // Structure and text
  static const navy900 = Color(0xFF14203A);
  static const navy700 = Color(0xFF23324F);
  static const navy500 = Color(0xFF47587A);
  static const muted = Color(0xFF7A879F);

  // Action
  static const coral = Color(0xFFE2694A);
  static const coralPressed = Color(0xFFC7563A);
  static const coralSoft = Color(0xFFFBEAE4);

  // Surfaces
  static const sand = Color(0xFFF6F2ED);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFEAE3DB);
  static const lineStrong = Color(0xFFDCD3C8);
  static const track = Color(0xFFEFEAE3);

  // Status. Amber and rose appear only at the budget thresholds, so a
  // warning is never competing with decoration elsewhere in the UI.
  static const sage = Color(0xFF3F7D6A);
  static const sageSoft = Color(0xFFE7F1ED);
  static const amber = Color(0xFFC67E0C);
  static const amberSoft = Color(0xFFFCF0DC);
  static const rose = Color(0xFFC0433C);
  static const roseSoft = Color(0xFFFAE8E7);
}

/// Per-category colour pair. This is presentation, so it lives in Dart
/// keyed by the category slug rather than in the categories table.
class CategoryPalette {
  const CategoryPalette(this.foreground, this.background, this.icon);

  final Color foreground;
  final Color background;
  final IconData icon;

  static const _fallback = CategoryPalette(
    Color(0xFF7A879F),
    Color(0xFFEFF1F4),
    Icons.more_horiz,
  );

  static const Map<String, CategoryPalette> _bySlug = {
    'rent': CategoryPalette(
      Color(0xFF6C7FD8),
      Color(0xFFECEEFB),
      Icons.home_outlined,
    ),
    'wifi': CategoryPalette(
      Color(0xFF3F9AA6),
      Color(0xFFE6F4F5),
      Icons.wifi_rounded,
    ),
    'phone': CategoryPalette(
      Color(0xFF8A6BD1),
      Color(0xFFF0EAFB),
      Icons.smartphone_outlined,
    ),
    'subscriptions': CategoryPalette(
      Color(0xFFD8567F),
      Color(0xFFFBE9EF),
      Icons.autorenew_rounded,
    ),
    'transport': CategoryPalette(
      Color(0xFFC87A2E),
      Color(0xFFFAEEE1),
      Icons.directions_bus_outlined,
    ),
    'food': CategoryPalette(
      Color(0xFF4E9455),
      Color(0xFFE9F4EA),
      Icons.restaurant_outlined,
    ),
    'books': CategoryPalette(
      Color(0xFF2F7FBF),
      Color(0xFFE6F1FA),
      Icons.menu_book_outlined,
    ),
    'fines': CategoryPalette(
      Color(0xFFC0433C),
      Color(0xFFFAE8E7),
      Icons.error_outline_rounded,
    ),
    'other': _fallback,
  };

  /// Falls back to the neutral pair for a custom category added later,
  /// so an unknown slug renders correctly instead of throwing.
  static CategoryPalette of(String slug) => _bySlug[slug] ?? _fallback;
}
