import 'package:guardify_app/core/config/environment_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppConfig {
  static EnvironmentConfig get environment =>
      const EnvironmentConfig.development();
  static set environment(EnvironmentConfig env) {}

  static double get dAppbarHeight => 60;
  static set dAppbarHeight(double v) {}

  static double get dPadding => 16;
  static set dPadding(double v) {}

  static String get fontFamily => GoogleFonts.dmSans().fontFamily ?? 'DM Sans';
  static set fontFamily(String v) {}

  static String get fileName =>
      'ISI-MOBILE-${DateFormat('ddMMyyyyHHmmss').format(DateTime.now())}';
}
