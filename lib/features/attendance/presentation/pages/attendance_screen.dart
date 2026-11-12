import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';
import 'check_in_page.dart';
import 'check_out_page.dart';
import '../../domain/usecases/get_attendance_status_usecase.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class AttendanceScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const AttendanceScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          getIt<AttendanceBloc>()..add(GetAttendanceStatusEvent(userId)),
      child: _AttendanceScreenView(
        userId: userId,
        userName: userName,
      ),
    );
  }
}

class _AttendanceScreenView extends StatelessWidget {
  final String userId;
  final String userName;

  const _AttendanceScreenView({
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: bgColor,
      enableScrolling: false,
      appBar: const RumaraAppBar(title: 'Absensi'),
      child: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AttendanceStatusLoaded) {
            return _buildAttendanceStatus(context, state);
          }

          if (state is AttendanceFailure) {
            return _buildErrorState(context, state.message);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildAttendanceStatus(
      BuildContext context, AttendanceStatusLoaded state) {
    return Padding(
      padding: REdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Absensi',
                  style: TS.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                12.verticalSpace,
                Row(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: _getStatusColor(state.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    8.horizontalSpace,
                    Text(
                      _getStatusText(state.status),
                      style: TS.bodyLarge.copyWith(
                        color: _getStatusColor(state.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (state.currentAttendance != null) ...[
                  16.verticalSpace,
                  Text(
                    'Waktu Check In: ${_formatTime(state.currentAttendance!.timestamp)}',
                    style: TS.bodyMedium.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          24.verticalSpace,

          // Action Button
          SizedBox(
            width: double.infinity,
            child: UIButton(
              text: _getButtonText(state.status),
              onPressed: () => _handleAction(context, state.status),
              variant: state.status == UserAttendanceStatus.checkedIn
                  ? UIButtonVariant.warning
                  : UIButtonVariant.primary,
              size: UIButtonSize.large,
            ),
          ),

          24.verticalSpace,

          // Info Section
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20.sp,
                    ),
                    8.horizontalSpace,
                    Text(
                      'Informasi',
                      style: TS.labelMedium.copyWith(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                8.verticalSpace,
                Text(
                  _getInfoText(state.status),
                  style: TS.bodySmall.copyWith(
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: Colors.red,
          ),
          16.verticalSpace,
          Text(
            'Terjadi Kesalahan',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          UIButton(
            text: 'Coba Lagi',
            onPressed: () {
              context.read<AttendanceBloc>().add(
                    GetAttendanceStatusEvent(userId),
                  );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(UserAttendanceStatus status) {
    switch (status) {
      case UserAttendanceStatus.notCheckedIn:
        return Colors.orange;
      case UserAttendanceStatus.checkedIn:
        return Colors.green;
      case UserAttendanceStatus.checkedOut:
        return Colors.blue;
    }
  }

  String _getStatusText(UserAttendanceStatus status) {
    switch (status) {
      case UserAttendanceStatus.notCheckedIn:
        return 'Belum Check In';
      case UserAttendanceStatus.checkedIn:
        return 'Sedang Bekerja';
      case UserAttendanceStatus.checkedOut:
        return 'Sudah Check Out';
    }
  }

  String _getButtonText(UserAttendanceStatus status) {
    switch (status) {
      case UserAttendanceStatus.notCheckedIn:
        return 'Mulai Bekerja';
      case UserAttendanceStatus.checkedIn:
        return 'Akhiri Bekerja';
      case UserAttendanceStatus.checkedOut:
        return 'Sudah Selesai';
    }
  }

  String _getInfoText(UserAttendanceStatus status) {
    switch (status) {
      case UserAttendanceStatus.notCheckedIn:
        return 'Anda belum melakukan check in hari ini. Tekan tombol "Mulai Bekerja" untuk memulai absensi.';
      case UserAttendanceStatus.checkedIn:
        return 'Anda sedang dalam masa kerja. Tekan tombol "Akhiri Bekerja" untuk melakukan check out.';
      case UserAttendanceStatus.checkedOut:
        return 'Anda sudah menyelesaikan absensi hari ini. Terima kasih atas kerja keras Anda.';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(BuildContext context, UserAttendanceStatus status) {
    switch (status) {
      case UserAttendanceStatus.notCheckedIn:
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => CheckInPage(
              userId: userId,
              namaPersonil: userName,
            ),
          ),
        )
            .then((_) {
          // Refresh status after returning from check in
          context.read<AttendanceBloc>().add(
                GetAttendanceStatusEvent(userId),
              );
        });
        break;
      case UserAttendanceStatus.checkedIn:
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => CheckOutPage(
              userId: userId,
              attendanceId:
                  '', // You might need to pass the actual attendance ID
            ),
          ),
        )
            .then((_) {
          // Refresh status after returning from check out
          context.read<AttendanceBloc>().add(
                GetAttendanceStatusEvent(userId),
              );
        });
        break;
      case UserAttendanceStatus.checkedOut:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda sudah menyelesaikan absensi hari ini'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
    }
  }
}
