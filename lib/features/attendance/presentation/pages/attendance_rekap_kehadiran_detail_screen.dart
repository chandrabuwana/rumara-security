import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../domain/entities/attendance_rekap_detail_entity.dart';
import '../../domain/entities/attendance_update_request.dart';
import '../bloc/attendance_rekap_detail_bloc.dart';
import '../bloc/attendance_rekap_detail_event.dart';
import '../bloc/attendance_rekap_detail_state.dart';

class AttendanceRekapKehadiranDetailScreen extends StatelessWidget {
  final String idAttendance;

  const AttendanceRekapKehadiranDetailScreen({
    super.key,
    required this.idAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttendanceRekapDetailBloc>()
        ..add(LoadAttendanceRekapDetailEvent(idAttendance)),
      child: _AttendanceRekapKehadiranDetailScreenContent(idAttendance: idAttendance),
    );
  }
}

class _AttendanceRekapKehadiranDetailScreenContent extends StatefulWidget {
  final String idAttendance;

  const _AttendanceRekapKehadiranDetailScreenContent({required this.idAttendance});

  @override
  State<_AttendanceRekapKehadiranDetailScreenContent> createState() =>
      _AttendanceRekapKehadiranDetailScreenContentState();
}

class _AttendanceRekapKehadiranDetailScreenContentState
    extends State<_AttendanceRekapKehadiranDetailScreenContent> {
  int _stepIndex = 0;
  final TextEditingController _laporanCheckInController = TextEditingController();
  final TextEditingController _laporanCheckOutController = TextEditingController();
  File? _photoPakaianCheckInFile;
  File? _photoPengamananCheckInFile;
  File? _photoAbsenCheckOutFile;
  File? _photoPengamananCheckOutFile;
  File? _photoLemburCheckOutFile;
  bool _isOvertime = false;
  String? _initializedDetailId;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSavingDialogOpen = false;

  @override
  void dispose() {
    _laporanCheckInController.dispose();
    _laporanCheckOutController.dispose();
    super.dispose();
  }

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
          'Detail Kehadiran',
          style: TS.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      child: BlocConsumer<AttendanceRekapDetailBloc, AttendanceRekapDetailState>(
        listener: (context, state) {
          if (state is AttendanceRekapDetailFailure) {
            if (_isSavingDialogOpen) {
              Navigator.of(context, rootNavigator: true).pop();
              _isSavingDialogOpen = false;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }

          if (state is AttendanceRekapDetailUpdating) {
            if (!_isSavingDialogOpen) {
              _isSavingDialogOpen = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          }

          if (state is AttendanceRekapDetailUpdateSuccess) {
            if (_isSavingDialogOpen) {
              Navigator.of(context, rootNavigator: true).pop();
              _isSavingDialogOpen = false;
            }
            Navigator.of(context).pop(true);
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
            return _buildContent(context, state.detail);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AttendanceRekapDetailEntity detail) {
    final canEdit = detail.statusLaporan.toUpperCase() == 'REVISI';
    final isWaiting = detail.statusLaporan.toUpperCase() == 'WAITING';

    if (_initializedDetailId != detail.idAttendance) {
      _initializedDetailId = detail.idAttendance;
      _laporanCheckInController.text = detail.notes ?? '';
      _laporanCheckOutController.text = detail.notesCheckout ?? '';
      _isOvertime = detail.isOvertime;
      _photoPakaianCheckInFile = null;
      _photoPengamananCheckInFile = null;
      _photoAbsenCheckOutFile = null;
      _photoPengamananCheckOutFile = null;
      _photoLemburCheckOutFile = null;
    }

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
            _buildProfileSectionInCard(detail),
            16.verticalSpace,
            Padding(
              padding: REdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoFieldInCard('Tanggal', _formatDate(detail.shiftDate)),
                  16.verticalSpace,
                  _buildInfoFieldInCard('Nama Shift', detail.shiftName),
                  16.verticalSpace,
                  _buildInfoFieldInCard('Lokasi Jaga', detail.location ?? '-'),
                  16.verticalSpace,
                  _stepIndex == 0
                      ? _buildMulaiBekerjaSection(detail)
                      : _buildSelesaiBekerjaSection(detail),
                  if (_stepIndex == 1) ...[
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Status Laporan',
                      _formatStatusLaporan(detail.statusLaporan),
                    ),
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Diverifikasi Oleh',
                      isWaiting
                          ? '-'
                          : (detail.updateBy != null && detail.updateBy!.isNotEmpty)
                              ? detail.updateBy!
                              : '-',
                    ),
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Tanggal Verifikasi',
                      isWaiting
                          ? '-'
                          : (detail.updateDate != null)
                              ? _formatTime(detail.updateDate!)
                              : '-',
                    ),
                    16.verticalSpace,
                    _buildTextAreaFieldInCard(
                      'Feedback',
                      (detail.feedback != null && detail.feedback!.isNotEmpty)
                          ? detail.feedback!
                          : '-',
                    ),
                  ],
                ],
              ),
            ),
            32.verticalSpace,
            Padding(
              padding: REdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: UIButton(
                      text: _stepIndex == 0 ? 'Selanjutnya' : 'Kembali',
                      enable: _stepIndex == 0
                          ? detail.statusLaporan.toUpperCase() != 'CHECKIN'
                          : true,
                      onPressed: () {
                        setState(() {
                          _stepIndex = _stepIndex == 0 ? 1 : 0;
                        });
                      },
                      variant: UIButtonVariant.primary,
                      size: UIButtonSize.large,
                      fullWidth: true,
                      suffixIcon: _stepIndex == 0
                          ? const Icon(Icons.arrow_forward, color: Colors.white)
                          : const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  if (_stepIndex == 1 && canEdit) ...[
                    12.horizontalSpace,
                    Expanded(
                      child: UIButton(
                        text: 'Simpan',
                        onPressed: () => _handleFinalSave(context),
                        variant: UIButtonVariant.primary,
                        size: UIButtonSize.large,
                        fullWidth: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFinalSave(BuildContext context) async {
    final currentState = context.read<AttendanceRekapDetailBloc>().state;
    if (currentState is! AttendanceRekapDetailLoaded) return;

    final detail = currentState.detail;
    if (detail.statusLaporan.toUpperCase() != 'REVISI') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan hanya dapat disimpan ketika status REVISI.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final merged = AttendanceUpdateRequest(
      idAttendance: widget.idAttendance,
      // Check-in
      photoAbsenPath: _photoPakaianCheckInFile?.path,
      photoAbsenFilename:
          _photoPakaianCheckInFile != null ? detail.photoPakaian?.filename : null,
      photoPengamananPath: _photoPengamananCheckInFile?.path,
      photoPengamananFilename: _photoPengamananCheckInFile != null
          ? detail.photoPengamanan?.filename
          : null,
      laporan: _laporanCheckInController.text.trim().isNotEmpty
          ? _laporanCheckInController.text.trim()
          : null,
      // Check-out
      photoPakaianPath: _photoAbsenCheckOutFile?.path,
      photoPakaianFilename: _photoAbsenCheckOutFile != null
          ? detail.photoCheckoutPakaian?.filename
          : null,
      photoPengamananCheckOutPath: _photoPengamananCheckOutFile?.path,
      photoPengamananCheckOutFilename: _photoPengamananCheckOutFile != null
          ? detail.photoCheckoutPengamanan?.filename
          : null,
      laporanCheckout: _laporanCheckOutController.text.trim().isNotEmpty
          ? _laporanCheckOutController.text.trim()
          : null,
      isOvertime: _isOvertime,
      photoOvertimePath: _photoLemburCheckOutFile?.path,
      photoOvertimeFilename: _photoLemburCheckOutFile != null
          ? detail.photoOvertime?.filename
          : null,
    );

    context.read<AttendanceRekapDetailBloc>().add(
          UpdateAttendanceRekapDetailEvent(merged),
        );
  }

  Widget _buildMulaiBekerjaSection(AttendanceRekapDetailEntity detail) {
    final canEdit = detail.statusLaporan.toUpperCase() == 'REVISI';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          detail.checkIn != null ? _formatTime(detail.checkIn!) : '-',
        ),
        16.verticalSpace,
        canEdit
            ? _buildEditablePhotoPickerCard(
                label: 'Pakaian Personil',
                existingUrl: detail.photoPakaian?.url,
                pickedFile: _photoPakaianCheckInFile,
                onPick: (file) {
                  setState(() {
                    _photoPakaianCheckInFile = file;
                  });
                },
              )
            : _buildImageCard('Pakaian Personil', detail.photoPakaian?.url),
        16.verticalSpace,
        canEdit
            ? _buildEditableTextAreaFieldInCard(
                label: 'Laporan Pengamanan',
                controller: _laporanCheckInController,
                onChanged: (_) => setState(() {}),
              )
            : _buildTextAreaFieldInCard(
                'Laporan Pengamanan',
                (detail.notes != null && detail.notes!.isNotEmpty)
                    ? detail.notes!
                    : '-',
              ),
        16.verticalSpace,
        canEdit
            ? _buildEditablePhotoPickerCard(
                label: 'Foto Pengamanan',
                existingUrl: detail.photoPengamanan?.url,
                pickedFile: _photoPengamananCheckInFile,
                onPick: (file) {
                  setState(() {
                    _photoPengamananCheckInFile = file;
                  });
                },
              )
            : _buildImageCard('Foto Pengamanan', detail.photoPengamanan?.url),
      ],
    );
  }

  Widget _buildSelesaiBekerjaSection(AttendanceRekapDetailEntity detail) {
    final canEdit = detail.statusLaporan.toUpperCase() == 'REVISI';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selesai Bekerja',
          style: TS.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        _buildInfoFieldInCard('Status Selesai Bekerja', detail.statusKerja ?? '-'),
        16.verticalSpace,
        canEdit
            ? _buildEditablePhotoPickerCard(
                label: 'Pakaian Personil Checkout',
                existingUrl: detail.photoCheckoutPakaian?.url,
                pickedFile: _photoAbsenCheckOutFile,
                onPick: (file) {
                  setState(() {
                    _photoAbsenCheckOutFile = file;
                  });
                },
              )
            : _buildImageCard('Pakaian Personil Checkout', detail.photoCheckoutPakaian?.url),
        16.verticalSpace,
        _buildInfoFieldInCard('Lokasi Pengamanan', detail.location ?? '-'),
        
// i want to add patrol timeline widget in this section dont delete 


        if (detail.patrol == 'Yes' && detail.route != null) ...[
          16.verticalSpace,
          _buildPatrolSectionInCard(detail.route!, detail.listRoute, detail.listCarryOver),
        ],
        16.verticalSpace,
        canEdit
            ? _buildEditableTextAreaFieldInCard(
                label: 'Laporan Pengamanan',
                controller: _laporanCheckOutController,
                onChanged: (_) => setState(() {}),
              )
            : _buildTextAreaFieldInCard(
                'Laporan Pengamanan',
                (detail.notesCheckout != null && detail.notesCheckout!.isNotEmpty)
                    ? detail.notesCheckout!
                    : '-',
              ),
        16.verticalSpace,
        canEdit
            ? _buildEditablePhotoPickerCard(
                label: 'Foto Pengamanan',
                existingUrl: detail.photoCheckoutPengamanan?.url,
                pickedFile: _photoPengamananCheckOutFile,
                onPick: (file) {
                  setState(() {
                    _photoPengamananCheckOutFile = file;
                  });
                },
              )
            : _buildImageCard('Foto Pengamanan', detail.photoCheckoutPengamanan?.url),
        if (detail.carryOver != null && detail.carryOver!.isNotEmpty) ...[
          16.verticalSpace,
          _buildTextAreaFieldInCard('Tugas Tertunda', detail.carryOver!),
        ],
        16.verticalSpace,
        _buildInfoFieldInCard(
          'Jam Selesai Bekerja',
          detail.checkOut != null ? _formatTime(detail.checkOut!) : '-',
        ),
        16.verticalSpace,
        canEdit
            ? _buildEditableOvertimeToggleInCard()
            : _buildInfoFieldInCard('Lembur', detail.isOvertime ? 'Ya' : 'Tidak'),
        16.verticalSpace,
        if (canEdit && _isOvertime) ...[
          _buildEditablePhotoPickerCard(
            label: 'Bukti Lembur',
            existingUrl: detail.photoOvertime?.url,
            pickedFile: _photoLemburCheckOutFile,
            onPick: (file) {
              setState(() {
                _photoLemburCheckOutFile = file;
              });
            },
          ),
        ] else if (!canEdit) ...[
          _buildImageCard('Bukti Lembur', detail.photoOvertime?.url),
        ],
      ],
    );
  }

  Widget _buildEditableTextAreaFieldInCard({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
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
        TextField(
          controller: controller,
          maxLines: 4,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: primaryColor),
            ),
            contentPadding: REdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildEditablePhotoPickerCard({
    required String label,
    required String? existingUrl,
    required File? pickedFile,
    required ValueChanged<File> onPick,
  }) {
    final hasImage = pickedFile != null || (existingUrl != null && existingUrl.isNotEmpty);
    ImageProvider? imageProvider;
    if (pickedFile != null) {
      imageProvider = FileImage(pickedFile);
    } else if (existingUrl != null && existingUrl.isNotEmpty) {
      imageProvider = NetworkImage(existingUrl.startsWith('http') ? existingUrl : 'https:$existingUrl');
    }

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
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (hasImage && imageProvider != null) {
                  _showFullScreenImage(context, imageProvider);
                } else {
                  _pickImage(onPick);
                }
              },
              child: Container(
                width: double.infinity,
                height: 180.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: () {
                     if (hasImage && imageProvider != null) {
                      return Image(image: imageProvider, fit: BoxFit.cover);
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.grey.shade600),
                          8.verticalSpace,
                          Text(
                            'Tap untuk ambil foto',
                            style: TS.bodySmall.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }(),
                ),
              ),
            ),
            if (hasImage)
              Positioned(
                bottom: 8,
                right: 8,
                child: InkWell(
                  onTap: () => _pickImage(onPick),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(ValueChanged<File> onPick) async {
    XFile? xFile;
    try {
      xFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } on PlatformException {
      try {
        xFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
      } catch (_) {
        xFile = null;
      }
      if (mounted && xFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera tidak tersedia. Silakan pilih dari galeri.'),
          ),
        );
      }
    } catch (_) {
      xFile = null;
    }
    if (xFile == null) return;
    onPick(File(xFile.path));
  }

  Widget _buildEditableOvertimeToggleInCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lembur',
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        8.verticalSpace,
        Container(
          width: double.infinity,
          padding: REdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isOvertime ? 'Ya' : 'Tidak', style: TS.bodyMedium),
              Switch(
                value: _isOvertime,
                activeColor: primaryColor,
                onChanged: (v) {
                  setState(() {
                    _isOvertime = v;
                    if (!_isOvertime) {
                      _photoLemburCheckOutFile = null;
                    }
                  });
                },
              ),
            ],
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
              style: TS.titleMedium.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          4.verticalSpace,
          Center(
            child: Text(
              '${detail.jabatan} - ${detail.nrp}',
              style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFieldInCard(String label, String value) {
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
          child: Text(value, style: TS.bodyMedium),
        ),
      ],
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
          child: Text(value, style: TS.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildImageCard(String label, String? imageUrl) {
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
        if (imageUrl != null && imageUrl.isNotEmpty)
          GestureDetector(
            onTap: () {
              _showFullScreenImage(context, NetworkImage(imageUrl));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                imageUrl,
                height: 200.h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200.h,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: const Center(child: Icon(Icons.broken_image)),
                  );
                },
              ),
            ),
          )
        else
          Container(
            height: 100.h,
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.image_outlined, color: Colors.grey.shade600),
                8.horizontalSpace,
                Expanded(
                  child: Text(
                    'Tidak ada gambar',
                    style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPatrolSectionInCard(
    String routeName,
    List<RouteItem> listRoute,
    List<CarryOverItem> listCarryOver,
  ) {
    final allChecked = listCarryOver.isNotEmpty && listCarryOver.every((item) => item.isCompleted);

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
                style: TS.bodySmall.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
        if (listRoute.isNotEmpty) ...[
          16.verticalSpace,
          _buildPatrolTimeline(listRoute),
        ],
        if (listCarryOver.isEmpty) ...[
          16.verticalSpace,
          Text(
            'Belum ada data patroli',
            style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
          ),
        ] else ...[
          16.verticalSpace,
          Text(
            'Tugas Tertunda',
            style: TS.bodyMedium.copyWith(color: neutral90,fontWeight: FontWeight.bold,),
          ),
          // Text(
          // label,
          // style: TS.bodyMedium.copyWith(
            
          //   color: neutral90,
          // ),
        // ),
        // 8.verticalSpace,
          16.verticalSpace,
          ...listCarryOver.map(_buildPatrolItem),
        ],
      ],
    );
  }

  Widget _buildPatrolItem(CarryOverItem item) {
    final isCompleted = item.isCompleted;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: REdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          12.horizontalSpace,
          Expanded(
            child: Text(item.note, style: TS.bodyMedium.copyWith(color: neutral90)),
          ),
          8.horizontalSpace,
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              item.status,
              style: TS.bodySmall.copyWith(
                color: isCompleted ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
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
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          16.verticalSpace,
          Text(
            'Terjadi Kesalahan',
            style: TS.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          8.verticalSpace,
          Text(
            message,
            style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
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
      case 'REVISI':
        return 'Revisi';
      default:
        return status;
    }
  }

  Widget _buildPatrolTimeline(List<RouteItem> listRoute) {
    if (listRoute.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        16.verticalSpace,
        Text(
          'Timeline Patroli',
          style: TS.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: neutral90,
          ),
        ),
        16.verticalSpace,
        ...listRoute.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == listRoute.length - 1;
          return _buildPatrolTimelineItem(item, isLast);
        }),
      ],
    );
  }

  Widget _buildPatrolTimelineItem(RouteItem item, bool isLast) {
    final isChecked = item.checkDate != null;
    final checkDateLabel = item.checkDate != null ? _formatTime(item.checkDate!) : '-';
    final photoUrl = item.photoRoute?.url;
    final photoFilename = item.photoRoute?.filename;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final photoLabel = hasPhoto
        ? (photoFilename != null && photoFilename.isNotEmpty ? photoFilename : 'Lihat Foto')
        : 'Tidak Ada Foto';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 16.w,
                height: 16.w,
                decoration: BoxDecoration(
                  color: isChecked ? Colors.green : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isChecked
                    ? Icon(Icons.check, size: 10.w, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          12.horizontalSpace,
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.areasName,
                        style: TS.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: neutral90,
                        ),
                      ),
                    ],
                  ),
                  4.verticalSpace,
                  Text(
                    checkDateLabel,
                    style: TS.bodySmall.copyWith(
                      color: neutral50,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  6.verticalSpace,
                  hasPhoto
                      ? InkWell(
                          onTap: () {
                            _showFullScreenImage(context, NetworkImage(photoUrl));
                          },
                          child: Text(
                            photoLabel,
                            style: TS.bodySmall.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          photoLabel,
                          style: TS.bodySmall.copyWith(
                            color: neutral50,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.1,
              maxScale: 4.0,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: REdgeInsets.all(16),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
