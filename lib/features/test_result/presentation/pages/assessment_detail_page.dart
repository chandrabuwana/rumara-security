import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../domain/entities/test_result_entity.dart';
import '../../domain/entities/test_summary_entity.dart';
import '../bloc/test_result_bloc.dart';
import '../widgets/test_result_header_widget.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Detail page for Assessment (Ujian Anggota)
class AssessmentDetailPage extends StatefulWidget {
  final String assessmentId;

  const AssessmentDetailPage({
    super.key,
    required this.assessmentId,
  });

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  @override
  void initState() {
    super.initState();
    // Trigger fetch assessment detail event
    Future.microtask(() {
      if (mounted) {
        final state = context.read<TestResultBloc>().state;
        if (state is TestResultLoaded && state.userId != null) {
          context.read<TestResultBloc>().add(
            FetchAssessmentDetailEvent(widget.assessmentId, state.userId!),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestResultBloc, TestResultState>(
      builder: (context, state) {
        if (state is TestResultLoading) {
          return AppScaffold(
            appBar: const RumaraAppBar(title: 'Detail Penilaian'),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is TestResultError) {
          return AppScaffold(
            appBar: const RumaraAppBar(title: 'Detail Penilaian'),
            child: Center(child: Text('Error: ${state.message}')),
          );
        }

        if (state is TestResultLoaded) {
          final assessmentDetailList = state.assessmentDetailList;
          final isLoading = state.isLoadingAssessmentDetail;
          final error = state.assessmentDetailError;

          if (isLoading && assessmentDetailList.isEmpty) {
            return AppScaffold(
              appBar: const RumaraAppBar(title: 'Detail Penilaian'),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (error != null && assessmentDetailList.isEmpty) {
            return AppScaffold(
              appBar: const RumaraAppBar(title: 'Detail Penilaian'),
              child: Center(child: Text('Error: $error')),
            );
          }

          // Calculate summary from assessment detail list
          final passedCount = assessmentDetailList.where((r) => r.status == TestKelulusanStatus.lulus).length;
          final failedCount = assessmentDetailList.where((r) => r.status == TestKelulusanStatus.tidakLulus).length;
          final averageScore = assessmentDetailList.isEmpty
              ? 0.0
              : assessmentDetailList.map((r) => r.nilaiTest).reduce((a, b) => a + b) / assessmentDetailList.length;
          final minValue = assessmentDetailList.isEmpty
              ? 0
              : assessmentDetailList.map((r) => r.nilaiKKM).reduce((a, b) => a < b ? a : b);

          return AppScaffold(
            appBar: const RumaraAppBar(title: 'Detail Penilaian'),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Component 1: Summary Header
                  TestResultHeaderWidget(
                    assessmentDetailList: assessmentDetailList,
                    summary: TestSummaryEntity(
                      jumlahPesertaLulus: passedCount,
                      jumlahPesertaTidakLulus: failedCount,
                      nilaiRataRata: averageScore,
                      nilaiMinimal: minValue.toDouble(),
                      picPeserta: assessmentDetailList.isNotEmpty ? assessmentDetailList.first.keterangan ?? '-' : '-',
                      tipeTest: assessmentDetailList.isNotEmpty ? assessmentDetailList.first.tipeTest : 'Ujian',
                      tanggalPelaksanaan: assessmentDetailList.isNotEmpty ? assessmentDetailList.first.tanggalTest : null,
                      namaPenguji: '-',
                      anggotaList: assessmentDetailList.map((r) => r.userId).toList(),
                    ),
                    userRole: UserRole.pjo,
                    showPassFailCount: true,
                  ),

                  16.verticalSpace,

                  // Component 2: List of Anggota (participants with their results)
                  Container(
                    margin: REdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Table header with icon and title
                        Container(
                          padding: REdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(8.r),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: primaryColor,
                                size: 24.w,
                              ),
                              12.horizontalSpace,
                              Text(
                                'Daftar Peserta',
                                style: TS.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: neutral90,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table column headers
                        Container(
                          padding: REdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Nama',
                                  style: TS.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neutral70,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Nilai',
                                  style: TS.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neutral70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Nilai Remedial',
                                  style: TS.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neutral70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Status',
                                  style: TS.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neutral70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table rows
                        if (assessmentDetailList.isEmpty)
                          Padding(
                            padding: REdgeInsets.all(16),
                            child: Text(
                              'Tidak ada data peserta',
                              style: TS.bodySmall.copyWith(color: neutral70),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...List.generate(
                            assessmentDetailList.length,
                            (index) => _buildParticipantRow(assessmentDetailList[index], index == assessmentDetailList.length - 1),
                          ),
                      ],
                    ),
                  ),

                  32.verticalSpace,
                ],
              ),
            ),
          );
        }

        return AppScaffold(
          appBar: const RumaraAppBar(title: 'Detail Penilaian'),
          child: const Center(child: Text('Unknown state')),
        );
      },
    );
  }

  Widget _buildParticipantRow(TestResultEntity participant, bool isLast) {
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: const Color(0xFFE0E0E0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              participant.userFullname ?? participant.userId,
              style: TS.bodySmall.copyWith(
                color: neutral90,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${participant.nilaiTest}',
              style: TS.bodySmall.copyWith(
                color: neutral90,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${participant.remedialGrade ?? '-'}',
              style: TS.bodySmall.copyWith(
                color: neutral90,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              participant.status == TestKelulusanStatus.lulus
                  ? 'Lulus'
                  : participant.status == TestKelulusanStatus.tidakLulus
                      ? 'Tidak Lulus'
                      : 'Belum Dinilai',
              style: TS.bodySmall.copyWith(
                color: participant.status == TestKelulusanStatus.lulus
                    ? successColor
                    : participant.status == TestKelulusanStatus.tidakLulus
                        ? errorColor
                        : neutral70,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
