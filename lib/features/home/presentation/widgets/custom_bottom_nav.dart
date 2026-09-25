import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:guardify_app/core/design/colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onEmergencyPressed;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onEmergencyPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Get system navigation bar padding for Android
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 80.h + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left side - 2 nav items
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Beranda',
                      index: 0,
                      isActive: currentIndex == 0,
                    ),
                    _buildNavItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: 'Kalender',
                      index: 1,
                      isActive: currentIndex == 1,
                    ),
                  ],
                ),
              ),
              // Center space for emergency button (overlay)
              SizedBox(width: 70.w),
              // Right side - 2 nav items
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      label: 'Pesan',
                      index: 2,
                      isActive: currentIndex == 2,
                    ),
                    _buildNavItem(
                      icon: Icons.notifications_outlined,
                      activeIcon: Icons.notifications,
                      label: 'Notifikasi',
                      index: 3,
                      isActive: currentIndex == 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Emergency button overlay (centered, elevated)
        Positioned(
          left: 0,
          right: 0,
          top: -30.h,
          child: Center(
            child: GestureDetector(
              onTap: onEmergencyPressed,
              child: Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: errorColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: errorColor.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 45.w,
                    height: 45.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning,
                      color: errorColor,
                      size: 28.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? primaryColor : neutral50,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? primaryColor : neutral50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
