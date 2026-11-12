import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/colors.dart';

class RumaraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RumaraAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.showBack = true,
    this.bottom,
  });

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    const shape = BorderRadius.vertical(bottom: Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: rumaraHeaderGradient,
        borderRadius: shape,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: showBack ? NavigationToolbar.kMiddleSpacing : 16,
          leading: showBack
              ? IconButton(
                  tooltip: 'Kembali',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              : null,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: actions,
          bottom: bottom,
        ),
      ),
    );
  }
}
