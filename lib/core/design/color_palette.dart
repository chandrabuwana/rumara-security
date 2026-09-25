import 'package:flutter/material.dart';

/// A concrete color palette for one accent hue, exposing every semantic role.
///
/// This is the single source of truth for a palette. Screens should reference
/// the role getters (primary, surface, text, semantic colors) rather than raw
/// hexes so a palette switch re-colors the whole app.
class ColorPalette {
  const ColorPalette({
    required this.seed,
    required this.primary,
    required this.primaryDark,
    required this.primaryAccent,
    required this.neutral5,
    required this.neutral10,
    required this.neutral20,
    required this.neutral30,
    required this.neutral50,
    required this.neutral70,
    required this.neutral90,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.background,
    required this.backgroundDark,
    required this.surface,
    required this.surfaceDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.input,
    required this.tabbar,
  });

  /// Seed drives the Material3 tonal ramp via `ColorScheme.fromSeed`.
  final Color seed;

  final Color primary;
  final Color primaryDark;
  final Color primaryAccent;

  // Neutral ramp (mirrors existing colors.dart neutral5..90).
  final Color neutral5;
  final Color neutral10;
  final Color neutral20;
  final Color neutral30;
  final Color neutral50;
  final Color neutral70;
  final Color neutral90;

  // Semantic.
  final Color error;
  final Color success;
  final Color warning;
  final Color info;

  // Surfaces (light / dark variants).
  final Color background;
  final Color backgroundDark;
  final Color surface;
  final Color surfaceDark;

  // Text.
  final Color textPrimary;
  final Color textSecondary;

  // Fields + navigation.
  final Color input;
  final Color tabbar;
}
