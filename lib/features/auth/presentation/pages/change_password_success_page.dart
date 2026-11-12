import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ChangePasswordSuccessPage extends StatelessWidget {
  const ChangePasswordSuccessPage({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      enableScrolling: false,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => _goToLogin(context),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 220.w,
                      height: 220.w,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified,
                        size: 120.sp,
                        color: primaryColor,
                      ),
                    ),
                    24.verticalSpace,
                    Text(
                      'Ubah Password Berhasil!',
                      style: TS.headlineSmall.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    12.verticalSpace,
                    Text(
                      'Anda berhasil mengubah password.\nSilakan gunakan kata sandi baru saat masuk.',
                      style: TS.bodyMedium.copyWith(
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              UIButton(
                text: 'Ok',
                fullWidth: true,
                size: UIButtonSize.medium,
                variant: UIButtonVariant.primary,
                onPressed: () {
                  _goToLogin(context);
                },
                borderRadius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
