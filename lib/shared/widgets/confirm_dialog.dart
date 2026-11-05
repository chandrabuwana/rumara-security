import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/design/colors.dart';
import '../../core/design/styles.dart';
import 'Buttons/ui_button.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;

  const ConfirmDialog({
    Key? key,
    required this.title,
    required this.message,
    this.confirmText = 'Ya',
    this.cancelText = 'Tidak',
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      contentPadding: REdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: (iconColor ?? primaryColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon!,
                size: 32.sp,
                color: iconColor ?? primaryColor,
              ),
            ),
            16.verticalSpace,
          ],
          Text(
            title,
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(
              color: const Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          Row(
            children: [
              Expanded(
                child: UIButton(
                  text: cancelText,
                  buttonType: UIButtonType.outline,
                  variant: UIButtonVariant.neutral,
                  onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: UIButton(
                  text: confirmText,
                  variant: isDestructive
                      ? UIButtonVariant.error
                      : UIButtonVariant.primary,
                  onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Ya',
    String cancelText = 'Tidak',
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        iconColor: iconColor,
        isDestructive: isDestructive,
      ),
    );
  }
}
