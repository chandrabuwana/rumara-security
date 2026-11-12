import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Custom AppBar dengan design yang konsisten untuk halaman peraturan perusahaan
///
/// AppBar ini menyediakan layout standar dengan:
/// - Back button di kiri
/// - Title di tengah
/// - Action button(s) di kanan
/// - Theme warna merah gelap sesuai design
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    Key? key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions = const [],
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 1,
    this.centerTitle = true,
  }) : super(key: key);

  /// Judul yang akan ditampilkan di AppBar
  final String title;

  /// Apakah menampilkan back button atau tidak
  final bool showBackButton;

  /// Callback ketika back button ditekan
  final VoidCallback? onBackPressed;

  /// List action widgets di kanan AppBar
  final List<Widget> actions;

  /// Background color AppBar (default: primaryColor)
  final Color? backgroundColor;

  /// Foreground color (text & icons) (default: white)
  final Color? foregroundColor;

  /// Elevation shadow AppBar
  final double elevation;

  /// Apakah title di center atau tidak
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return RumaraAppBar(
      title: title,
      showBack: showBackButton,
      onBack: onBackPressed,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Factory methods untuk variasi AppBar yang umum digunakan
extension CustomAppBarFactory on CustomAppBar {
  /// AppBar untuk halaman detail dengan download button
  static CustomAppBar detailPage({
    required String title,
    VoidCallback? onBackPressed,
    VoidCallback? onDownloadPressed,
    bool isDownloading = false,
  }) {
    return CustomAppBar(
      title: title,
      onBackPressed: onBackPressed,
      actions: [
        if (onDownloadPressed != null)
          Padding(
            padding: REdgeInsets.only(right: 16),
            child: IconButton(
              icon: isDownloading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              onPressed: isDownloading ? null : onDownloadPressed,
              tooltip: 'Download',
            ),
          ),
      ],
    );
  }

  /// AppBar untuk halaman list dengan action button
  static CustomAppBar listPage({
    required String title,
    VoidCallback? onBackPressed,
    List<Widget>? actions,
  }) {
    return CustomAppBar(
      title: title,
      onBackPressed: onBackPressed,
      actions: actions ?? [],
    );
  }
}
