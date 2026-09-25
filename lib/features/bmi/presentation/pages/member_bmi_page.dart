import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/constants/enums.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../bloc/bmi_bloc.dart';
import '../widgets/bmi_calculation_dialog.dart';

/// Page untuk role anggota - menampilkan BMI personal
class MemberBMIPage extends StatefulWidget {
  final String userId;

  const MemberBMIPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<MemberBMIPage> createState() => _MemberBMIPageState();
}

class _MemberBMIPageState extends State<MemberBMIPage> {
  BMIBloc get _bmiBloc => context.read<BMIBloc>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _bmiBloc.add(BMIGetUserProfile(widget.userId));
    _bmiBloc.add(BMILoadHistory(widget.userId));
  }

  void _showBMICalculationDialog() {
    final currentProfile = _bmiBloc.state.currentUserProfile;

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: _bmiBloc,
        child: BMICalculationDialog(
          userId: widget.userId,
          userName: currentProfile?.name ?? 'User',
          initialWeight: currentProfile?.currentWeight,
          initialHeight: currentProfile?.height,
          onCalculated: () {
            // Reload data after calculation
            _loadData();
          },
        ),
      ),
    );
  }

  Color _getBMIStatusColor(BMIStatus? status) {
    if (status == null) return neutral50;

    switch (status) {
      case BMIStatus.underweight:
        return const Color(0xFF2196F3);
      case BMIStatus.normal:
        return successColor;
      case BMIStatus.overweight:
        return const Color(0xFFFF9800);
      case BMIStatus.obese:
        return errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Body Mass Index',
          style: TS.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 0,
      ),
      body: BlocBuilder<BMIBloc, BMIState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasUserProfile) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (state.hasError && !state.hasUserProfile) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.w,
                    color: neutral50,
                  ),
                  16.verticalSpace,
                  Text(
                    state.error!,
                    style: TS.bodyLarge.copyWith(color: neutral70),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: _loadData,
                  ),
                ],
              ),
            );
          }

          final userProfile = state.currentUserProfile;
          final bmiHistory = state.bmiHistory;

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: REdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current BMI Card
                  _buildCurrentBMICard(userProfile),

                  20.verticalSpace,

                  // Quick Actions
                  _buildQuickActions(),

                  24.verticalSpace,

                  // BMI History Section
                  _buildBMIHistorySection(bmiHistory),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentBMICard(userProfile) {
    final hasData = userProfile?.currentBMI != null;
    final bmiStatus = userProfile?.currentBMIStatus;
    final statusColor = _getBMIStatusColor(bmiStatus);

    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasData
            ? LinearGradient(
                colors: [
                  statusColor.withOpacity(0.1),
                  statusColor.withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [neutral10, neutral5],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasData ? statusColor.withOpacity(0.3) : neutral30,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Profile Info
          Row(
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: userProfile?.profileImageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          userProfile!.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 32.w,
                              color: primaryColor,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 32.w,
                        color: primaryColor,
                      ),
              ),
              16.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile?.name ?? 'Loading...',
                      style: TS.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                      ),
                    ),
                    4.verticalSpace,
                    Text(
                      userProfile?.role.displayName ?? '',
                      style: TS.bodyMedium.copyWith(
                        color: neutral70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          24.verticalSpace,

          if (hasData) ...[
            // BMI Status Badge
            Container(
              padding: REdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                bmiStatus!.label.toUpperCase(),
                style: TS.labelLarge.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            16.verticalSpace,

            // BMI Value
            Text(
              'Body Mass Index ${userProfile!.currentBMI!.toStringAsFixed(1)} Kg/M2',
              style: TS.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            16.verticalSpace,

            // Weight and Height Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Berat',
                    '${userProfile.currentWeight!.toStringAsFixed(1)} KG',
                    Icons.monitor_weight_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40.h,
                  color: neutral30,
                  margin: REdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Tinggi',
                    '${userProfile.height!.toStringAsFixed(0)} CM',
                    Icons.height_outlined,
                  ),
                ),
              ],
            ),

            if (userProfile.lastUpdated != null) ...[
              16.verticalSpace,
              Text(
                'Terakhir diperbarui: ${_formatDate(userProfile.lastUpdated!)}',
                style: TS.bodySmall.copyWith(
                  color: neutral50,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            // No Data State
            Icon(
              Icons.scale_outlined,
              size: 48.w,
              color: neutral50,
            ),
            16.verticalSpace,
            Text(
              'Belum ada data body mass index',
              style: TS.titleMedium.copyWith(
                color: neutral70,
                fontWeight: FontWeight.w600,
              ),
            ),
            8.verticalSpace,
            Text(
              'Hitung body mass index pertama Anda untuk melihat status kesehatan',
              style: TS.bodyMedium.copyWith(
                color: neutral50,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24.w,
          color: primaryColor,
        ),
        8.verticalSpace,
        Text(
          label,
          style: TS.bodySmall.copyWith(
            color: neutral50,
          ),
        ),
        4.verticalSpace,
        Text(
          value,
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        12.verticalSpace,
        UIButton(
          text: 'Hitung Body Mass Index',
          icon: Icon(Icons.calculate_outlined, size: 20.w),
          fullWidth: true,
          onPressed: _showBMICalculationDialog,
        ),
      ],
    );
  }

  Widget _buildBMIHistorySection(List bmiHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Body Mass Index',
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        12.verticalSpace,
        if (bmiHistory.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(24),
            decoration: BoxDecoration(
              color: neutral10,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: neutral30),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 48.w,
                  color: neutral50,
                ),
                16.verticalSpace,
                Text(
                  'Belum ada riwayat body mass index',
                  style: TS.bodyLarge.copyWith(
                    color: neutral70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                8.verticalSpace,
                Text(
                  'Mulai hitung body mass index untuk melihat riwayat perkembangan',
                  style: TS.bodyMedium.copyWith(
                    color: neutral50,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bmiHistory.length > 5 ? 5 : bmiHistory.length,
            separatorBuilder: (context, index) => 12.verticalSpace,
            itemBuilder: (context, index) {
              final record = bmiHistory[index];
              return _buildBMIHistoryItem(record);
            },
          ),
          if (bmiHistory.length > 5) ...[
            16.verticalSpace,
            UIButton(
              text: 'Lihat Semua Riwayat',
              buttonType: UIButtonType.outline,
              fullWidth: true,
              onPressed: () {
                // Navigate to full history page
                // TODO: Implement BMI history page
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBMIHistoryItem(dynamic record) {
    final statusColor = _getBMIStatusColor(record.status);

    return Container(
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: neutral30),
        boxShadow: [
          BoxShadow(
            color: neutral50.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 4.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          16.horizontalSpace,

          // BMI Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Body Mass Index ${record.bmi.toStringAsFixed(1)}',
                      style: TS.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    8.horizontalSpace,
                    Container(
                      padding:
                          REdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        record.status.label,
                        style: TS.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                4.verticalSpace,
                Text(
                  '${record.weight.toStringAsFixed(1)} kg • ${record.height.toStringAsFixed(0)} cm',
                  style: TS.bodyMedium.copyWith(color: neutral70),
                ),
                if (record.notes != null && record.notes.isNotEmpty) ...[
                  4.verticalSpace,
                  Text(
                    record.notes,
                    style: TS.bodySmall.copyWith(
                      color: neutral50,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(record.recordedAt),
                style: TS.bodySmall.copyWith(
                  color: neutral50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hari ini';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
