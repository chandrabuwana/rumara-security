import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'color_palette.dart';
import 'palettes.dart';

/// Brightness mode — mirrors the app-level theme selector.
enum ThemeBrightness { system, light, dark }

/// Holds the currently-selected [Palettes] accent + [ThemeBrightness] and
/// notifies listeners when either changes.
///
/// Persistence goes through [SharedPreferences] (the same store main.dart uses
/// for the corrupted-`api_logs` guard). The controller is deliberately a
/// hand-rolled singleton rather than a get_it binding so we do NOT need to
/// re-generate `injection.config.dart` (which `build_runner` owns).
class ThemeController {
  ThemeController();

  static ThemeController? _instance;

  static ThemeController get instance {
    _instance ??= ThemeController();
    return _instance!;
  }

  static const String keyPalette = 'app_theme_palette';
  static const String keyBrightness = 'app_theme_brightness';

  final ValueNotifier<Palettes> palette = ValueNotifier<Palettes>(
    Palettes.guardify,
  );
  final ValueNotifier<ThemeBrightness> brightness =
      ValueNotifier<ThemeBrightness>(ThemeBrightness.system);

  ColorPalette get currentPalette => PaletteRegistry.of(palette.value);

  // Custom accent seed from the branding config (overrides the preset's seed).
  // Set once at boot BEFORE runApp, so the first MaterialApp build already uses
  // it — no runtime notifier needed.
  Color? _seedOverride;
  set seedOverride(Color? value) => _seedOverride = value;

  /// The effective seed: branding override when set, else the palette's default.
  Color get currentSeed => _seedOverride ?? currentPalette.seed;

  /// Load persisted palette + brightness from [prefs]. Safe to call more than
  /// once (idempotent); does not notify if nothing changed.
  Future<void> loadFrom(SharedPreferences prefs) async {
    final p = prefs.getString(keyPalette);
    if (p != null) {
      for (final candidate in PaletteRegistry.all) {
        if (candidate.name == p) {
          palette.value = candidate;
          break;
        }
      }
    }

    final b = prefs.getString(keyBrightness);
    if (b != null) {
      for (final mode in ThemeBrightness.values) {
        if (mode.name.toLowerCase() == b.toLowerCase()) {
          brightness.value = mode;
          break;
        }
      }
    }
  }

  /// Persist + notify. Returns a Future that completes once saved.
  Future<void> setPalette(SharedPreferences prefs, Palettes value) async {
    palette.value = value;
    await prefs.setString(keyPalette, value.name);
  }

  Future<void> setBrightness(
    SharedPreferences prefs,
    ThemeBrightness value,
  ) async {
    brightness.value = value;
    await prefs.setString(keyBrightness, value.name.toLowerCase());
  }
}
