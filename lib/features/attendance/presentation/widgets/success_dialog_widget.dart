import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/design/colors.dart';

class SuccessDialogWidget extends StatelessWidget {
  final String message;
  final VoidCallback onConfirm;

  const SuccessDialogWidget({
    super.key,
    required this.message,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      contentPadding: REdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.thumb_up,
              color: Colors.white,
              size: 40.r,
            ),
          ),
          20.verticalSpace,
          Text(
            'Check In Berhasil',
            style: TS.titleLarge.copyWith(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          8.verticalSpace,
          Text(
            'Selamat Bekerja!',
            style: TS.bodyLarge.copyWith(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          30.verticalSpace,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: REdgeInsets.symmetric(vertical: 15),
                elevation: 0,
              ),
              child: Text(
                'OK',
                style: TS.labelLarge.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
