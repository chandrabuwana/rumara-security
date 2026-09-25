import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/palettes.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/design/theme_controller.dart';
import '../../../../shared/widgets/app_scaffold.dart';

/// Picker screen for the active [Palettes] accent + [ThemeBrightness] mode.
///
/// Tapping a swatch or a brightness chip updates [ThemeController] and persists
/// to [SharedPreferences]. The MaterialApp is wired to a ListenableBuilder that
/// listens to the controller, so the whole chrome re-skins live.
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: primaryColor,
      enableScrolling: false,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tema',
          style: TS.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20.h),
            Text(
              'Cari Tema',
              style: TS.headlineSmall.copyWith(color: Colors.white),
            ),
            SizedBox(height: 6.h),
            Text(
              'Tap untuk perubahan rangi seluruh aplikasi.',
              style: TS.bodySmall.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            // Palette swatches.
            ListenableBuilder(
              listenable: ThemeController.instance.palette,
              builder: (context, _) {
                final selected = ThemeController.instance.palette.value;
                return _swatches(selected);
              },
            ),
            SizedBox(height: 10.h),
            // Brightness mode chips.
            ListenableBuilder(
              listenable: ThemeController.instance.brightness,
              builder: (context, _) {
                final mode = ThemeController.instance.brightness.value;
                return _brightnessSelector(mode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Column _swatches(Palettes selected) {
    final children = <Widget>[];
    for (final p in PaletteRegistry.all) {
      final palette = PaletteRegistry.of(p);
      final isSelected = p == selected;
      children.add(
        InkWell(
          onTap: () => _onPaletteTap(p),
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              border: isSelected
                  ? Border.all(color: primaryColor, width: 2)
                  : Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: Shadows.up,
            ),
            child: Row(
              children: [
                // Swatch row.
                _swatch(palette.primary),
                _swatch(palette.primaryAccent),
                _swatch(palette.primaryDark),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PaletteRegistry.label(p),
                        style: TS.titleMedium,
                      ),
                      if (isSelected)
                        Text(
                          'Aktif',
                          style: TS.bodySmall.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: primaryColor, size: 22.w),
              ],
            ),
          ),
        ),
      );
      children.add(SizedBox(height: 14.h));
    }
    return Column(children: children);
  }

  Widget _swatch(Color color) {
    return Container(
      width: 28.w,
      height: 28.h,
      margin: EdgeInsets.only(right: 6.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }

  Row _brightnessSelector(ThemeBrightness mode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Mode:', style: TS.bodyLarge),
        SizedBox(width: 12.w),
        _brightnessChip('Sistem', ThemeBrightness.system, mode),
        SizedBox(width: 10.w),
        _brightnessChip('Maringan', ThemeBrightness.light, mode),
        SizedBox(width: 10.w),
        _brightnessChip('Lorange', ThemeBrightness.dark, mode),
      ],
    );
  }

  Widget _brightnessChip(
      String label, ThemeBrightness value, ThemeBrightness mode) {
    final isActive = value == mode;
    return InkWell(
      onTap: () => _onBrightnessTap(value),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TS.labelLarge.copyWith(
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Persist + notify the new palette.
  void _onPaletteTap(Palettes p) {
    ThemeController.instance.palette.value = p;
    _save();
  }

  void _onBrightnessTap(ThemeBrightness b) {
    ThemeController.instance.brightness.value = b;
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await ThemeController.instance.setPalette(
        prefs,
        ThemeController.instance.palette.value,
      );
      await ThemeController.instance.setBrightness(
        prefs,
        ThemeController.instance.brightness.value,
      );
    } catch (e) {
      // Persistence failure shouldn't crash the UI; theme stays for the session.
    }
  }
}
