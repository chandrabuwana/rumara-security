import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../bloc/laporan_kegiatan_bloc.dart';
import '../../domain/entities/laporan_kegiatan_entity.dart';
import '../widgets/patrol_timeline_widget.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';
// tugas tertunda = carryOver
//tugas lanjutan =listCarryOver.note
class LaporanKegiatanDetailPage extends StatefulWidget {
  final String laporanId;
  final UserRole userRole;

  const LaporanKegiatanDetailPage({
    Key? key,
    required this.laporanId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<LaporanKegiatanDetailPage> createState() =>
      _LaporanKegiatanDetailPageState();
}

class _LaporanKegiatanDetailPageState extends State<LaporanKegiatanDetailPage> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _isSubmittingRevisi = false;

  @override
  void initState() {
    super.initState();
    context
        .read<LaporanKegiatanBloc>()
        .add(GetLaporanDetailEvent(widget.laporanId));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: AppScaffold(
        enableScrolling: false,
        appBar: RumaraAppBar(title: 'Detail Laporan Kegiatan', onBack: () async {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }),
        child: BlocConsumer<LaporanKegiatanBloc, LaporanKegiatanState>(
        listener: (context, state) {
          if (_isSubmittingRevisi && state is LaporanDetailLoaded) {
            _isSubmittingRevisi = false;
            Navigator.of(context).pop(true);
            return;
          }

          if (_isSubmittingRevisi && state is LaporanError) {
            _isSubmittingRevisi = false;
          }

          // Handle mark as tidak masuk success
          if (state is LaporanDetailLoaded && state.showMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.showMessage!),
                backgroundColor: Colors.green,
              ),
            );
            // If laporan is null (data not found), navigate back to list
            if (state.laporan == null) {
              Navigator.of(context).pop(true);
            }
          }

          if (state is LaporanUpdated) {
            // Show success dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                contentPadding: REdgeInsets.all(24),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.h,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32.sp,
                      ),
                    ),
                    16.verticalSpace,
                    Text(
                      'Laporan Kegiatan Berhasil Diterima!',
                      style: TS.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    24.verticalSpace,
                    UIButton(
                      text: 'OK',
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(true); // Go back to list with refresh flag
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is LaporanLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is LaporanError) {
            return Center(child: Text(state.message));
          }

          if (state is LaporanDetailLoaded) {
            if (state.laporan == null) {
              // Data not found case - show loading or navigate back (handled in listener)
              return const Center(child: CircularProgressIndicator());
            }
            return _buildDetailContent(state.laporan!);
          }

          return const SizedBox();
        },
      ),
      ),
    );
  }

  Widget _buildDetailContent(LaporanKegiatanEntity laporan) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildFirstPage(laporan),
              _buildSecondPage(laporan),
            ],
          ),
        ),
        // Page indicator and navigation
        if (_currentPage == 0)
          Container(
            padding: REdgeInsets.all(16),
            child: UIButton(
              text: 'Selanjutnya →',
              fullWidth: true,
              enable: laporan.status != LaporanStatus.checkIn &&
                  laporan.checkOut != null,
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          )
        else
          _buildActionButtons(laporan),
      ],
    );
  }

  Widget _buildFirstPage(LaporanKegiatanEntity laporan) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');

    return SingleChildScrollView(
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40.r,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: laporan.profileImageUrl != null
                      ? NetworkImage(laporan.profileImageUrl!)
                      : null,
                  child: laporan.profileImageUrl == null
                      ? Icon(Icons.person, size: 40.sp)
                      : null,
                ),
                8.verticalSpace,
                Text(
                  laporan.namaPersonil,
                  style: TS.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                Text(
                  '${laporan.role.displayName} - ${laporan.nrp}',
                  style: TS.bodySmall.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                Text(
                  _getKehadiranText(laporan.kehadiran),
                  style: TS.bodySmall.copyWith(
                    color: _getKehadiranColor(laporan.kehadiran),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          24.verticalSpace,

          // Status Laporan
          _buildInfoCard('Status Laporan', laporan.status.displayName),
          16.verticalSpace,

          // Tanggal
          _buildInfoCard('Tanggal', dateFormat.format(laporan.tanggal)),
          16.verticalSpace,

          // Nama Shift
          _buildInfoCard('Nama Shift', laporan.shift),
          16.verticalSpace,

          // Lokasi Jaga
          _buildInfoCard('Lokasi Jaga', laporan.lokasiJaga),
          16.verticalSpace,

          // Mulai Bekerja Section
          Text(
            'Mulai Bekerja',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          16.verticalSpace,

          // Jam Absensi
          _buildInfoCard(
            'Jam Absensi',
            laporan.jamAbsensi ?? '-',
          ),
          16.verticalSpace,

          // Pakaian Personil
          _buildFileCard(
            'Pakaian Personil',
            laporan.fotoPakaianPersonil,
          ),
          16.verticalSpace,

          // Laporan Pengamanan
          _buildInfoCard(
            'Laporan Pengamanan',
            laporan.laporanPengamanan.trim().isNotEmpty
                ? laporan.laporanPengamanan
                : '-',
          ),
          16.verticalSpace,

          // Foto Pengamanan
          if (laporan.fotoPengamanan != null &&
              laporan.fotoPengamanan!.isNotEmpty)
            _buildFotoPengamananCard(laporan.fotoPengamanan!)
          else
            _buildFileCard('Foto Pengamanan', null),
          16.verticalSpace,

          // Tugas Lanjutan
          _buildTugasLanjutanCard(laporan),

          16.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildSecondPage(LaporanKegiatanEntity laporan) {
    return SingleChildScrollView(
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selesai Bekerja Section
          Text(
            'Selesai Bekerja',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          16.verticalSpace,

          // Pakaian Personil (selesai)
          _buildFileCard(
            'Pakaian Personil',
            laporan.fotoCheckoutPakaian,
          ),
          16.verticalSpace,

          // Patroli Section - ambil dari ListRoute
          if (laporan.checkpoints != null && laporan.checkpoints!.isNotEmpty) ...[
            Builder(
              builder: (context) {
                // Determine route name and status
                String routeDisplayName = laporan.routeName ?? 'Patroli';
                bool isDiperiksa = laporan.checkpoints!
                    .every((cp) => cp.isDiperiksa && cp.buktiUrl != null);
                
                // Add status suffix if not fully checked
                if (!isDiperiksa && !routeDisplayName.contains('Belum Selesai Diperiksa')) {
                  routeDisplayName = '$routeDisplayName (Belum Selesai Diperiksa)';
                }
                
                return PatrolTimelineWidget(
                  routeName: routeDisplayName,
                  checkpoints: laporan.checkpoints!,
                  isDiperiksa: isDiperiksa,
                );
              },
            ),
            16.verticalSpace,
          ],

          _buildDaftarTugasTertundaCard(laporan.listCarryOver ?? const []),
          16.verticalSpace,
          _buildTugasTertundaCard((laporan.carryOver ?? '').trim()),
          16.verticalSpace,

          // Laporan Pengamanan
          _buildInfoCard(
            'Laporan Pengamanan Checkout',
            laporan.laporanPengamananCheckout ?? '-',
          ),
          16.verticalSpace,

          // Foto Pengamanan
          if (laporan.fotoPengamananCheckout != null &&
              laporan.fotoPengamananCheckout!.isNotEmpty)
            _buildFotoPengamananCard(laporan.fotoPengamananCheckout!)
          else
            _buildFileCard('Foto Pengamanan', null),
          16.verticalSpace,

          // Jam Selesai Bekerja
          _buildInfoCard(
            'Jam Selesai Bekerja',
            laporan.jamSelesaiBekerja ?? '-',
          ),
          16.verticalSpace,

          // Total Jam Kerja
          if (laporan.checkIn != null && laporan.checkOut != null)
            _buildInfoCard(
              'Total Jam Kerja',
              _calculateTotalHours(laporan.checkIn!, laporan.checkOut!),
            )
          else
            _buildInfoCard('Total Jam Kerja', '-'),
          16.verticalSpace,

          // Lembur
          _buildInfoCard('Lembur', laporan.lembur ? 'Ya' : 'Tidak'),
          16.verticalSpace,

          // Bukti Lembur
          if (laporan.lembur)
            _buildFileCard(
              'Bukti Lembur',
              laporan.fotoLembur,
            )
          else
            _buildInfoCard('Bukti Lembur', '-'),
          16.verticalSpace,

          // Status Selesai Bekerja
          _buildInfoCard(
            'Status Selesai Bekerja',
            laporan.statusKerja ?? '-',
          ),
          16.verticalSpace,

          // Umpan Balik
          
          16.verticalSpace,
          _buildInfoCard(
            'Diverifikasi Oleh',
            laporan.status == LaporanStatus.waiting ? '-' : (laporan.updateBy ?? '-'),
          ),
          16.verticalSpace,
          _buildInfoCard(
            'Tanggal Verifikasi',
            laporan.status == LaporanStatus.waiting
                ? '-'
                : (laporan.updateDate != null
                    ? DateFormat('dd-MM-yyyy HH:mm').format(laporan.updateDate!)
                    : '-'),
          ),
          16.verticalSpace,
          _buildInfoCard(
            'Umpan Balik',
            laporan.umpanBalik ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(LaporanKegiatanEntity laporan) {
    final canTakeAction = widget.userRole.isHighAccess &&
        laporan.status == LaporanStatus.waiting;

    return Container(
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canTakeAction) ...[
            Row(
              children: [
                // WhatsApp Button
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat, color: Colors.white),
                    onPressed: () {
                      _openWhatsApp(laporan);
                    },
                  ),
                ),
                12.horizontalSpace,
                // Revisi Button
                Expanded(
                  child: UIButton(
                    text: 'Revisi',
                    buttonType: UIButtonType.outline,
                    variant: UIButtonVariant.error,
                    onPressed: () {
                      _showRevisiDialog(laporan);
                    },
                  ),
                ),
                12.horizontalSpace,
                // Terima Button
                Expanded(
                  flex: 2,
                  child: UIButton(
                    text: 'Terima Laporan Kegiatan',
                    onPressed: () {
                      _showAcceptConfirmation(laporan);
                    },
                  ),
                ),
              ],
            ),
            12.verticalSpace,
          ],
          // Tandai Sebagai Tidak Masuk Button
          if (canTakeAction)
            UIButton(
              text: 'Tandai Sebagai Tidak Masuk',
              buttonType: UIButtonType.outline,
              variant: UIButtonVariant.neutral,
              onPressed: () {
                _showMarkAsTidakMasukDialog(laporan);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TS.bodySmall.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          4.verticalSpace,
          Text(
            value,
            style: TS.bodyMedium.copyWith(color: Colors.black87),
            maxLines: 20,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

  Widget _buildFileCard(String label, String? imageUrl) {
    // Build full image URL
    final fullImageUrl = _buildImageUrl(imageUrl);
    // Consider it valid if we have a URL (even if it might fail to load)
    // This ensures we always try to show image instead of text
    final isValidImage = fullImageUrl.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TS.bodySmall.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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
                          // Even if image fails to load, show the URL as clickable text
                          // so user can still see what the URL is
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
      ),
    );
  }

  Widget _buildFotoPengamananCard(List<String> imageUrls) {
    // Build full URLs for all images
    final fullImageUrls = imageUrls.map((url) => _buildImageUrl(url)).where((url) => url.isNotEmpty).toList();
    
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foto Pengamanan',
            style: TS.bodySmall.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          8.verticalSpace,
          if (fullImageUrls.isEmpty)
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: fullImageUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final fullImageUrl = entry.value;
                return GestureDetector(
                  onTap: () => _showFullImage(fullImageUrl, index, fullImageUrls),
                child: Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      fullImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 24.sp,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl, [int index = 0, List<String>? allImages]) {
    int currentIndex = index;
    final pageController = PageController(initialPage: index);
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: REdgeInsets.all(0),
          child: Stack(
            children: [
              // Image viewer dengan swipe navigation jika ada multiple images
              if (allImages != null && allImages.length > 1)
                PageView.builder(
                  controller: pageController,
                  itemCount: allImages.length,
                  onPageChanged: (newIndex) {
                    setState(() {
                      currentIndex = newIndex;
                    });
                  },
                  itemBuilder: (context, pageIndex) {
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          allImages[pageIndex],
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
                    );
                  },
                )
              else
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              // Image counter dan navigation arrows
              if (allImages != null && allImages.length > 1) ...[
                // Previous button
                if (currentIndex > 0)
                  Positioned(
                    left: 20.w,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // Next button
                if (currentIndex < allImages.length - 1)
                  Positioned(
                    right: 20.w,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // Image counter
                Positioned(
                  bottom: 30.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: REdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${currentIndex + 1} / ${allImages.length}',
                        style: TS.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTugasLanjutanCard(LaporanKegiatanEntity laporan) {
    final value = (laporan.tugasLanjutan ?? '').trim();
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tugas Lanjutan',
                  style: TS.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                4.verticalSpace,
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TS.bodyMedium.copyWith(color: Colors.black87),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16.sp,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildTugasTertundaCard(String value) {
    final cleaned = value.trim();
    return Container(
      width: double.infinity,
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tugas Tertunda',
                  style: TS.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                4.verticalSpace,
                Text(
                  cleaned.isNotEmpty ? cleaned : '-',
                  style: TS.bodyMedium.copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),         
        ],
      ),
    );
  }

  Widget _buildDaftarTugasTertundaCard(List<LaporanCarryOverItem> items) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tugas Lanjutan',
            style: TS.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          12.verticalSpace,
          _buildInfoCard('Daftar Tugas Lanjutan', '-'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tugas Lanjutan',
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        12.verticalSpace,
        ...items.map((e) {
          final note = e.note.trim().isNotEmpty ? e.note.trim() : '-';
          final rawStatus = e.status.trim();
          final upperStatus = rawStatus.toUpperCase();

          final isCompleted = upperStatus.contains('SELESAI') ||
              upperStatus.contains('DONE') ||
              upperStatus.contains('CLOSED') ||
              (upperStatus.isNotEmpty && upperStatus != 'OPEN');

          final statusText = rawStatus.isNotEmpty
              ? rawStatus
              : (isCompleted ? 'Selesai' : 'Belum');

          return Padding(
            padding: REdgeInsets.only(bottom: 12),
            child: _buildCarryOverBubbleRow(
              note: note,
              statusText: statusText,
              isCompleted: isCompleted,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCarryOverBubbleRow({
    required String note,
    required String statusText,
    required bool isCompleted,
  }) {
    final borderColor =
        isCompleted ? const Color(0xFF2563EB) : const Color(0xFFD4A72C);
    final dotColor = borderColor;
    final tagBgColor =
        isCompleted ? const Color(0xFFE8F0FF) : const Color(0xFFFFF3C4);
    final tagTextColor =
        isCompleted ? const Color(0xFF1D4ED8) : const Color(0xFFB8860B);

    return Container(
      padding: REdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          14.horizontalSpace,
          Expanded(
            child: Text(
              note,
              style: TS.bodyMedium.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          12.horizontalSpace,
          Container(
            padding: REdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tagBgColor,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              statusText,
              style: TS.bodySmall.copyWith(
                color: tagTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getKehadiranText(String kehadiran) {
    switch (kehadiran) {
      case 'Masuk':
        return 'Masuk';
      case 'Terlambat':
        return 'Terlambat';
      case 'Cuti':
        return 'Cuti';
      case 'Tidak Masuk':
        return 'Tidak Masuk';
      default:
        return kehadiran;
    }
  }

  Color _getKehadiranColor(String kehadiran) {
    switch (kehadiran) {
      case 'Masuk':
        return const Color(0xFF1E88E5);
      case 'Terlambat':
        return Colors.orange;
      case 'Cuti':
        return const Color(0xFF1E88E5);
      case 'Tidak Masuk':
        return errorColor;
      default:
        return Colors.grey;
    }
  }

  String _calculateTotalHours(DateTime checkIn, DateTime checkOut) {
    final difference = checkOut.difference(checkIn);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')} Hours ${minutes.toString().padLeft(2, '0')} Minutes';
  }

  void _showAcceptConfirmation(LaporanKegiatanEntity laporan) {
    // Get bloc reference before showing dialog to avoid context issues
    final laporanBloc = context.read<LaporanKegiatanBloc>();
    
    ConfirmDialog.show(
      context: context,
      title: 'Konfirmasi',
      message: 'Apakah Anda yakin menerima laporan kegiatan ini?',
      confirmText: 'Ya',
      cancelText: 'Tidak',
      icon: Icons.check_circle_outline,
      iconColor: primaryColor,
    ).then((confirmed) {
      if (confirmed == true) {
        // Gunakan API verifikasi Attendance/verif
        laporanBloc.add(
          VerifLaporanEvent(
            idAttendance: laporan.id,
            isVerif: true,
            feedback: '',
          ),
        );
      }
    });
  }

  void _showRevisiDialog(LaporanKegiatanEntity laporan) {
    final noteController = TextEditingController();
    // Get bloc reference before showing dialog to avoid context issues
    final laporanBloc = context.read<LaporanKegiatanBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: laporanBloc,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Request Revisi',
            style: TS.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: noteController,
            decoration: InputDecoration(
              hintText: 'Masukkan catatan revisi...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Batal', style: TS.bodyMedium),
            ),
            UIButton(
              text: 'Kirim',
              onPressed: () {
                if (noteController.text.isNotEmpty) {
                  _isSubmittingRevisi = true;
                  // Gunakan idAttendance untuk API verif, fallback ke id jika idAttendance null
                  final idAttendance = laporan.idAttendance ?? laporan.id;
                  laporanBloc.add(
                    RequestRevisiEvent(
                      idAttendance: idAttendance,
                      note: noteController.text,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkAsTidakMasukDialog(LaporanKegiatanEntity laporan) {
    // Get bloc reference before showing dialog to avoid context issues
    final laporanBloc = context.read<LaporanKegiatanBloc>();
    
    ConfirmDialog.show(
      context: context,
      title: 'Konfirmasi',
      message: 'Yakin menandai laporan kegiatan ini sebagai "Tidak Masuk"?',
      confirmText: 'Ya',
      cancelText: 'Tidak',
      icon: Icons.help_outline,
      iconColor: errorColor,
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        laporanBloc.add(
          MarkAsTidakMasukEvent(laporan.id),
        );
      }
    });
  }

  void _openWhatsApp(LaporanKegiatanEntity laporan) {
    // TODO: Add url_launcher package to pubspec.yaml
    // Format: https://wa.me/PHONENUMBER?text=MESSAGE
    // final phoneNumber = '6281234567890'; // Replace with actual phone number
    // final message = 'Halo, saya ingin membahas laporan kegiatan untuk ${laporan.namaPersonil}';

    // For now, show a message that WhatsApp integration will be available after API integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur WhatsApp akan tersedia setelah integrasi API'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Uncomment when url_launcher is added:
    // final phoneNumber = '6281234567890';
    // final message = 'Halo, saya ingin membahas laporan kegiatan untuk ${laporan.namaPersonil}';
    // final url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';
    // if (await canLaunchUrl(Uri.parse(url))) {
    //   await launchUrl(Uri.parse(url));
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
    //   );
    // }
  }
}
