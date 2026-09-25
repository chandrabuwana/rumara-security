import 'dart:convert';

import 'package:flutter/material.dart' show Color;

import 'palettes.dart';
import 'theme_controller.dart';

/// Branding for one company/deployment, parsed from `assets/config/branding_config.json`.
///
/// This is what makes the app white-label: edit the JSON + swap the logo assets
/// and a different company's binary is produced with no Dart changes. All parsed
/// with safe fallbacks back to the current Guardify defaults.
class BrandingConfig {
  // App.
  final String appName;
  final String appTitle;

  // Theme.
  final Palettes palette;
  final Color seed;
  final ThemeBrightness brightness;

  // Branding assets.
  final String logo;
  final String logoDark;
  final String shield;

  // Backend.
  final String apiBaseUrl;

  // Keys.
  final String tokenKey;
  final String encryptionKey;

  const BrandingConfig({
    required this.appName,
    required this.appTitle,
    required this.palette,
    required this.seed,
    required this.brightness,
    required this.logo,
    required this.logoDark,
    required this.shield,
    required this.apiBaseUrl,
    required this.tokenKey,
    required this.encryptionKey,
  });

  /// Parse a JSON string into a [BrandingConfig], falling back to Guardify
  /// defaults for any missing/invalid field (never throws).
  static BrandingConfig parse(String json) {
    Map<String, dynamic> map = {};
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      map = {};
    }

    final app = _asMap(map['app']);
    final theme = _asMap(map['theme']);
    final branding = _asMap(map['branding']);
    final backend = _asMap(map['backend']);
    final keys = _asMap(map['keys']);

    return BrandingConfig(
      appName: _asString(app['name'], 'Guardify App'),
      appTitle: _asString(app['title'], 'Guardify App'),
      palette: _asPalette(theme['palette']),
      seed: _asColor(theme['seed'], const Color(0xFFE74C3C)),
      brightness: _asBrightness(theme['brightness']),
      logo: _asString(
        branding['logo'],
        'assets/images/guardify-round-white.svg',
      ),
      logoDark:
          _asString(branding['logoDark'], 'assets/images/logo_guardify.svg'),
      shield: _asString(branding['shield'], 'assets/images/shield_logo.svg'),
      apiBaseUrl: _asString(
        backend['apiBaseUrl'],
        'https://api-guardify.abb-apps.com/api/v1',
      ),
      tokenKey: _asString(keys['tokenKey'], 'token_guardify'),
      encryptionKey: _asString(
        keys['encryptionKey'],
        'guardify_encryption_key_2024',
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : const {};

  static String _asString(dynamic v, String fallback) =>
      v is String && v.isNotEmpty ? v : fallback;

  static Palettes _asPalette(dynamic v) {
    if (v is String) {
      for (final candidate in PaletteRegistry.all) {
        if (candidate.name == v) return candidate;
      }
    }
    return Palettes.guardify;
  }

  static ThemeBrightness _asBrightness(dynamic v) {
    if (v is String) {
      for (final mode in ThemeBrightness.values) {
        if (mode.name.toLowerCase() == v.toLowerCase()) {
          return mode;
        }
      }
    }
    return ThemeBrightness.system;
  }

  /// Parse a `#RRGGBB` (or `#RRGGBBAA`) color string. Falls back on failure.
  static Color _asColor(dynamic v, Color fallback) {
    if (v is! String) return fallback;
    // Strip a leading '#'. Use substring, NOT regex — replaceFirst treats the
    // pattern as a literal so '^#' would NOT strip (found via ad-hoc test).
    var s = v;
    if (s.startsWith('#')) s = s.substring(1);
    // Parse hex digits directly — do NOT prepend '0x' when radix is given
    // (Dart's int.tryParse rejects the 0x prefix with an explicit radix).
    final intValue = int.tryParse(s, radix: 16);
    if (intValue == null || s.length < 6) return fallback;
    // Treat as RGB (FF alpha).
    return Color(0xFF000000 | intValue);
  }
}

/// Singleton holder for the active [BrandingConfig].
///
/// Loaded once at boot from the bundled asset by [BrandingController]. Screens
/// that render a logo/name/title read from here instead of hardcoded values.
class BrandingController {
  BrandingController();

  static BrandingController? _instance;

  static BrandingController get instance {
    _instance ??= BrandingController();
    return _instance!;
  }

  BrandingConfig _config = BrandingConfig.parse('');

  BrandingConfig get config => _config;

  String get appName => _config.appName;
  String get appTitle => _config.appTitle;
  Palettes get palette => _config.palette;
  ThemeBrightness get brightness => _config.brightness;
  String get logo => _config.logo;
  String get logoDark => _config.logoDark;
  String get shield => _config.shield;
  String get apiBaseUrl => _config.apiBaseUrl;
  String get tokenKey => _config.tokenKey;
  String get encryptionKey => _config.encryptionKey;

  /// Default bundled branding config path.
  static const String defaultAssetPath = 'assets/config/branding_config.json';

  /// Set the active config (from the parsed JSON) and drive the theme.
  void apply(BrandingConfig config) {
    _config = config;
    ThemeController.instance.palette.value = config.palette;
    ThemeController.instance.brightness.value = config.brightness;
    ThemeController.instance.seedOverride = config.seed;
  }

  /// Load the bundled branding JSON from [rootBundle] and apply it.
  ///
  /// [assetPath] can be overridden for white-label builds (each company ships a
  /// different config). Never throws: on failure the Guardify defaults remain.
  /// [rootBundle] comes from `package:flutter/services.dart`; the asset key must
  /// match the path declared under `flutter: assets:` in pubspec.yaml.
  Future<void> loadFromAsset(
    dynamic bundle, {
    String assetPath = defaultAssetPath,
  }) async {
    try {
      final json = await bundle.loadString(assetPath);
      apply(BrandingConfig.parse(json));
    } catch (e) {
      // Fall back to the current config (Guardify defaults on first run).
    }
  }
}
