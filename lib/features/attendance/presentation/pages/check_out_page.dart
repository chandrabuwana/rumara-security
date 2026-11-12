import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/photo_picker_field.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/entities/attendance_request.dart';
import '../../../shift/data/models/shift_checkout_detail_response.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class CheckOutPage extends StatefulWidget {
  final String userId;
  final String attendanceId;
  final ShiftCheckoutDetailData? checkoutDetail;

  const CheckOutPage({
    Key? key,
    required this.userId,
    required this.attendanceId,
    this.checkoutDetail,
  }) : super(key: key);

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  late AttendanceBloc _attendanceBloc; // Add bloc reference

  // Controllers
  final _lokasiPengamananController = TextEditingController();
  final _laporanPengamananController = TextEditingController();
  final _tugasTertundaController = TextEditingController();

  // Form data
  String _statusTugas = 'selesai'; // Default selesai, tidak ditampilkan di form
  String _pakaianPersonil = '';
  List<String> _fotoPengamanan = [];
  List<String> _buktiLembur = [];
  String _lembur = 'Tidak'; // Lembur dropdown
  String _adaTugasBelumSelesai = 'Tidak'; // Default Tidak
  ShiftCheckoutDetailData? _checkoutDetail;
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _attendanceBloc = getIt<AttendanceBloc>();
    _checkoutDetail = widget.checkoutDetail;
    _applyPrefillDetail(_checkoutDetail);
    _lokasiPengamananController.addListener(_onFormChanged);
    _laporanPengamananController.addListener(_onFormChanged);
    _getCurrentGPSLocation();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _getCurrentGPSLocation() async {
    try {
      final locationService = getIt<LocationService>();
      final position = await locationService.getCurrentLatLng();
      
      if (position != null) {
        setState(() {
          _currentLatitude = position.lat;
          _currentLongitude = position.lng;
        });
      } else {
        print('⚠️ CheckOut - GPS tidak tersedia');
      }
    } catch (e) {
      print('❌ CheckOut - Error mengambil lokasi GPS: $e');
    }
  }

  void _applyPrefillDetail(ShiftCheckoutDetailData? detail) {
    if (detail == null) return;

    // Ambil CurrentLocation dari response, fallback ke guardLocation
    final locationName = detail.currentLocation ?? detail.guardLocation;
    if (locationName != null && locationName.isNotEmpty) {
      _lokasiPengamananController.text = locationName;
    }

    final report = detail.securityReport;
    if (report != null && report.isNotEmpty) {
      _laporanPengamananController.text = report;
    }

    final outfit = detail.pakaianPersonilNormalized;
    if (outfit != null && outfit.isNotEmpty) {
      _pakaianPersonil = outfit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _attendanceBloc..add(const CheckOutStartedEvent()),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: const RumaraAppBar(title: 'Akhiri Bekerja'),
        body: BlocConsumer<AttendanceBloc, AttendanceState>(
          listener: (context, state) {
            if (state is AttendanceCheckedOut) {
              // Close loading dialog if exists
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              // Return true to indicate successful checkout, so home page can reload data
              Navigator.of(context).pop(true);
            } else if (state is AttendanceFailure) {
              // Close loading dialog if exists
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is AttendanceLoading) {
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
            }
          },
          builder: (context, state) {
            // Remove loading check from builder since it's handled in listener

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: REdgeInsets.all(16),
                    child: Container(
                    padding: REdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: rumaraBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patroli Section (Read-only status)
                        _buildReadOnlyStatusField(
                          label: 'Patroli',
                          value: _checkoutDetail?.patrolStatusLabel ??
                              _checkoutDetail?.patrolDescription ??
                              'Selesai (5/5 Tempat Telah Diperiksa)',
                        ),
                        16.verticalSpace,

                        // Tugas Lanjutan Section (Read-only status)
                        _buildReadOnlyStatusField(
                          label: 'Tugas Lanjutan',
                          value: (_checkoutDetail?.statusCarryOverLabel ?? '').trim().isNotEmpty
                              ? _checkoutDetail!.statusCarryOverLabel!.trim()
                              : (_checkoutDetail?.followUpStatusLabel ?? '').trim().isNotEmpty
                                  ? _checkoutDetail!.followUpStatusLabel!.trim()
                                  : (_checkoutDetail?.followUpDescription ?? '').trim().isNotEmpty
                                      ? _checkoutDetail!.followUpDescription!.trim()
                                      : '-',
                        ),
                        16.verticalSpace,

                        // Lokasi Pengamanan
                        InputPrimary(
                          label: 'Lokasi Pengamanan',
                          controller: _lokasiPengamananController,
                          hint: 'Lokasi Pengamanan',
                          readOnly: true,
                          margin: REdgeInsets.only(bottom: 16),
                          isRequired: true,
                        ),

                        // Pakaian Personil (Photo field)
                        PhotoPickerField(
                          label: 'Pakaian Personil',
                          photos: _pakaianPersonil.isEmpty
                              ? []
                              : [_pakaianPersonil],
                          onPhotosChanged: (photos) {
                            setState(() {
                              _pakaianPersonil =
                                  photos.isNotEmpty ? photos.first : '';
                            });
                          },
                          isRequired: true,
                          multiple: false,
                          maxPhotos: 1,
                          margin: REdgeInsets.only(bottom: 16),
                        ),

                        // Laporan Pengamanan
                        InputPrimary(
                          label: 'Laporan Pengamanan',
                          controller: _laporanPengamananController,
                          hint: 'Keterangan Pengamanan',
                          maxLines: 4,
                          maxLength: TextField.noMaxLength,
                          margin: REdgeInsets.only(bottom: 16),
                          isRequired: true,
                        ),

                        // Foto Pengamanan
                        PhotoPickerField(
                          label: 'Foto Pengamanan',
                          photos: _fotoPengamanan,
                          onPhotosChanged: (photos) {
                            setState(() {
                              _fotoPengamanan = photos;
                            });
                          },
                          isRequired: true,
                          multiple: false,
                          maxPhotos: 1,
                          margin: REdgeInsets.only(bottom: 16),
                        ),

                        // Tugas Belum Selesai Dropdown
                        CustomDropdown<String>(
                          label: 'Terdapat tugas yang belum terselesaikan?',
                          hint: 'Pilih',
                          value: _adaTugasBelumSelesai.isEmpty ? null : _adaTugasBelumSelesai,
                          items: [
                            DropdownItem(value: 'Tidak', text: 'Tidak'),
                            DropdownItem(value: 'Ya', text: 'Ya'),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _adaTugasBelumSelesai = value ?? 'Tidak';
                              // Update status tugas based on selection
                              _statusTugas = (_adaTugasBelumSelesai == 'Ya') ? 'tidak_selesai' : 'selesai';
                              // Clear tugas tertunda if user selects Tidak
                              if (_adaTugasBelumSelesai == 'Tidak') {
                                _tugasTertundaController.clear();
                              }
                            });
                          },
                          isRequired: true,
                          margin: REdgeInsets.only(bottom: 16),
                        ),

                        // Tugas Tertunda (enabled only when Ada Tugas Belum Selesai = Ya)
                        InputPrimary(
                          label: 'Tugas Lanjutan',
                          controller: _tugasTertundaController,
                          hint: 'Keterangan Tugas Lanjutan',
                          maxLines: 4,
                          maxLength: TextField.noMaxLength,
                          margin: REdgeInsets.only(bottom: 16),
                          isRequired: _adaTugasBelumSelesai == 'Ya',
                          enable: _adaTugasBelumSelesai == 'Ya',
                        ),

                        // Lembur Dropdown
                        CustomDropdown<String>(
                          label: 'Lembur',
                          hint: 'Pilih Lembur',
                          value: _lembur.isEmpty ? null : _lembur,
                          items: [
                            DropdownItem(value: 'Tidak', text: 'Tidak'),
                            DropdownItem(value: 'Ya', text: 'Ya'),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _lembur = value ?? 'Tidak';
                            });
                          },
                          isRequired: false,
                          margin: REdgeInsets.only(bottom: 16),
                        ),

                        // Bukti Lembur (Photo field)
                        PhotoPickerField(
                          label: 'Bukti Lembur',
                          photos: _buktiLembur,
                          onPhotosChanged: (photos) {
                            setState(() {
                              _buktiLembur = photos;
                            });
                          },
                          isRequired: false,
                          multiple: false,
                          maxPhotos: 1,
                          margin: REdgeInsets.only(bottom: 16),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
                BottomActionBar(
                  helper: _missingCheckOutFields(),
                  child: UIButton(
                    text: 'Akhiri Bekerja',
                    fullWidth: true,
                    onPressed: _canSubmitCheckOut() ? _submitCheckOut : null,
                    variant: UIButtonVariant.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadOnlyStatusField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TS.labelLarge,
        ),
        8.verticalSpace,
        Container(
          width: double.infinity,
          padding: REdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: TS.bodyMedium.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String? _missingCheckOutFields() {
    final missing = <String>[
      if (_lokasiPengamananController.text.isEmpty) 'Lokasi Pengamanan',
      if (_pakaianPersonil.isEmpty) 'Pakaian Personil',
      if (_laporanPengamananController.text.isEmpty) 'Laporan Pengamanan',
      if (_fotoPengamanan.isEmpty) 'Foto Pengamanan',
    ];
    if (missing.isEmpty) return null;
    return 'Lengkapi dulu: ${missing.join(', ')}';
  }

  bool _canSubmitCheckOut() {
    return _lokasiPengamananController.text.isNotEmpty &&
        _pakaianPersonil.isNotEmpty &&
        _laporanPengamananController.text.isNotEmpty &&
        _fotoPengamanan.isNotEmpty;
  }

  void _submitCheckOut() async {
    String confirmMessage = 'Pastikan semua data sudah benar dan lengkap sebelum mengakhiri tugas hari ini.';
    String confirmTitle = 'Konfirmasi Akhiri Bekerja';
    IconData confirmIcon = Icons.logout_rounded;
    Color confirmIconColor = primaryColor;

    if (_statusTugas == 'tidak_selesai') {
      confirmTitle = '⚠️ Tugas Belum Selesai';
      confirmMessage =
          'Anda memiliki tugas yang belum selesai. Apakah Anda yakin ingin mengakhiri tugas sekarang?\n\nPastikan Anda sudah menyelesaikan semua tugas yang diperlukan.';
      confirmIcon = Icons.warning_rounded;
      confirmIconColor = Colors.orange;
    }

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: confirmTitle,
      message: confirmMessage,
      icon: confirmIcon,
      iconColor: confirmIconColor,
      confirmText: 'Ya, Akhiri Bekerja',
      cancelText: 'Batal',
      isDestructive: _statusTugas == 'tidak_selesai',
    );

    if (confirmed == true && mounted) {
      // Get shiftDetailId from checkoutDetail, fallback to storage
      String? shiftDetailId = _checkoutDetail?.shiftDetailId;
      if (shiftDetailId == null || shiftDetailId.isEmpty) {
        shiftDetailId = await SecurityManager.readSecurely(AppConstants.shiftDetailIdKey);
        print('📋 CheckOut - shiftDetailId from storage: $shiftDetailId');
      } else {
        print('📋 CheckOut - shiftDetailId from checkoutDetail: $shiftDetailId');
      }

      final coTask = _statusTugas == 'tidak_selesai' && _tugasTertundaController.text.isNotEmpty
          ? _tugasTertundaController.text
          : null;

      print('📤 CheckOut - Submitting checkout request:');
      print('  - userId: ${widget.userId}');
      print('  - shiftDetailId: $shiftDetailId');
      print('  - lokasiPenugasanAkhir: ${_lokasiPengamananController.text}');
      print('  - isOvertime: ${_lembur == 'Ya'}');
      print('  - fotoWajah (PhotoAbsen - foto pakaian): ${_pakaianPersonil.isNotEmpty ? "EXISTS (${_pakaianPersonil})" : "NULL"}');
      print('  - fotoPengamanan count: ${_fotoPengamanan.length}');
      print('  - buktiLaporan count: ${_buktiLembur.length}');

      // Get GPS location if not available
      if (_currentLatitude == null || _currentLongitude == null) {
        await _getCurrentGPSLocation();
      }
      
      if (_currentLatitude == null || _currentLongitude == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lokasi GPS belum tersedia. Silakan aktifkan GPS dan coba lagi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('  - latitude: $_currentLatitude (GPS real device)');
      print('  - longitude: $_currentLongitude (GPS real device)');

      // fotoWajah harus diisi dengan foto pakaian (_pakaianPersonil) karena foto pakaian dikirim sebagai PhotoAbsen
      final request = CheckOutRequest(
        userId: widget.userId,
        attendanceId: widget.attendanceId,
        shiftDetailId: shiftDetailId,
        lokasiPenugasanAkhir: _lokasiPengamananController.text,
        statusTugas: _statusTugas,
        pakaianPersonil: _pakaianPersonil,
        laporanPengamanan: _laporanPengamananController.text,
        fotoPengamanan: _fotoPengamanan,
        buktiLaporan: _buktiLembur,
        fotoWajah: _pakaianPersonil.isNotEmpty ? _pakaianPersonil : null, // Foto pakaian dikirim sebagai PhotoAbsen
        coTask: _tugasTertundaController.text.isNotEmpty ? _tugasTertundaController.text : coTask,
        isOvertime: _lembur == 'Ya',
        latitude: _currentLatitude, // Use GPS real device location
        longitude: _currentLongitude, // Use GPS real device location
      );

      _attendanceBloc.add(CheckOutSubmittedEvent(request));
    }
  }

  @override
  void dispose() {
    _lokasiPengamananController.dispose();
    _laporanPengamananController.dispose();
    _tugasTertundaController.dispose();
    // Don't close bloc here as it's managed by DI container
    super.dispose();
  }
}

