import 'package:flutter/material.dart';

import '../config/app_config.dart';
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
          onSurface: p.textPrimary,
          onSurfaceVariant: p.textSecondary,
  static ThemeData lightOf(ColorPalette p, {Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? p.seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: p.primary,
      onPrimary: Colors.white,
      error: p.error,
      surface: p.surface,
      onSurface: p.textPrimary,
      outline: p.neutral30,
      outlineVariant: p.neutral30,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: p.neutral30),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppConfig.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppConfig.fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.neutral30),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.neutral30,
          disabledForegroundColor: p.neutral20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: p.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textSecondary),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.error, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.neutral70,
        indicatorColor: p.primary,
      ),
      dividerTheme: DividerThemeData(color: p.neutral30, thickness: 1),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }

  static ThemeData darkOf(ColorPalette p, {Color? seed}) => ThemeData(
        useMaterial3: true,
        fontFamily: AppConfig.fontFamily,
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
