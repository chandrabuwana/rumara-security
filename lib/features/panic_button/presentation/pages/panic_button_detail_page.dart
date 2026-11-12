import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/utils/image_compress_util.dart';
import '../../../../core/utils/user_role_helper.dart';
import '../../data/models/panic_button_edit_request.dart';
import '../../domain/entities/panic_button_history_item.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_event.dart';
import '../bloc/panic_button_state.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicButtonDetailPage extends StatefulWidget {
  final String incidentId;

  const PanicButtonDetailPage({
    super.key,
    required this.incidentId,
  });

  @override
  State<PanicButtonDetailPage> createState() => _PanicButtonDetailPageState();
}

class _PanicButtonDetailPageState extends State<PanicButtonDetailPage> {
  final TextEditingController _tindakanPenyelesaianController =
      TextEditingController();
  final TextEditingController _buktiPenyelesaianController =
      TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _proofImage;
  UserRole? _currentUserRole;
  bool _isLoadingRole = true;

  Future<String> _convertImageToBase64(File imageFile) async {
    final compressed =
        await ImageCompressUtil.ensureMax1MbIfImage(imageFile.path);
    final bytes = await compressed.readAsBytes();
    return base64Encode(bytes);
  }

  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PanicButtonBloc>().add(
              LoadPanicButtonDetailEvent(widget.incidentId),
            );
      }
    });
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleHelper.getUserRole();
    setState(() {
      _currentUserRole = role;
      _isLoadingRole = false;
    });
  }

  @override
  void dispose() {
    _tindakanPenyelesaianController.dispose();
    _buktiPenyelesaianController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  bool get _isPengawas {
    return _currentUserRole == UserRole.pengawas;
  }

  bool _isOpenStatus(String status) => status.toUpperCase() == 'OPEN';

  bool _isRevisedStatus(String status) {
    final s = status.toUpperCase();
    return s == 'REVISI' || s == 'REVISION' || s == 'REVISED';
  }

  bool _isCompletedStatus(String status) {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'DONE';
  }

  bool _isVerifiedStatus(String status) => status.toUpperCase() == 'VERIFIED';

  bool _canEditCompletion(PanicButtonHistoryItem item) {
    final role = _currentUserRole;
    if (role == null) return false;
    final status = item.status;

    final eligibleRole = role == UserRole.pjo ||
        role == UserRole.deputy ||
        role == UserRole.pengawas;
    if (!eligibleRole) return false;

    // Pengawas: OPEN only (REVISED is view-only per requirement)
    if (role == UserRole.pengawas) {
      return _isOpenStatus(status);
    }

    // PJO/Deputy: OPEN or REVISED
    return _isOpenStatus(status) || _isRevisedStatus(status);
  }

  bool _canMarkCompleted(PanicButtonHistoryItem item) =>
      _canEditCompletion(item);

  bool _canSupervisorVerifyOrRevise(PanicButtonHistoryItem item) {
    if (!_isPengawas) return false;
    return _isCompletedStatus(item.status);
  }

  bool _canEditFeedback(PanicButtonHistoryItem item) =>
      _canSupervisorVerifyOrRevise(item);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const RumaraAppBar(title: 'Detail Tombol Darurat'),
      body: SafeArea(
        child: BlocListener<PanicButtonBloc, PanicButtonState>(
          listener: (context, state) {
            if (state.detailItem != null) {
              // Pre-fill editable fields if they exist
              final item = state.detailItem!;
              final action = item.action?.trim();
              if (action != null &&
                  action.isNotEmpty &&
                  _tindakanPenyelesaianController.text.isEmpty) {
                _tindakanPenyelesaianController.text = action;
              }

              final feedback = item.feedback?.trim();
              if (feedback != null &&
                  feedback.isNotEmpty &&
                  _feedbackController.text.isEmpty) {
                _feedbackController.text = feedback;
              }
            }

            // Handle verification submission
            if (state.submitVerificationSuccess) {
              // Navigate back to history page and reload
              Navigator.pop(
                  context, true); // Pass true to indicate refresh needed
            }

            if (state.submitVerificationError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.submitVerificationError!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<PanicButtonBloc, PanicButtonState>(
            builder: (context, state) {
              if (state.isLoadingDetail || _isLoadingRole) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state.detailErrorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48.sp,
                        color: Colors.red,
                      ),
                      16.verticalSpace,
                      Text(
                        state.detailErrorMessage!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      16.verticalSpace,
                      ElevatedButton(
                        onPressed: () {
                          context.read<PanicButtonBloc>().add(
                                LoadPanicButtonDetailEvent(widget.incidentId),
                              );
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              final historyItem = state.detailItem;
              if (historyItem == null) {
                return const Center(
                  child: Text('Data tidak ditemukan'),
                );
              }

              final canEditCompletion = _canEditCompletion(historyItem);
              final canMarkCompleted = _canMarkCompleted(historyItem);
              final canSupervisorVerifyOrRevise =
                  _canSupervisorVerifyOrRevise(historyItem);
              final canEditFeedback = _canEditFeedback(historyItem);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: REdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Status'),
                                8.verticalSpace,
                                _buildGreyField(historyItem.status),
                                12.verticalSpace,
                                _buildFieldLabel('Jenis Keadaan Darurat'),
                                8.verticalSpace,
                                _buildGreyField(
                                    historyItem.incidentTypeName ?? '-'),
                                12.verticalSpace,
                                _buildFieldLabel('Lokasi Kejadian'),
                                8.verticalSpace,
                                _buildGreyField(historyItem.areaName ?? '-'),
                                12.verticalSpace,
                                _buildFieldLabel('Kejadian'),
                                8.verticalSpace,
                                _buildGreyField(historyItem.description,
                                    isMultiline: true),
                                12.verticalSpace,
                                if (historyItem.files.isNotEmpty) ...[
                                  _buildFieldLabel('Foto Kejadian'),
                                  8.verticalSpace,
                                  _buildPhotoGrid(historyItem.files),
                                  12.verticalSpace,
                                ],
                                _buildFieldLabel('Tindakan Yang Dibutuhkan'),
                                8.verticalSpace,
                                _buildGreyField(
                                    historyItem.resolveAction?.trim().isNotEmpty == true
                                        ? historyItem.resolveAction!
                                        : '-',
                                    isMultiline: true),
                                12.verticalSpace,
                                _buildFieldLabel('Pelapor'),
                                8.verticalSpace,
                                _buildGreyField(_formatReporter(historyItem)),
                                12.verticalSpace,
                                _buildFieldLabel('Tanggal Kejadian'),
                                8.verticalSpace,
                                _buildGreyField(
                                    _formatIncidentDate(historyItem)),
                                12.verticalSpace,
                                _buildFieldLabel('Tindakan Penyelesaian'),
                                8.verticalSpace,
                                canEditCompletion
                                    ? _buildEditableField(
                                        'Tindakan Penyelesaian',
                                        _tindakanPenyelesaianController,
                                        maxLines: 4,
                                        hintText:
                                            'Masukkan tindakan penyelesaian...',
                                      )
                                    : _buildGreyField(
                                        historyItem.action
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? historyItem.action!.trim()
                                            : '-',
                                        isMultiline: true),
                                12.verticalSpace,
                                _buildBuktiPenyelesaianField(
                                    canEdit: canEditCompletion),
                                12.verticalSpace,
                                _buildFieldLabel('Diselesaikan Oleh'),
                                8.verticalSpace,
                                _buildGreyField(_formatSolver(historyItem)),
                                12.verticalSpace,
                                _buildFieldLabel('Tanggal Penyelesaian'),
                                8.verticalSpace,
                                _buildGreyField(_formatSolverDate(historyItem)),
                                12.verticalSpace,
                                _buildFieldLabel('Umpan Balik'),
                                8.verticalSpace,
                                _buildFeedbackField(historyItem,
                                    canEdit: canEditFeedback),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Button
                  if (canMarkCompleted || canSupervisorVerifyOrRevise)
                    Container(
                      padding: REdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Container(
                              width: 52.w,
                              height: 52.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                    color: Colors.red[700]!, width: 1.5),
                                color: Colors.white,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Fitur panggilan akan segera tersedia')),
                                  );
                                },
                                icon: Icon(Icons.call,
                                    color: Colors.red[700], size: 22.sp),
                              ),
                            ),
                            12.horizontalSpace,
                            if (canSupervisorVerifyOrRevise) ...[
                              Expanded(
                                child: BlocBuilder<PanicButtonBloc,
                                    PanicButtonState>(
                                  builder: (context, state) {
                                    final isSubmitting =
                                        state.isSubmittingVerification;
                                    return OutlinedButton(
                                      onPressed: (!isSubmitting)
                                          ? () => _showRevisiConfirmDialog(
                                              context, historyItem)
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        padding:
                                            REdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(
                                            color: Colors.orange[700]!,
                                            width: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      child: isSubmitting
                                          ? SizedBox(
                                              width: 20.w,
                                              height: 20.h,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Colors.orange[700]!),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.edit,
                                                    size: 18.sp,
                                                    color: Colors.orange[700]),
                                                8.horizontalSpace,
                                                Text(
                                                  'Revisi',
                                                  style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    );
                                  },
                                ),
                              ),
                              12.horizontalSpace,
                            ],
                            Expanded(
                              flex: 1,
                              child: BlocBuilder<PanicButtonBloc,
                                  PanicButtonState>(
                                builder: (context, state) {
                                  final isSubmitting =
                                      state.isSubmittingVerification;
                                  return ElevatedButton(
                                    onPressed: (!isSubmitting &&
                                            (canMarkCompleted ||
                                                canSupervisorVerifyOrRevise))
                                        ? () => _showConfirmDialog(
                                            context, historyItem)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      padding:
                                          REdgeInsets.symmetric(vertical: 16),
                                      elevation: 4,
                                      shadowColor:
                                          Colors.red[700]!.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                      ),
                                    ),
                                    child: isSubmitting
                                        ? SizedBox(
                                            width: 20.w,
                                            height: 20.h,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            canSupervisorVerifyOrRevise
                                                ? 'Verifikasi'
                                                : 'Tandai Sebagai Selesai',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildGreyField(String value, {bool isMultiline = false}) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          height: isMultiline ? 1.45 : 1.2,
        ),
      ),
    );
  }

  Widget _buildFeedbackField(PanicButtonHistoryItem item,
      {required bool canEdit}) {
    if (canEdit) {
      return Container(
        width: double.infinity,
        padding: REdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextField(
          controller: _feedbackController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '....',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      );
    }

    final feedbackValue =
        (item.feedback != null && item.feedback!.trim().isNotEmpty)
            ? item.feedback!.trim()
            : '-';
    return _buildGreyField(feedbackValue, isMultiline: true);
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: REdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Gagal memuat gambar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(PanicButtonHistoryItem item) {
    final statusColor = _getStatusColor(item.statusColor);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: REdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID : ${item.formattedId}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      10.verticalSpace,
                      Text(
                        item.incidentTypeName ?? '-',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      6.verticalSpace,
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16.sp, color: Colors.grey[700]),
                          6.horizontalSpace,
                          Expanded(
                            child: Text(
                              item.areaName ?? '-',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                12.horizontalSpace,
                Container(
                  padding: REdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            12.verticalSpace,
            Text(
              _formatIncidentDate(item),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: REdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            size: 20.sp,
            color: Colors.red[700],
          ),
        ),
        12.horizontalSpace,
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    IconData? icon,
    required String label,
    required String value,
    Color? statusColor,
    bool isMultiline = false,
  }) {
    return Container(
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: REdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                size: 18.sp,
                color: Colors.red[700],
              ),
            ),
            12.horizontalSpace,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
                8.verticalSpace,
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: statusColor ?? Colors.black87,
                    fontWeight:
                        statusColor != null ? FontWeight.w600 : FontWeight.w500,
                    height: isMultiline ? 1.5 : 1.3,
                  ),
                  maxLines: isMultiline ? null : 2,
                  overflow: isMultiline
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hintText,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Row(
            children: [
              Container(
                padding: REdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: Colors.blue[700],
                ),
              ),
              12.horizontalSpace,
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ] else
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        12.verticalSpace,
        Container(
          padding: REdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Colors.blue[300]!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            enabled: true,
            decoration: InputDecoration(
              hintText: hintText ?? '....',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14.sp,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuktiPenyelesaianField({required bool canEdit}) {
    final detailItem = context.read<PanicButtonBloc>().state.detailItem;
    final canViewEvidence =
        _currentUserRole == UserRole.pjo || _currentUserRole == UserRole.pengawas;
    final evidence = detailItem?.evidenceFile;
    final isCompleted = detailItem != null && _isCompletedStatus(detailItem.status);
    final hasEvidenceUrl = evidence != null && evidence.url.trim().isNotEmpty;
    final isVerified = detailItem != null && detailItem.status.toUpperCase() == 'VERIFIED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: REdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.attach_file,
                size: 18.sp,
                color: Colors.green[700],
              ),
            ),
            12.horizontalSpace,
            Text(
              'Bukti Penyelesaian',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        12.verticalSpace,
        Container(
          padding: REdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canEdit ? Colors.white : Colors.grey[50],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: canEdit ? Colors.green[300]! : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: canEdit
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  canEdit ? 'Tambahkan foto bukti penyelesaian' : '-',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (canEdit) ...[
                8.horizontalSpace,
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt,
                        color: Colors.green[700], size: 22.sp),
                    onPressed: () => _showImagePickerDialog(),
                    tooltip: 'Ambil Foto',
                  ),
                ),
                4.horizontalSpace,
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.attach_file,
                        color: Colors.green[700], size: 22.sp),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Fitur attachment akan segera tersedia')),
                      );
                    },
                    tooltip: 'Lampirkan File',
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canViewEvidence && hasEvidenceUrl) ...[
          8.verticalSpace,
          GestureDetector(
            onTap: () => _showImagePreview(evidence.url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                evidence.url,
                width: 100.w,
                height: 100.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100.w,
                    height: 100.h,
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.broken_image, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (canViewEvidence && isVerified && !hasEvidenceUrl) ...[
          8.verticalSpace,
          Text(
            'Tidak terdapat photo.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
        if (_proofImage != null) ...[
          8.verticalSpace,
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.file(
                  _proofImage!,
                  width: 100.w,
                  height: 100.h,
                  fit: BoxFit.cover,
                ),
              ),
              if (canEdit)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _proofImage = null;
                      });
                    },
                    child: Container(
                      padding: REdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoGrid(List<PanicButtonHistoryFile> files) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.0,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showImagePreview(file.url),
                    child: Image.network(
                      file.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red[700]!),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.grey[400],
                              size: 32.sp,
                            ),
                            8.verticalSpace,
                            Text(
                              'Gagal memuat',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Gradient overlay for better visibility
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _proofImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showConfirmDialog(BuildContext context, PanicButtonHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: Colors.red[700],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            16.verticalSpace,
            Text(
              'Apakah Anda yakin menyelesaikan tindakan ini?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            24.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: REdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red[700]!),
                    ),
                    child: Text(
                      'Tidak',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitPrimaryAction(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: REdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Ya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitPrimaryAction(PanicButtonHistoryItem item) {
    if (_canSupervisorVerifyOrRevise(item)) {
      _submitVerify(item);
      return;
    }

    if (_canMarkCompleted(item)) {
      _submitMarkCompleted(item);
      return;
    }
  }

  void _submitMarkCompleted(PanicButtonHistoryItem item) {
    final completionAction = _tindakanPenyelesaianController.text.trim();
    if (completionAction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tindakan penyelesaian wajib diisi')),
      );
      return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bukti penyelesaian (foto) wajib diisi')),
      );
      return;
    }

    () async {
      try {
        final solverId =
            await SecurityManager.readSecurely(AppConstants.userIdKey);
        final now = DateTime.now().toIso8601String();

        // Debug prints disabled temporarily
        // print('');
        // print('🎯 ========================================');
        // print('🎯 [PanicButtonDetailPage] SUBMIT MARK COMPLETED');
        // print('🎯 ========================================');
        // print('🎯 SolverDate being sent: $now');
        // print('🎯 SolverId being sent: $solverId');
        // print('🎯 ========================================');
        // print('');

        final proofImage = _proofImage!;
        final fileName = path.basename(proofImage.path);
        final base64 = await _convertImageToBase64(proofImage);
        final mimeType = _getMimeType(fileName);
        final fileSize = await proofImage.length();

        final request = PanicButtonEditRequest(
          id: item.id,
          action: completionAction,
          areasId: item.areasId,
          description: item.description,
          feedback: item.feedback,
          idIncidentType: item.idIncidentType,
          reporterDate: (item.reporterDate ?? item.createDate ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          reporterId: item.reporterId,
          resolveAction: item.resolveAction,
          solverDate: now,
          solverId: (solverId != null && solverId.isNotEmpty) ? solverId : null,
          status: 'COMPLETED',
          files: const [],
          evidenceFile: PanicButtonEditFile(
            filename: fileName,
            mimeType: mimeType,
            base64: base64,
            fileSize: fileSize,
          ),
        );

        // Debug prints disabled temporarily
        // print('');
        // print('🎯 ========================================');
        // print('🎯 [PanicButtonDetailPage] REQUEST CREATED');
        // print('🎯 ========================================');
        // print('🎯 Request solverDate: ${request.solverDate}');
        // print('🎯 Expected solverDate (now): $now');
        // print('🎯 Match: ${request.solverDate == now}');
        // print('🎯 ========================================');
        // print('');

        if (!mounted) return;
        context.read<PanicButtonBloc>().add(
              SubmitPanicButtonCompletionEvent(
                id: item.id,
                request: request,
              ),
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses bukti penyelesaian: $e')),
        );
      }
    }();
  }

  void _submitVerify(PanicButtonHistoryItem item) {
    final notes = _feedbackController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Umpan balik wajib diisi')),
      );
      return;
    }
    context.read<PanicButtonBloc>().add(
          SubmitPanicButtonVerificationEvent(
            id: item.id,
            status: 'VERIFIED',
            notes: notes.isNotEmpty ? notes : null,
          ),
        );
  }

  void _submitRevisi(PanicButtonHistoryItem item) {
    // Pengawas: notes dari field Feedback
    final notes = _feedbackController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Umpan balik wajib diisi')),
      );
      return;
    }

    context.read<PanicButtonBloc>().add(
          SubmitPanicButtonVerificationEvent(
            id: item.id,
            status: 'REVISION',
            notes: notes.isNotEmpty ? notes : null,
          ),
        );
  }

  void _showRevisiConfirmDialog(
      BuildContext context, PanicButtonHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: Colors.red[700],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 32.sp,
              ),
            ),
            16.verticalSpace,
            Text(
              'Apakah Anda yakin mengirim revisi?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            24.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: REdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red[700]!),
                    ),
                    child: Text(
                      'Tidak',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitRevisi(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: REdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Ya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(PanicButtonStatusColor statusColor) {
    switch (statusColor) {
      case PanicButtonStatusColor.red:
        return Colors.red;
      case PanicButtonStatusColor.orange:
        return Colors.orange;
      case PanicButtonStatusColor.blue:
        return Colors.blue[700]!;
      case PanicButtonStatusColor.grey:
        return Colors.grey;
    }
  }

  String _formatReporter(PanicButtonHistoryItem item) {
    final parts = <String>[];
    if (item.reporterNrp != null && item.reporterNrp!.isNotEmpty) {
      parts.add(item.reporterNrp!);
    }
    if (item.reporterName != null && item.reporterName!.isNotEmpty) {
      parts.add(item.reporterName!);
    }
    return parts.isEmpty ? '-' : parts.join(' - ');
  }

  String _formatSolver(PanicButtonHistoryItem item) {
    final parts = <String>[];
    if (item.solverNrp != null && item.solverNrp!.isNotEmpty) {
      parts.add(item.solverNrp!);
    }
    if (item.solverName != null && item.solverName!.isNotEmpty) {
      parts.add(item.solverName!);
    }
    return parts.isEmpty ? 'xxxx' : parts.join(' - ');
  }

  String _formatIncidentDate(PanicButtonHistoryItem item) {
    if (item.createDate == null) return '-';

    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH.mm', 'id_ID');

    final dateStr = dateFormat.format(item.createDate!);
    final timeStr = timeFormat.format(item.createDate!);

    return '$dateStr - $timeStr WIB';
  }

  String _formatCreateDate(PanicButtonHistoryItem item) {
    if (item.createDate == null) return 'xxxx';

    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    return dateFormat.format(item.createDate!);
  }

  String _formatSolverDate(PanicButtonHistoryItem item) {
    if (item.solverDate == null) return 'xxxx';

    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final timeFormat = DateFormat('HH.mm', 'id_ID');
    final dateStr = dateFormat.format(item.solverDate!);
    final timeStr = timeFormat.format(item.solverDate!);
    return '$dateStr - $timeStr WIB';
  }
}
