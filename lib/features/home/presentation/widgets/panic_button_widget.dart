import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:guardify_app/core/design/colors.dart';

class PanicButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;

  const PanicButtonWidget({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Row(
        children: [
          // Tombol Text
          Expanded(
            child: Text(
              'TOMBOL',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // SOS Button
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: errorColor, // Theme-driven danger color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: errorColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White triangle background
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning,
                      color: errorColor,
                      size: 40.sp,
                    ),
                  ),
                  // SOS text at bottom
                  Positioned(
                    bottom: 4.h,
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Darurat Text
          Expanded(
            child: Text(
              'DARURAT',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
