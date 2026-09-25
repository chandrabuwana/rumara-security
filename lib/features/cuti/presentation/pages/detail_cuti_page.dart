import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../bloc/cuti_bloc.dart';
import '../bloc/cuti_event.dart';
import '../bloc/cuti_state.dart';
import '../dialogs/success_dialog.dart';
import '../../domain/entities/cuti_entity.dart';
import 'edit_cuti_page.dart';

class DetailCutiPage extends StatefulWidget {
  final String cutiId;
  final bool showActions;
  final UserRole currentUserRole;

  const DetailCutiPage({
    Key? key,
    required this.cutiId,
    this.showActions = false,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<DetailCutiPage> createState() => _DetailCutiPageState();
}

class _DetailCutiPageState extends State<DetailCutiPage> {
  final _feedbackController = TextEditingController();
  late CutiBloc _cutiBloc;
  CutiEntity? _lastLoadedCuti;

  @override
  void initState() {
    super.initState();
    _cutiBloc = getIt<CutiBloc>();
    _loadDetailCuti();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _cutiBloc.close();
    super.dispose();
  }

  void _loadDetailCuti() {
    _cutiBloc.add(GetDetailCutiEvent(widget.cutiId));
  }

  bool _isQuotaNotEnoughMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('kuota') ||
        lower.contains('jatah cuti') ||
        lower.contains('tidak cukup');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cutiBloc,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Detail Ajuan Cuti'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        child: BlocListener<CutiBloc, CutiState>(
          listener: (context, state) {
            if (state is StatusCutiUpdated) {
              if (!mounted) return;
              SuccessDialog.show(
                context: context,
                title: 'Status Berhasil Diperbarui',
                message: 'Status cuti telah berhasil diperbarui.',
                buttonText: 'Kembali',
                onPressed: () {
                  if (!mounted) return;
                  // Close dialog
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // Return true to indicate status was updated, so parent can reload
                  Future.microtask(() {
                    if (!mounted) return;
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  });
                },
              );
            } else if (state is CutiEdited) {
              // Note: Dialog is already shown in EditCutiPage
              // EditCutiPage already calls reload, so we don't need to reload here
              // The list will be reloaded when user returns from detail page
            } else if (state is CutiDeleted) {
              if (!mounted) return;
              
              // Reload list cuti setelah delete berhasil dengan data terbaru dari API
              _reloadAfterDelete();
              
              SuccessDialog.show(
                context: context,
                title: 'Cuti Berhasil Dihapus',
                message: 'Ajuan cuti telah berhasil dihapus.',
                buttonText: 'Kembali',
                onPressed: () {
                  if (!mounted) return;
                  // Close dialog
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // Return true to indicate cuti was deleted, so parent can reload
                  Future.microtask(() {
                    if (!mounted) return;
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  });
                },
              );
            } else if (state is CutiError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: BlocBuilder<CutiBloc, CutiState>(
            builder: (context, state) {
              if (state is CutiLoading) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (state is CutiError) {
                if (_lastLoadedCuti != null &&
                    _isQuotaNotEnoughMessage(state.message)) {
                  return _buildDetailContent(_lastLoadedCuti!);
                }

                return _buildErrorWidget(state.message);
              }

              if (state is DetailCutiLoaded) {
                _lastLoadedCuti = state.cuti;
                return _buildDetailContent(state.cuti);
              }

              return Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(CutiEntity cuti) {
    final formatter = DateFormat('dd/MM/yyyy');
    final dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Center(
            child: _buildStatusChip(cuti.status, isDark: false),
          ),

          24.verticalSpace,

          // Detail Information
          _buildInfoSection('Informasi Detail', [
            _buildInfoItem('Nama', cuti.nama),
            _buildInfoItem('Tipe Cuti', cuti.tipeCutiDisplayName),
            _buildInfoItem(
                'Tanggal Mulai', formatter.format(cuti.tanggalMulai)),
            _buildInfoItem(
                'Tanggal Selesai', formatter.format(cuti.tanggalSelesai)),
            _buildInfoItem('Jumlah Hari', '${cuti.jumlahHari} hari'),
            if (cuti.tanggalDibuat != null)
              _buildInfoItem(
                  'Tanggal Dibuat', dateTimeFormatter.format(cuti.tanggalDibuat!)),
            if (cuti.tanggalReview != null)
              _buildInfoItem(
                  'Tanggal Disetujui', dateTimeFormatter.format(cuti.tanggalReview!)),
            if (cuti.approveBy != null && cuti.approveBy!.isNotEmpty)
              _buildInfoItem('Disetujui oleh', cuti.approveBy!),
            if (cuti.reviewerName != null)
              _buildInfoItem('Direview oleh', cuti.reviewerName!),
          ]),

          20.verticalSpace,

          // Alasan Section
          _buildInfoSection('Alasan', [
            _buildTextContent(cuti.alasan),
          ]),

          if (cuti.umpanBalik != null && cuti.umpanBalik!.isNotEmpty) ...[
            20.verticalSpace,
            _buildInfoSection('Feedback', [
              _buildTextContent(cuti.umpanBalik!),
            ]),
          ],

          // Show action buttons for pjo/deputy/pengawas when viewing from Ajuan Anggota/Ajuan Cuti tab
          // Note: Danton sama dengan anggota, tidak bisa approve/reject
          if (widget.showActions && 
              cuti.status == CutiStatus.pending &&
              (widget.currentUserRole == UserRole.pjo ||
               widget.currentUserRole == UserRole.deputy ||
               widget.currentUserRole == UserRole.pengawas)) ...[
            32.verticalSpace,
            _buildActionButtons(cuti),
          ],

          // Show Edit and Delete buttons for pending cuti (only for anggota/danton who created it)
          // Pengawas, admin, PJO, dan Deputy tidak bisa edit/hapus cuti
          FutureBuilder<String?>(
            future: SecurityManager.readSecurely(AppConstants.userIdKey),
            builder: (context, snapshot) {
              final currentUserId = snapshot.data ?? '';
              final isOwner = cuti.userId == currentUserId;
              final canEditDelete = cuti.status == CutiStatus.pending &&
                  isOwner &&
                  (widget.currentUserRole == UserRole.anggota ||
                   widget.currentUserRole == UserRole.danton);
              
              if (canEditDelete) {
                return Column(
                  children: [
                    32.verticalSpace,
                    _buildEditDeleteButtons(cuti),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          12.verticalSpace,
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: REdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TS.bodyMedium.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(String text) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TS.bodyMedium.copyWith(
          color: Colors.black87,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionButtons(CutiEntity cuti) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: UIButton(
                text: 'Tolak',
                buttonType: UIButtonType.outline,
                variant: UIButtonVariant.error,
                onPressed: () => _showRejectionDialog(cuti),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: UIButton(
                text: 'Terima',
                variant: UIButtonVariant.success,
                onPressed: () => _showApprovalDialog(cuti),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(CutiStatus status, {bool isDark = false}) {
    Color backgroundColor;
    Color textColor;

    if (isDark) {
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white;
    } else {
      switch (status) {
        case CutiStatus.pending:
          backgroundColor = Colors.orange.shade100;
          textColor = Colors.orange.shade700;
          break;
        case CutiStatus.approved:
          backgroundColor = Colors.green.shade100;
          textColor = Colors.green.shade700;
          break;
        case CutiStatus.rejected:
          backgroundColor = Colors.red.shade100;
          textColor = Colors.red.shade700;
          break;
        case CutiStatus.cancelled:
          backgroundColor = Colors.grey.shade100;
          textColor = Colors.grey.shade700;
          break;
      }
    }

    return Container(
      padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        status == CutiStatus.pending
            ? 'Menunggu'
            : status == CutiStatus.approved
                ? 'Disetujui'
                : status == CutiStatus.rejected
                    ? 'Ditolak'
                    : 'Dibatalkan',
        style: TS.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.r,
            color: Colors.red,
          ),
          16.verticalSpace,
          Text(
            'Terjadi Kesalahan',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          UIButton(
            text: 'Coba Lagi',
            onPressed: _loadDetailCuti,
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(CutiEntity cuti) {
    showDialog(
      context: context,
      builder: (context) => _buildFeedbackDialog(
        title: 'Terima Ajuan Cuti?',
        message: 'Pastikan data sudah sesuai',
        confirmText: 'Ya',
        isApproval: true,
        cuti: cuti,
      ),
    );
  }

  void _showRejectionDialog(CutiEntity cuti) {
    showDialog(
      context: context,
      builder: (context) => _buildFeedbackDialog(
        title: 'Tolak Ajuan Cuti?',
        message: 'Berikan alasan penolakan ajuan cuti ini:',
        confirmText: 'Tolak',
        isApproval: false,
        cuti: cuti,
      ),
    );
  }

  Widget _buildFeedbackDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isApproval,
    required CutiEntity cuti,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Text(
        title,
        style: TS.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TS.bodyMedium,
          ),
          if (isApproval) ...[
            16.verticalSpace,
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Umpan balik (opsional)...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ] else ...[
            16.verticalSpace,
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Masukkan alasan penolakan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _feedbackController.clear();
            Navigator.of(context).pop();
          },
          child: Text(isApproval ? 'Tidak' : 'Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            final feedback = _feedbackController.text.trim();

            if (!isApproval && feedback.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alasan penolakan harus diisi'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Get current user info from secure storage
            final userId = await SecurityManager.readSecurely(AppConstants.userIdKey) ?? '';
            final userName = await SecurityManager.readSecurely('user_fullname') ?? 'Reviewer';

            _cutiBloc.add(
              UpdateStatusCutiEvent(
                cutiId: cuti.id,
                status: isApproval ? CutiStatus.approved : CutiStatus.rejected,
                reviewerId: userId,
                reviewerName: userName,
                umpanBalik: feedback,
              ),
            );

            _feedbackController.clear();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }

  Widget _buildEditDeleteButtons(CutiEntity cuti) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: UIButton(
                text: 'Edit',
                buttonType: UIButtonType.outline,
                variant: UIButtonVariant.primary,
                onPressed: () => _navigateToEdit(cuti),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: UIButton(
                text: 'Hapus',
                variant: UIButtonVariant.error,
                onPressed: () => _showDeleteDialog(cuti),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToEdit(CutiEntity cuti) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _cutiBloc,
          child: EditCutiPage(cuti: cuti),
        ),
      ),
    );
    
    if (result == true) {
      // Edit was successful, pop detail page and return true to list
      // so list can reload
      Future.microtask(() {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  Future<void> _reloadAfterEdit(CutiEntity cuti) async {
    // Reload list cuti setelah edit berhasil dengan data terbaru dari API
    final role = widget.currentUserRole;
    final userId = cuti.userId;
    
    // Always reload Ajuan Saya tab to ensure data is fresh from API
    _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
    
    // Also reload other tabs based on role
    if (role == UserRole.pjo || role == UserRole.deputy) {
      _cutiBloc.add(const GetDaftarCutiAnggotaEvent());
    } else if (role == UserRole.pengawas || role == UserRole.admin) {
      _cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
      _cutiBloc.add(const GetRekapCutiEvent());
    }
  }

  Future<void> _reloadAfterDelete() async {
    // Reload list cuti setelah delete berhasil dengan data terbaru dari API
    final role = widget.currentUserRole;
    final userId = await SecurityManager.readSecurely(AppConstants.userIdKey) ?? 'user_1';
    
    // Always reload Ajuan Saya tab to ensure data is fresh from API
    _cutiBloc.add(GetDaftarCutiSayaEvent(userId));
    
    // Also reload other tabs based on role
    if (role == UserRole.pjo || role == UserRole.deputy) {
      _cutiBloc.add(const GetDaftarCutiAnggotaEvent());
    } else if (role == UserRole.pengawas || role == UserRole.admin) {
      _cutiBloc.add(const GetDaftarCutiAnggotaEvent(status: 'pending'));
      _cutiBloc.add(const GetRekapCutiEvent());
    }
  }

  void _showDeleteDialog(CutiEntity cuti) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Hapus Ajuan Cuti?',
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus ajuan cuti ini? Tindakan ini tidak dapat dibatalkan.',
          style: TS.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              _cutiBloc.add(DeleteCutiEvent(cuti.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
