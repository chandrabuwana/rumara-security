import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/constants/enums.dart';
import '../bloc/bmi_bloc.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Page detail untuk melihat profil dan BMI user (untuk role non-anggota)
class BMIDetailPage extends StatefulWidget {
  final dynamic userProfile;
  final UserRole currentUserRole;

  const BMIDetailPage({
    Key? key,
    required this.userProfile,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<BMIDetailPage> createState() => _BMIDetailPageState();
}

class _BMIDetailPageState extends State<BMIDetailPage> {
  BMIBloc get _bmiBloc => context.read<BMIBloc>();
  bool _hasInitialLoad = false; // Flag untuk mencegah multiple initial loads

  @override
  void initState() {
    super.initState();
    _loadBMIHistory();
  }

  void _loadBMIHistory() {
    // Load user profile dengan data BMI dan history hanya sekali
    if (_hasInitialLoad) {
      print('⏭️ BMIDetailPage: Skip _loadBMIHistory - _hasInitialLoad=true');
      return; // Skip jika sudah pernah load
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (_hasInitialLoad) {
        print('⏭️ BMIDetailPage: Skip _loadBMIHistory - _hasInitialLoad=true (double check)');
        return; // Double check
      }
      
      final state = _bmiBloc.state;
      bool shouldLoadProfile = false;
      bool shouldLoadHistory = false;
      
      // Load user profile dengan data BMI (dari Bmi/list API)
      // Hanya load jika user berbeda atau belum ada BMI data dan tidak sedang loading
      // DAN belum ada profile untuk user ini di state
      if (state.currentUserProfile?.id != widget.userProfile.id) {
        // User berbeda atau belum ada profile
        if (!state.isLoading) {
          shouldLoadProfile = true;
        } else {
          print('⏭️ BMIDetailPage: Skip load profile - already loading');
        }
      } else {
        // Sudah ada profile untuk user ini
        print('⏭️ BMIDetailPage: Skip load profile - already has profile for user ${widget.userProfile.id}');
      }
      
      // Load BMI history hanya jika belum pernah load untuk user ini
      // Check: bmiHistoryUserId harus null atau berbeda dengan userProfile.id
      if (state.bmiHistoryUserId != widget.userProfile.id) {
        // Belum pernah load history untuk user ini
        if (!state.isLoading) {
          shouldLoadHistory = true;
          print('🔄 BMIDetailPage: Will load history - history not loaded for user ${widget.userProfile.id}');
        } else {
          print('⏭️ BMIDetailPage: Skip load history - already loading');
        }
      } else {
        // Sudah pernah load history untuk user ini (meskipun kosong)
        print('⏭️ BMIDetailPage: Skip load history - already loaded history for user ${widget.userProfile.id} (${state.bmiHistory.length} records, bmiHistoryUserId=${state.bmiHistoryUserId})');
      }
      
      if (shouldLoadProfile || shouldLoadHistory) {
        _hasInitialLoad = true;
        if (shouldLoadProfile) {
          print('🔄 BMIDetailPage: Loading user profile for ${widget.userProfile.id}');
          _bmiBloc.add(BMIGetUserProfile(widget.userProfile.id));
        }
        if (shouldLoadHistory) {
          print('🔄 BMIDetailPage: Loading BMI history for ${widget.userProfile.id}');
          _bmiBloc.add(BMILoadHistory(widget.userProfile.id));
        }
      } else {
        print('⏭️ BMIDetailPage: Skip all loads - no need to load');
        _hasInitialLoad = true; // Set flag meskipun tidak load untuk mencegah retry
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: const RumaraAppBar(title: 'Detail Body Mass Index'),
      body: BlocBuilder<BMIBloc, BMIState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Card with BMI Info
                _buildUserProfileCard(),

                24.verticalSpace,

                // BMI History Section
                if (state.bmiHistory.isNotEmpty)
                  Padding(
                    padding: REdgeInsets.symmetric(horizontal: 16),
                    child: _buildBMIHistorySection(state.bmiHistory, state.currentUserProfile ?? widget.userProfile),
                  ),

                24.verticalSpace,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return BlocBuilder<BMIBloc, BMIState>(
      builder: (context, state) {
        // Use currentUserProfile from state if available (has BMI data), otherwise use widget.userProfile
        // If loading, show loading state
        if (state.isLoading && state.currentUserProfile == null) {
          return const _BMIProfileSkeleton();
        }
        
        final userProfile = state.currentUserProfile ?? widget.userProfile;
        final hasData = userProfile.currentBMI != null;
        final bmiStatus = userProfile.currentBMIStatus;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: hasData
            ? LinearGradient(
                colors: [
                  const Color(0xFFFFF5F5),
                  const Color(0xFFFFF9F9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : LinearGradient(
                colors: [neutral10, neutral5],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: Column(
        children: [
          32.verticalSpace,
          if (hasData) ...[
            // Profile Photo
            Container(
              width: 130.w,
              height: 130.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: white, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: neutral50.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: userProfile.profileImageUrl != null
                    ? Image.network(
                        userProfile.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: neutral20,
                            child: Icon(
                              Icons.person,
                              size: 60.w,
                              color: neutral50,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: neutral20,
                        child: Icon(
                          Icons.person,
                          size: 60.w,
                          color: neutral50,
                        ),
                      ),
              ),
            ),

            24.verticalSpace,

            // BMI Status - Map to display text
            Container(
              padding: REdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C5F7C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Text(
                (userProfile.bmiCategory != null && userProfile.bmiCategory!.isNotEmpty)
                    ? userProfile.bmiCategory!
                    : _getBMIStatusDisplayText(bmiStatus!),
                style: TS.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C5F7C),
                  letterSpacing: 1.5,
                  fontSize: 26.sp,
                ),
              ),
            ),

            20.verticalSpace,

            // BMI Value
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TS.titleLarge.copyWith(
                  color: primaryColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Your BMI is '),
                  TextSpan(
                    text: userProfile.currentBMI!.toStringAsFixed(1).replaceAll('.', ','),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                    ),
                  ),
                  const TextSpan(text: ' Kg/M2'),
                ],
              ),
            ),

            32.verticalSpace,

            // Height, Weight, Updated Info
            Container(
              margin: REdgeInsets.symmetric(horizontal: 24),
              padding: REdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      'Height',
                      '${userProfile.height!.toStringAsFixed(1).replaceAll('.', ',')} CM',
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Weight',
                      '${userProfile.currentWeight!.toStringAsFixed(1).replaceAll('.', ',')} KG',
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Updated',
                      userProfile.lastUpdated != null
                          ? _formatDateShort(userProfile.lastUpdated!)
                          : (state.bmiHistory.isNotEmpty 
                              ? _formatDateShort(state.bmiHistory.first.recordedAt)
                              : '-'),
                    ),
                  ),
                ],
              ),
            ),

            32.verticalSpace,

            // Recommendation Section
            Container(
              width: double.infinity,
              margin: REdgeInsets.symmetric(horizontal: 16),
              padding: REdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFF5F5),
                    const Color(0xFFFFF9F9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: const Color(0xFF2C5F7C),
                        size: 20.w,
                      ),
                      8.horizontalSpace,
                      Text(
                        'Recommendation',
                        style: TS.titleMedium.copyWith(
                          color: const Color(0xFF2C5F7C),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                  16.verticalSpace,
                  Text(
                    // Prioritas: 1. Dari API, 2. Fallback ke default recommendation
                    userProfile.recommendation ?? _getRecommendation(bmiStatus),
                    style: TS.bodyMedium.copyWith(
                      color: primaryColor,
                      height: 1.6,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),

            24.verticalSpace,
          ] else ...[
            // No Data State
            // Profile photo with ring decoration
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 136.w,
                  height: 136.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: neutral20.withOpacity(0.4),
                  ),
                ),
                Container(
                  width: 116.w,
                  height: 116.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: neutral20,
                  ),
                  child: userProfile.profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            userProfile.profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 55.w, color: neutral50),
                          ),
                        )
                      : Icon(Icons.person, size: 55.w, color: neutral50),
                ),
              ],
            ),

