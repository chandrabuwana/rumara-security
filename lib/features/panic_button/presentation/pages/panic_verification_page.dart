import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_event.dart';
import '../bloc/panic_button_state.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicVerificationPage extends StatelessWidget {
  const PanicVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize bloc with event
    context.read<PanicButtonBloc>().add(const LoadVerificationItemsEvent());
    return const _PanicVerificationView();
  }
}

class _PanicVerificationView extends StatelessWidget {
  const _PanicVerificationView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      enableScrolling: false,
      backgroundColor: Colors.white,
      appBar: RumaraAppBar(title: 'Tombol Darurat', onBack: () {
            context.read<PanicButtonBloc>().add(const ResetVerificationEvent());
            Navigator.pop(context);
          }),
      child: BlocConsumer<PanicButtonBloc, PanicButtonState>(
        listener: (context, state) {
          if (state.status == PanicButtonStateStatus.activated) {
            _showSuccessDialog(context);
          } else if (state.status == PanicButtonStateStatus.error) {
            _showErrorDialog(context, state.errorMessage ?? 'Unknown error');
          }
        },
        builder: (context, state) {
          if (state.status == PanicButtonStateStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE5484D),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: state.verificationItems.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 24.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.h,
                              margin: EdgeInsets.only(right: 16.w, top: 2.h),
                              child: Checkbox(
                                value: state.verificationStates[index],
                                onChanged: (bool? value) {
                                  context.read<PanicButtonBloc>().add(
                                        UpdateVerificationEvent(
                                            index, value ?? false),
                                      );
                                },
                                activeColor: const Color(0xFFE5484D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                state.verificationItems[index],
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Bottom buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: () {
                            context
                                .read<PanicButtonBloc>()
                                .add(const ResetVerificationEvent());
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5484D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'KEMBALI',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    16.horizontalSpace,
                    Expanded(
                      child: SizedBox(
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: state.allVerified
                              ? () {
                                  Navigator.pushNamed(
                                      context, '/panic-disaster-confirmation');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.allVerified
                                ? const Color(0xFFE5484D)
                                : Colors.grey[300],
                            foregroundColor: state.allVerified
                                ? Colors.white
                                : Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'LANJUT',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                20.verticalSpace,
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: const BoxDecoration(
                color: Color(0xFFE5484D),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 50.w,
              ),
            ),
            20.verticalSpace,
            Text(
              'Panic Button Diaktifkan!',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            12.verticalSpace,
            Text(
              'Alert darurat telah dikirim ke tim keamanan dan atasan Anda.',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            SizedBox(
              width: double.infinity,
              height: 45.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to home
                  context
                      .read<PanicButtonBloc>()
                      .add(const ResetVerificationEvent());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5484D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
