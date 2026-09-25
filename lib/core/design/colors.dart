import 'package:flutter/material.dart';

import 'theme_controller.dart';

// =============================================================================
// Brand colors — runtime getters backed by the ACTIVE ColorPalette.
//
// Originally these were top-level `const`s frozen at compile time, so changing
// the theme (JSON branding) never re-skinned screens that referenced them.
// Now each getter reads the active palette (set at boot from branding_config),
// so `primaryColor`, `bgColor`, neutrals, etc. all follow the theme instantly.
// Names are unchanged → all 91 importing files re-skin without edits.
// =============================================================================

// Brand accent.
Color get primaryColor => ThemeController.instance.currentPalette.primary;
Color get primaryDark => ThemeController.instance.currentPalette.primaryDark;
Color get primaryAccent => ThemeController.instance.currentPalette.primaryAccent;

// Brand tonal ramp (derived from the active palette's seed).
Color get primary10 => ThemeController.instance.currentPalette.seed.withOpacity(.1);
Color get primary30 => ThemeController.instance.currentPalette.seed.withOpacity(.3);
Color get primary50 => ThemeController.instance.currentPalette.seed.withOpacity(.5);
Color get primary70 => ThemeController.instance.currentPalette.seed.withOpacity(.7);
Color get primary90 => ThemeController.instance.currentPalette.seed.withOpacity(.9);

Color get secondary10 => ThemeController.instance.currentPalette.seed.withOpacity(.1);
Color get secondary30 => ThemeController.instance.currentPalette.seed.withOpacity(.3);
Color get secondary70 => ThemeController.instance.currentPalette.seed.withOpacity(.7);
Color get secondary90 => ThemeController.instance.currentPalette.seed.withOpacity(.9);
Color get secondary50 => ThemeController.instance.currentPalette.seed;

// Neutral ramp.
Color get neutral90 => ThemeController.instance.currentPalette.neutral90;
Color get neutral70 => ThemeController.instance.currentPalette.neutral70;
Color get neutral50 => ThemeController.instance.currentPalette.neutral50;
Color get neutral30 => ThemeController.instance.currentPalette.neutral30;
Color get neutral20 => ThemeController.instance.currentPalette.neutral20;
Color get neutral10 => ThemeController.instance.currentPalette.neutral10;
Color get neutral5 => ThemeController.instance.currentPalette.neutral5;

// Surfaces.
Color get bgColor => ThemeController.instance.currentPalette.background;
Color get bgColorDark => ThemeController.instance.currentPalette.backgroundDark;

// Semantic.
Color get focusColor => ThemeController.instance.currentPalette.info;
Color get errorColor => ThemeController.instance.currentPalette.error;
Color get successColor => ThemeController.instance.currentPalette.success;
Color get normalColor => ThemeController.instance.currentPalette.neutral50;
Color get disabledColor => ThemeController.instance.currentPalette.neutral30;

// Text & fields.
Color get appTextColor => ThemeController.instance.currentPalette.textPrimary;
Color get appHintColor => ThemeController.instance.currentPalette.textSecondary;
Color get inputColor => ThemeController.instance.currentPalette.input;

// Grays.
Color get white => Colors.white;
Color get greySecond => ThemeController.instance.currentPalette.neutral30;
Color get grey => ThemeController.instance.currentPalette.neutral50;
Color get darkGrey => ThemeController.instance.currentPalette.neutral70;

// Surfaces / accents.
Color get cardColor => ThemeController.instance.currentPalette.surface;
Color get favoriteColor => const Color(0xFFFAC826); // brand badge (yellow)
Color get tabbarColor => ThemeController.instance.currentPalette.tabbar;
Color get babyBlueColor => ThemeController.instance.currentPalette.info.withOpacity(.2);

// Material color map (drives Material2 widgets that read a swatch).
Map<int, Color> get materialColor {
  final seed = ThemeController.instance.currentPalette.seed;
  return {
    50: seed.withOpacity(.1),
    100: seed.withOpacity(.2),
    200: seed.withOpacity(.3),
    300: seed.withOpacity(.4),
    400: seed.withOpacity(.5),
    500: seed.withOpacity(.6),
    600: seed.withOpacity(.7),
    700: seed.withOpacity(.8),
    800: seed.withOpacity(.9),
    900: seed,
  };
}

class Gradients {
  static LinearGradient primary() {
    final p = ThemeController.instance.currentPalette;
    return LinearGradient(
      colors: [p.seed, p.primary],
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    );
  }

  static LinearGradient primaryAccent() {
    final p = ThemeController.instance.currentPalette;
    return LinearGradient(
      colors: [p.seed, p.primaryAccent],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static LinearGradient neutral() {
    final p = ThemeController.instance.currentPalette;
    return LinearGradient(
      colors: [p.neutral10, p.neutral30],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static LinearGradient cardGradient() {
    final p = ThemeController.instance.currentPalette;
    return LinearGradient(
      colors: [p.seed, p.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}