            20.verticalSpace,

            Text(
              userProfile.name,
              style: TS.titleLarge.copyWith(
                color: neutral90,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
              textAlign: TextAlign.center,
            ),

            10.verticalSpace,

            Container(
              padding: REdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: neutral10,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: neutral20, width: 1),
              ),
              child: Text(
                'Belum ada data BMI',
                style: TS.bodySmall.copyWith(
                  color: neutral50,
                  fontSize: 12.sp,
                ),
              ),
            ),

            36.verticalSpace,

            // Triple ring scale illustration
            SizedBox(
              width: 160.w,
              height: 160.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160.w,
                    height: 160.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.04),
                    ),
                  ),
                  Container(
                    width: 124.w,
                    height: 124.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.07),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 92.w,
                    height: 92.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF0F0), Color(0xFFFFF8F8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.12),
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      size: 44.w,
                      color: primaryColor.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),

            24.verticalSpace,

            Text(
              'Pengukuran BMI Belum Tersedia',
              style: TS.titleLarge.copyWith(
                color: neutral90,
                fontWeight: FontWeight.bold,
                fontSize: 19.sp,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),

            10.verticalSpace,

            Text(
              'Lakukan pengukuran pertama untuk\nmelihat status kesehatan tubuh',
              style: TS.bodyMedium.copyWith(
                color: neutral50,
                height: 1.6,
                fontSize: 13.sp,
              ),
              textAlign: TextAlign.center,
            ),

            28.verticalSpace,

            // BMI info card
            Container(
              margin: REdgeInsets.symmetric(horizontal: 16),
              padding: REdgeInsets.all(20),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: neutral20, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: neutral50.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // BMI formula
                  Container(
                    width: double.infinity,
                    padding: REdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C5F7C).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'BMI  =  Berat (kg)  ÷  Tinggi² (m)',
                      textAlign: TextAlign.center,
                      style: TS.bodyMedium.copyWith(
                        color: const Color(0xFF2C5F7C),
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  16.verticalSpace,

                  // Category chips
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildBMIRangeChip('< 18.5', 'Kurus', const Color(0xFF42A5F5)),
                      _buildBMIRangeChip('18.5–24.9', 'Normal', const Color(0xFF66BB6A)),
                      _buildBMIRangeChip('25–29.9', 'Gemuk', const Color(0xFFFFA726)),
                      _buildBMIRangeChip('≥ 30', 'Obesitas', const Color(0xFFEF5350)),
                    ],
                  ),
                ],
              ),
            ),

            32.verticalSpace,
          ],
        ],
      ),
    );
      },
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TS.bodyMedium.copyWith(
            color: const Color(0xFF2C5F7C),
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
        10.verticalSpace,
        Text(
          value,
          style: TS.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontSize: 15.sp,
          ),
        ),
      ],
    );
  }

  String _getRecommendation(BMIStatus? status) {
    if (status == null) return '';

    switch (status) {
      case BMIStatus.underweight:
        return 'Increase calorie intake with nutritious foods. Consider consulting a nutritionist for a healthy weight gain plan.';
      case BMIStatus.normal:
        return 'Stay healthy, keep strong, happy tummy happy me. running, tanning, swimming, Let\'s exercise :)';
      case BMIStatus.overweight:
        return 'Maintain a balanced diet and regular exercise. Consider consulting a healthcare professional for personalized advice.';
      case BMIStatus.obese:
        return 'It\'s important to consult with a healthcare professional. Focus on gradual lifestyle changes with proper guidance.';
    }
  }

  String _formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getBMIStatusDisplayText(BMIStatus status) {
    // Map BMI status to display text based on image
    switch (status) {
      case BMIStatus.underweight:
        return 'UNDERWEIGHT';
      case BMIStatus.normal:
        return 'EXCELLENT'; // Based on image, normal shows as "EXCELLENT"
      case BMIStatus.overweight:
        return 'OVERWEIGHT';
      case BMIStatus.obese:
        return 'OBESE';
    }
  }

  Widget _buildBMIRangeChip(String range, String label, Color color) {
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          5.horizontalSpace,
          Text(
            '$range  $label',
            style: TextStyle(
              color: color.withOpacity(0.85),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMIHistorySection(List bmiHistory, dynamic currentUserProfile) {
    if (bmiHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show all history records except the first one (which is shown in main card)
    // The first record in history is the latest one, which is displayed in the main card
    // So we skip the first record and show the rest
    final filteredHistory = bmiHistory.length > 1 
        ? bmiHistory.skip(1).toList() 
        : [];

    if (filteredHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredHistory.length,
          separatorBuilder: (context, index) => 0.verticalSpace,
          itemBuilder: (context, index) {
            final record = filteredHistory[index];
            return _buildBMIHistoryItem(record);
          },
        ),
      ],
    );
  }

  Widget _buildBMIHistoryItem(dynamic record) {
    return Container(
      margin: REdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF5F5),
            const Color(0xFFFFF9F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: REdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Section - Status and Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C5F7C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          record.status.label,
                          style: TS.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C5F7C),
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                      16.verticalSpace,
                      Row(
                        children: [
                          SizedBox(
                            width: 60.w,
                            child: Text(
                              'Height',
                              style: TS.bodySmall.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          Text(
                            '${record.height.toStringAsFixed(1).replaceAll('.', ',')} CM',
                            style: TS.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                      8.verticalSpace,
                      Row(
                        children: [
                          SizedBox(
                            width: 60.w,
                            child: Text(
                              'Weight',
                              style: TS.bodySmall.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          Text(
                            '${record.weight.toStringAsFixed(1).replaceAll('.', ',')} Kg',
                            style: TS.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                16.horizontalSpace,

                // Right Section - BMI Value
                Container(
                  padding: REdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '${record.bmi.toStringAsFixed(1).replaceAll('.', ',')}\nKg/M2',
                    textAlign: TextAlign.center,
                    style: TS.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 16.sp,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recommendation Section
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(20),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF2C5F7C),
                      size: 18.w,
                    ),
                    8.horizontalSpace,
                    Text(
                      'Recommendation',
                      style: TS.bodyMedium.copyWith(
                        color: const Color(0xFF2C5F7C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                12.verticalSpace,
                Text(
                  // Prioritas: 1. Dari notes (API), 2. Fallback ke default
                  record.notes ?? _getRecommendation(record.status),
                  style: TS.bodySmall.copyWith(
                    color: primaryColor,
                    height: 1.5,
                    fontSize: 13.sp,
                  ),
                ),
                12.verticalSpace,
                // Updated Date
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: neutral10,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Updated ${_formatDateShort(record.recordedAt)}',
                      style: TS.bodySmall.copyWith(
                        color: neutral50,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BMIProfileSkeleton extends StatefulWidget {
  const _BMIProfileSkeleton();

  @override
  State<_BMIProfileSkeleton> createState() => _BMIProfileSkeletonState();
}

class _BMIProfileSkeletonState extends State<_BMIProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final shimmer = Color.lerp(
          const Color(0xFFECECEC),
          const Color(0xFFF6F6F6),
          _ctrl.value,
        )!;
        return Container(
          width: double.infinity,
          padding: REdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            children: [
              // Avatar circle
              Container(
                width: 116.w,
                height: 116.w,
                decoration: BoxDecoration(
                  color: shimmer,
                  shape: BoxShape.circle,
                ),
              ),
              24.verticalSpace,
              // Name line
              Container(
                width: 160.w,
                height: 14.h,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(7.r),
                ),
              ),
              10.verticalSpace,
              Container(
                width: 100.w,
                height: 10.h,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(5.r),
                ),
              ),
              32.verticalSpace,
              // BMI value box
              Container(
                width: 200.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              24.verticalSpace,
              // Stats row
              Container(
                width: double.infinity,
                height: 72.h,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              24.verticalSpace,
              // Recommendation box
              Container(
                width: double.infinity,
                height: 100.h,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
