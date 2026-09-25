import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../domain/entities/attendance_rekap_detail_entity.dart';
import '../bloc/attendance_rekap_detail_bloc.dart';
import '../bloc/attendance_rekap_detail_event.dart';
import '../bloc/attendance_rekap_detail_state.dart';
import 'attendance_rekap_edit_screen.dart';

class AttendanceRekapDetailScreen extends StatelessWidget {
  final String idAttendance;

  const AttendanceRekapDetailScreen({
    super.key,
    required this.idAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttendanceRekapDetailBloc>()
        ..add(LoadAttendanceRekapDetailEvent(idAttendance)),
      child: _AttendanceRekapDetailScreenContent(idAttendance: idAttendance),
    );
  }
}

class _AttendanceRekapDetailScreenContent extends StatefulWidget {
  final String idAttendance;

  const _AttendanceRekapDetailScreenContent({required this.idAttendance});

  @override
  State<_AttendanceRekapDetailScreenContent> createState() =>
      _AttendanceRekapDetailScreenContentState();
}

class _AttendanceRekapDetailScreenContentState
    extends State<_AttendanceRekapDetailScreenContent> {

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        enableScrolling: true,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Detail Laporan Kegiatan',
            style: TS.titleLarge.copyWith(color: Colors.white),
          ),
          centerTitle: true,
        ),
        child: BlocConsumer<AttendanceRekapDetailBloc,
            AttendanceRekapDetailState>(
          listener: (context, state) {
            if (state is AttendanceRekapDetailFailure) {
              // Close loading dialog if open
              Navigator.of(context, rootNavigator: true).popUntil(
                (route) => route.isFirst || !route.willHandlePopInternally,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is AttendanceRekapDetailLoading) {
              return Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            if (state is AttendanceRekapDetailFailure) {
              return _buildErrorState(context, state.message);
            }

            if (state is AttendanceRekapDetailLoaded) {
              return _buildDetailContent(context, state.detail);
            }

            return const SizedBox.shrink();
          },
        ),
    );
  }

  Widget _buildDetailContent(
      BuildContext context, AttendanceRekapDetailEntity detail) {
    final canEdit = detail.statusLaporan.toUpperCase() == 'REVISI';
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileSectionInCard(detail),

            16.verticalSpace,

            // Fields Section
            Padding(
              padding: REdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Laporan
                  _buildInfoFieldInCard(
                    'Status Laporan',
                    _formatStatusLaporan(detail.statusLaporan),
                  ),

                  16.verticalSpace,

                  // Tanggal
                  _buildInfoFieldInCard('Tanggal', _formatDate(detail.shiftDate)),

                  16.verticalSpace,

                  // Nama Shift
                  _buildInfoFieldInCard('Nama Shift', detail.shiftName),

                  16.verticalSpace,

                  // Lokasi Jaga
                  _buildInfoFieldInCard('Lokasi Jaga', detail.location ?? '-'),

                  // Mulai Bekerja Section
                  if (detail.checkIn != null) ...[
                    16.verticalSpace,
                    Text(
                      'Mulai Bekerja',
                      style: TS.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                      ),
                    ),
                    8.verticalSpace,
                    _buildInfoFieldInCard(
                      'Jam Absensi',
                      _formatTime(detail.checkIn!),
                    ),
                    16.verticalSpace,
                    _buildImageCard(
                      'Pakaian Personil',
                      detail.photoPakaian?.url,
                    ),
                    16.verticalSpace,
                    _buildTextAreaFieldInCard(
                      'Laporan Pengamanan',
                      (detail.notes != null && detail.notes!.trim().isNotEmpty)
                          ? detail.notes!.trim()
                          : '-',
                    ),
                    16.verticalSpace,
                    _buildImageCard(
                      'Foto Pengamanan',
                      detail.photoPengamanan?.url,
                    ),
                  ],

                  16.verticalSpace,

                  // Tugas Lanjutan (Carry Over)
                  _buildCarryOverFieldInCard(detail.listCarryOver),

                  // Selesai Bekerja Section
                  if (detail.checkOut != null) ...[
                    16.verticalSpace,
                    Text(
                      'Selesai Bekerja',
                      style: TS.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                      ),
                    ),
                    8.verticalSpace,
                    _buildImageCard(
                      'Pakaian Personil',
                      detail.photoCheckoutPakaian?.url,
                    ),
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Lokasi Pengamanan',
                      detail.location ?? '-',
                    ),

                    // Patroli Section
                    if (detail.patrol == 'Yes' && detail.route != null) ...[
                      16.verticalSpace,
                      _buildPatrolSectionInCard(detail.route!, detail.listCarryOver),
                    ],

                    // Bukti Penyelesaian Tugas Lanjutan
                    if (detail.photoOvertime?.hasPhoto == true) ...[
                      16.verticalSpace,
                      _buildImageCard(
                        'Bukti Penyelesaian Tugas Lanjutan',
                        detail.photoOvertime?.url,
                      ),
                    ],

                    // Laporan Pengamanan (Checkout)
                    if (detail.notesCheckout != null && detail.notesCheckout!.isNotEmpty) ...[
                      16.verticalSpace,
                      _buildTextAreaFieldInCard(
                        'Laporan Pengamanan',
                        detail.notesCheckout!,
                      ),
                    ],

                    // Foto Pengamanan (Checkout)
                    if (detail.photoCheckoutPengamanan?.hasPhoto == true) ...[
                      16.verticalSpace,
                      _buildImageCard(
                        'Foto Pengamanan',
                        detail.photoCheckoutPengamanan?.url,
                      ),
                    ],

                    // Tugas Tertunda
                    16.verticalSpace,
                    _buildTextAreaFieldInCard(
                      'Tugas Tertunda',
                      (detail.carryOver ?? '').trim().isNotEmpty
                          ? detail.carryOver!.trim()
                          : '-',
                    ),

                    // Jam Selesai Bekerja
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Jam Selesai Bekerja',
                      _formatTime(detail.checkOut!),
                    ),

                    // Total Jam Kerja
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Total Jam Kerja',
                      (detail.checkIn != null && detail.checkOut != null)
                          ? _calculateTotalHours(detail.checkIn!, detail.checkOut!)
                          : '-',
                    ),

                    // Lembur
                    16.verticalSpace,
                    _buildInfoFieldInCard('Lembur', detail.isOvertime ? 'Ya' : 'Tidak'),

                    // Bukti Lembur
                    if (detail.photoOvertime?.hasPhoto == true) ...[
                      16.verticalSpace,
                      _buildImageCard(
                        'Bukti Lembur',
                        detail.photoOvertime?.url,
                      ),
                    ],

                    // Status Selesai Bekerja
                    if (detail.statusKerja != null) ...[
                      16.verticalSpace,
                      _buildInfoFieldInCard(
                        'Status Selesai Bekerja',
                        detail.statusKerja!,
                      ),
                    ],
                  ],
                ],
              ),
            ),

            32.verticalSpace,

            // Next Button
            Padding(
              padding: REdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: UIButton(
                text: 'Selanjutnya',
                enable: detail.statusLaporan.toUpperCase() != 'CHECKIN',
                onPressed: () {
                  if (!canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Laporan hanya dapat diedit ketika status REVISI.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  _navigateToEdit(context);
                },
                variant: UIButtonVariant.primary,
                size: UIButtonSize.large,
                fullWidth: true,
                suffixIcon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEdit(BuildContext context) async {
    final currentState = context.read<AttendanceRekapDetailBloc>().state;
    if (currentState is AttendanceRekapDetailLoaded) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceRekapEditScreen(
            idAttendance: widget.idAttendance,
            detail: currentState.detail,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildInfoFieldInCard(
    String label,
    String value, {
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        GestureDetector(
          onTap: isClickable ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              value,
              style: TS.bodyMedium.copyWith(
                color: isClickable ? Colors.blue : neutral90,
                decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSectionInCard(AttendanceRekapDetailEntity detail) {
    return Padding(
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Photo
          Center(
            child: detail.photoPegawai != null
                ? CircleAvatar(
                    radius: 40.r,
                    backgroundImage: NetworkImage(detail.photoPegawai!),
                  )
                : CircleAvatar(
                    radius: 40.r,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 40.r,
                      color: primaryColor,
                    ),
                  ),
          ),
          12.verticalSpace,
          Center(
            child: Text(
              detail.fullname,
              style: TS.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          4.verticalSpace,
          Center(
            child: Text(
              '${detail.jabatan} - ${detail.nrp}',
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (detail.checkIn != null || detail.checkOut != null) ...[
            8.verticalSpace,
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Hadir',
                  style: TS.bodySmall.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextAreaFieldInCard(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        Container(
          width: double.infinity,
          padding: REdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            value,
            style: TS.bodyMedium,
          ),
        ),
      ],
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
          ElevatedButton(
            onPressed: () {
              context.read<AttendanceRekapDetailBloc>().add(
                    LoadAttendanceRekapDetailEvent(widget.idAttendance),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    try {
      final formatter = DateFormat('d MMMM yyyy', 'id_ID');
      return formatter.format(date);
    } catch (e) {
      final formatter = DateFormat('d MMMM yyyy');
      return formatter.format(date);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('dd MMMM yyyy - HH.mm', 'id_ID').format(dateTime) + ' WIB';
  }

  String _formatStatusLaporan(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Verifikasi';
      case 'CHECKIN':
        return 'Check In';
      case 'CHECKOUT':
        return 'Check Out';
      default:
        return status;
    }
  }

  String _calculateTotalHours(DateTime checkIn, DateTime checkOut) {
    final difference = checkOut.difference(checkIn);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')} Hours ${minutes.toString().padLeft(2, '0')} Minutes';
  }

  Widget _buildCarryOverFieldInCard(List<CarryOverItem> listCarryOver) {
    if (listCarryOver.isEmpty) {
      return _buildInfoFieldInCard('Tugas Lanjutan', '-');
    }

    // Calculate completion status
    final completedCount = listCarryOver.where((item) => item.isCompleted).length;
    final totalCount = listCarryOver.length;
    final statusText = completedCount == totalCount
        ? 'Selesai ($totalCount/$totalCount Selesai Dikerjakan)'
        : 'Belum Selesai ($completedCount/$totalCount Selesai Dikerjakan)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tugas Lanjutan',
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        GestureDetector(
          onTap: () {
            // TODO: Navigate to carry over detail
          },
          child: Container(
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: TS.bodyMedium.copyWith(
                      color: neutral90,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: neutral50,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatrolSectionInCard(String routeName, List<CarryOverItem> listCarryOver) {
    // Check if all items are completed
    final allChecked = listCarryOver.isNotEmpty && 
        listCarryOver.every((item) => item.isCompleted);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              routeName,
              style: TS.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: neutral90,
              ),
            ),
            if (!allChecked && listCarryOver.isNotEmpty) ...[
              8.horizontalSpace,
              Text(
                '(Belum Selesai Diperiksa)',
                style: TS.bodySmall.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        // this is must be patrol timeline
        if (listCarryOver.isEmpty) ...[
          16.verticalSpace,
          Text(
            'Belum ada data patroli',
            style: TS.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ] else ...[
          16.verticalSpace,
          ...listCarryOver.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == listCarryOver.length - 1;
            final isCompleted = item.isCompleted;

            final dotColor = isCompleted ? Colors.green : Colors.orange;
            final lineColor = Colors.grey.shade300;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2.w,
                        height: 40.h,
                        margin: REdgeInsets.symmetric(vertical: 4),
                        color: lineColor,
                      ),
                  ],
                ),
                12.horizontalSpace,
                Expanded(
                  child: Padding(
                    padding: REdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.note,
                          style: TS.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: neutral90,
                          ),
                        ),
                        4.verticalSpace,
                        Text(
                          item.status,
                          style: TS.bodySmall.copyWith(
                            color: isCompleted ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ],
    );
  }

  /// Helper method to build full image URL from relative or absolute URL
  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'Foto.jpg') {
      return '';
    }
    
    // If already a full URL, return as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Get base URL
    String baseUrl = AppConstants.baseUrl;
    
    // Check if URL is just a filename (no slashes, but has file extension)
    final hasFileExtension = imageUrl.toLowerCase().contains('.jpg') || 
        imageUrl.toLowerCase().contains('.jpeg') || 
        imageUrl.toLowerCase().contains('.png') || 
        imageUrl.toLowerCase().contains('.gif') || 
        imageUrl.toLowerCase().contains('.webp');
    
    // If URL is just a filename (contains extension but no slashes), 
    // construct URL with file endpoint
    if (!imageUrl.contains('/') && hasFileExtension) {
      // Use /api/v1/file/{filename} endpoint
      return '$baseUrl/file/$imageUrl';
    }
    
    // If relative path, construct full URL using base URL
    // Remove leading slash if present
    final cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    
    // If path doesn't start with api/v1, add it
    if (!cleanPath.startsWith('api/')) {
      return '$baseUrl/$cleanPath';
    }
    
    // If path already has api, use base URL without /api/v1
    String fileBaseUrl = baseUrl;
    if (fileBaseUrl.endsWith('/api/v1')) {
      fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 7);
    } else if (fileBaseUrl.endsWith('/api')) {
      fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 4);
    }
    
    // Construct full URL
    return '$fileBaseUrl/$cleanPath';
  }

  Widget _buildImageCard(String label, String? imageUrl) {
    // Build full image URL
    final fullImageUrl = _buildImageUrl(imageUrl);
    final isValidImage = fullImageUrl.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        if (isValidImage)
          GestureDetector(
            onTap: () => _showFullImage(fullImageUrl),
            child: Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      fullImageUrl,
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
                              color: primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return GestureDetector(
                          onTap: () => _showFullImage(fullImageUrl),
                          child: Container(
                            color: Colors.grey[100],
                            padding: REdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48.sp,
                                  color: Colors.grey.shade400,
                                ),
                                8.verticalSpace,
                                Text(
                                  'Gagal memuat gambar',
                                  style: TS.bodySmall.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                4.verticalSpace,
                                Text(
                                  fullImageUrl,
                                  style: TS.bodySmall.copyWith(
                                    color: primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Overlay untuk indikasi bisa diklik
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: REdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 20.sp,
                  color: Colors.grey.shade600,
                ),
                8.horizontalSpace,
                Expanded(
                  child: Text(
                    'Tidak ada gambar',
                    style: TS.bodyMedium.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: REdgeInsets.all(0),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      padding: REdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: REdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64.sp,
                            color: Colors.white,
                          ),
                          16.verticalSpace,
                          Text(
                            'Gagal memuat gambar',
                            style: TS.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40.h,
              right: 20.w,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
