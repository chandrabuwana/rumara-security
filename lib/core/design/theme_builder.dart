import 'package:flutter/material.dart';

import 'color_palette.dart';
import 'theme_controller.dart';

/// Builds [ThemeData] (light and dark) from a [ColorPalette].
///
/// Replaces the inline `ThemeData(...)` block previously hardcoded in main.dart
/// (and the now-dead `appTheme`/`darkTheme` in styles.dart). The Material3
/// tonal ramp is derived from `palette.seed`, so switching the palette swaps the
/// whole chrome (appbar, buttons, nav, inputs, FAB, focused borders) instantly.
///
/// NOTE: kept pixel-faithful to the original main.dart theme — only
/// `useMaterial3` + `colorScheme` + `appBarTheme`. The older styles.dart
/// `appTheme`/`darkTheme` set `primarySwatch`/`platform`/`textTheme` but were
/// DEAD CODE (never referenced by main.dart), so they are intentionally dropped.
class ThemeBuilder {
  static ThemeData lightOf(ColorPalette p, {Color? seed}) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed ?? p.seed,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      );

  static ThemeData darkOf(ColorPalette p, {Color? seed}) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed ?? p.seed,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      );

  /// Resolve which ThemeData a [ThemeBrightness] mode should use at build time.
  static ThemeData resolve(ThemeBrightness mode, ColorPalette p,
      {Color? seed}) {
    switch (mode) {
      case ThemeBrightness.dark:
        return darkOf(p, seed: seed);
      case ThemeBrightness.light:
      case ThemeBrightness.system:
        // MaterialApp applies `themeMode: system` (light/dark auto) itself via
        // the `theme`/`darkTheme` + `themeMode` fields; `resolve` only needs a
        // deterministic default for callers.
        return lightOf(p, seed: seed);
    }
  }
}

/// Current light theme from the active controller.
ThemeData appThemeResolved() {
  final c = ThemeController.instance;
  return ThemeBuilder.resolve(c.brightness.value, c.currentPalette,
      seed: c.currentSeed);
}

/// Current dark theme from the active controller (for MaterialApp `darkTheme`).
ThemeData appThemeDarkResolved() {
  final c = ThemeController.instance;
  return ThemeBuilder.darkOf(c.currentPalette, seed: c.currentSeed);
}
