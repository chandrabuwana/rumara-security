import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_state.dart';
import '../bloc/panic_button_event.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicConfirmationPage extends StatelessWidget {
  const PanicConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PanicConfirmationView();
  }
}

class _PanicConfirmationView extends StatelessWidget {
  const _PanicConfirmationView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const RumaraAppBar(title: 'Tombol Darurat'),
      child: BlocListener<PanicButtonBloc, PanicButtonState>(
        listener: (context, state) {
          if (state.status == PanicButtonStateStatus.activated) {
            // Show success dialog
            _showSuccessDialog(context);
          } else if (state.status == PanicButtonStateStatus.error) {
            // Show error dialog
            _showErrorDialog(context, state.errorMessage ?? 'Unknown error');
          }
        },
        child: BlocBuilder<PanicButtonBloc, PanicButtonState>(
          builder: (context, state) {
            return Padding(
              padding: REdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  Row(
                    children: [
                      _buildProgressDot(true),
                      _buildProgressLine(true),
                      _buildProgressDot(true),
                      _buildProgressLine(true),
                      _buildProgressDot(true),
                      _buildProgressLine(true),
                      _buildProgressDot(true),
                    ],
                  ),
                  40.verticalSpace,

                  // Warning icon
                  Center(
                    child: Container(
                      width: 100.w,
                      height: 100.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5484D),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 50.r,
                      ),
                    ),
                  ),
                  32.verticalSpace,

                  // Title
                  Center(
                    child: Text(
                      'Panic Button akan diaktifkan!',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  16.verticalSpace,

                  // Description
                  Center(
                    child: Text(
                      'Tim keamanan dan atasan akan segera dihubungi. Pastikan anda berada di tempat yang aman.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  50.verticalSpace,

                  // Bottom buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.popUntil(
                                  context, (route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'BATAL',
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
                            onPressed:
                                state.status == PanicButtonStateStatus.loading
                                    ? null
                                    : () {
                                        context.read<PanicButtonBloc>().add(
                                              const ActivatePanicButtonEvent(
                                                  'user_123'),
                                            );
                                      },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5484D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child:
                                state.status == PanicButtonStateStatus.loading
                                    ? SizedBox(
                                        width: 20.w,
                                        height: 20.h,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'AKTIFKAN',
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
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12.w,
      height: 12.h,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE5484D) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2.h,
        color: isActive ? const Color(0xFFE5484D) : Colors.grey[300],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
                  size: 40.r,
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
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5484D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'KEMBALI KE BERANDA',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Error',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  color: const Color(0xFFE5484D),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
