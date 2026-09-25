import 'package:flutter/material.dart';

import 'color_palette.dart';

/// Predefined accents. Default is `guardify` — identical to the current brand
/// (red/crimson), so enabling the palette engine changes nothing out of the box.
enum Palettes { guardify, ocean, forest, amber }

typedef PalettesPalette = ColorPalette;

/// Registry of every built-in [ColorPalette].
///
/// Neutral ramp, text tones and surfaces are shared across palettes; the brand
/// hue (primary/seed) is what distinguishes one accent from another.
class PaletteRegistry {
  static ColorPalette of(Palettes p) {
    switch (p) {
      case Palettes.ocean:
        return _ocean;
      case Palettes.forest:
        return _forest;
      case Palettes.amber:
        return _amber;
      case Palettes.guardify:
        return _guardify;
    }
  }

  static List<Palettes> get all => const [
        Palettes.guardify,
        Palettes.ocean,
        Palettes.forest,
        Palettes.amber,
      ];

  static String label(Palettes p) {
    switch (p) {
      case Palettes.ocean:
        return 'Ocean';
      case Palettes.forest:
        return 'Forest';
      case Palettes.amber:
        return 'Amber';
      case Palettes.guardify:
        return 'Guardify';
    }
  }

  // ---------------------------------------------------------------------------
  // Neutral / surface / text tokens shared by every palette. Mirrors the
  // existing colors.dart values so removing the engine is a no-op.
  // ---------------------------------------------------------------------------
  static const Color _neutral5 = Color(0xFFFFFFFF);
  static const Color _neutral10 = Color(0xFFF5F1F1);
  static const Color _neutral20 = Color(0xFF808080);
  static const Color _neutral30 = Color(0xFFDCDCDC);
  static const Color _neutral50 = Color(0xFFBDBDBD);
  static const Color _neutral70 = Color(0xFF333333);
  static const Color _neutral90 = Color(0xFF101820);

  static const Color _textPrimary = Color(0xFF1B1B1B);
  static const Color _textSecondary = Color(0xFFBDBDBD);
  static const Color _input = Color.fromARGB(186, 235, 238, 246);
  static const Color _tabbar = Color(0xFFFAFAFA);

  static const Color _success = Color(0xFF3AA757);
  static const Color _warning = Color(0xFFF57C00);
  static const Color _info = Color(0xFF2196F3);
  static const Color _error = Color(0xFFE53935);

  // ---------------------------------------------------------------------------
  // Guardify (RED / CRIMSON) — current app identity. Values from colors.dart.
  // ---------------------------------------------------------------------------
  static ColorPalette get _guardify => ColorPalette(
        seed: const Color(0xFFE74C3C),
        primary: const Color(0xFF8B0000),
        primaryDark: const Color(0xFF5D0000),
        primaryAccent: const Color(0xFFBB0000),
        neutral5: _neutral5,
        neutral10: _neutral10,
        neutral20: _neutral20,
        neutral30: _neutral30,
        neutral50: _neutral50,
        neutral70: _neutral70,
        neutral90: _neutral90,
        error: _error,
        success: _success,
        warning: _warning,
        info: _info,
        background: const Color(0xFFFFFFFF),
        backgroundDark: Color.fromARGB(255, 105, 105, 105),
        surface: const Color(0xFFFFFFFF),
        surfaceDark: const Color(0xFF1E1E1E),
        textPrimary: _textPrimary,
        textSecondary: _textSecondary,
        input: _input,
        tabbar: _tabbar,
      );

  // ---------------------------------------------------------------------------
  // OCEAN (BLUE) — "Trust Blue" scheme: vivid #0A7CFF seed, deep #0B3D91 brand.
  // ---------------------------------------------------------------------------
  static ColorPalette get _ocean => ColorPalette(
        seed: const Color(0xFF0A7CFF),
        primary: const Color(0xFF0B3D91),
        primaryDark: const Color(0xFF072A63),
        primaryAccent: const Color(0xFF4DA8FF),
        neutral5: _neutral5,
        neutral10: _neutral10,
        neutral20: _neutral20,
        neutral30: _neutral30,
        neutral50: _neutral50,
        neutral70: _neutral70,
        neutral90: _neutral90,
        error: _error,
        success: _success,
        warning: _warning,
        info: _info,
        background: const Color(0xFFFAFCFF),
        backgroundDark: const Color(0xFF0B1120),
        surface: const Color(0xFFFFFFFF),
        surfaceDark: const Color(0xFF17202E),
        textPrimary: const Color(0xFF0B1220),
        textSecondary: _textSecondary,
        input: _input,
        tabbar: _tabbar,
      );

  // ---------------------------------------------------------------------------
  // FOREST (GREEN)
  // ---------------------------------------------------------------------------
  static ColorPalette get _forest => ColorPalette(
        seed: const Color(0xFF2E7D32),
        primary: const Color(0xFF1B5E20),
        primaryDark: const Color(0xFF123F16),
        primaryAccent: const Color(0xFF43A047),
        neutral5: _neutral5,
        neutral10: _neutral10,
        neutral20: _neutral20,
        neutral30: _neutral30,
        neutral50: _neutral50,
        neutral70: _neutral70,
        neutral90: _neutral90,
        error: _error,
        success: _success,
        warning: _warning,
        info: _info,
        background: const Color(0xFFFAFFFA),
        backgroundDark: const Color(0xFF0F1613),
        surface: const Color(0xFFFFFFFF),
        surfaceDark: const Color(0xFF1B241D),
        textPrimary: const Color(0xFF15200D),
        textSecondary: _textSecondary,
        input: _input,
        tabbar: _tabbar,
      );

  // ---------------------------------------------------------------------------
  // AMBER (ORANGE)
  // ---------------------------------------------------------------------------
  static ColorPalette get _amber => ColorPalette(
        seed: const Color(0xFFFFB300),
        primary: const Color(0xFFB26500),
        primaryDark: const Color(0xFF7A4300),
        primaryAccent: const Color(0xFFFFB300),
        neutral5: _neutral5,
        neutral10: _neutral10,
        neutral20: _neutral20,
        neutral30: _neutral30,
        neutral50: _neutral50,
        neutral70: _neutral70,
        neutral90: _neutral90,
        error: _error,
        success: _success,
        warning: _warning,
        info: _info,
        background: const Color(0xFFFFFFFF),
        backgroundDark: const Color(0xFF121008),
        surface: const Color(0xFFFFFFFF),
        surfaceDark: const Color(0xFF241F12),
        textPrimary: const Color(0xFF1A1500),
        textSecondary: _textSecondary,
        input: _input,
        tabbar: _tabbar,
      );
}
