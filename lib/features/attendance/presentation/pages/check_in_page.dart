import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/live_location_tracker.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../../../shared/widgets/TextInput/input_primary.dart';
import '../../../../shared/widgets/photo_picker_field.dart';
import '../../domain/entities/attendance_request.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';
import '../../../shift/data/datasources/shift_remote_data_source.dart';
import '../../../shift/data/models/shift_current_location_response.dart';
import '../../../schedule/data/datasources/schedule_remote_data_source.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/location_update_service.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class CheckInPage extends StatefulWidget {
  final String userId;
  final String namaPersonil;
  final String? prefillFullname;
  final String? prefillLocation;
  final String? prefillCurrentLocation;
  final String? prefillRouteName;
  final String? prefillShiftDetailId;
  final String? prefillTugasLanjutan; // Tugas lanjutan dari ListCarryOver

  const CheckInPage({
    Key? key,
    required this.userId,
    required this.namaPersonil,
    this.prefillFullname,
    this.prefillLocation,
    this.prefillCurrentLocation,
    this.prefillRouteName,
    this.prefillShiftDetailId,
    this.prefillTugasLanjutan,
  }) : super(key: key);

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  int currentStep = 0;
  late AttendanceBloc _attendanceBloc; // Add bloc reference

  // Controllers
  final _namaPersonilController = TextEditingController();
  final _lokasiPenugasanController = TextEditingController();
  final _lokasiTerkiniController = TextEditingController();
  final _rutePatroliController = TextEditingController();
  final _laporanPengamananController = TextEditingController();
  final _tugasLanjutanController = TextEditingController();

  // Form data
  String _pakaianPersonil = '';
  List<String> _fotoPengamanan = [];
  List<String> _tugasLanjutan = [];
  String? _fotoWajah;
  double? _currentLat;
  double? _currentLng;
  String? _shiftDetailId;

  @override
  void initState() {
    super.initState();
    _attendanceBloc = getIt<AttendanceBloc>();
    _attendanceBloc.add(const CheckInStartedEvent());
    _namaPersonilController.text =
        widget.prefillFullname ?? widget.namaPersonil;
    if (widget.prefillLocation != null) {
      _lokasiPenugasanController.text = widget.prefillLocation!;
    }
    _shiftDetailId = widget.prefillShiftDetailId;
    // Jika prefillShiftDetailId kosong, cek dari storage
    _loadShiftDetailIdFromStorage();
    final prefillCurrentLocation = widget.prefillCurrentLocation;
    if (prefillCurrentLocation != null && prefillCurrentLocation.isNotEmpty) {
      _lokasiTerkiniController.text = prefillCurrentLocation;
    } else {
      _lokasiTerkiniController.text = '-';
      _getCurrentLocation();
    }
    final prefillRouteName = widget.prefillRouteName;
    if (prefillRouteName != null && prefillRouteName.isNotEmpty) {
      _rutePatroliController.text = prefillRouteName;
    } else {
      _rutePatroliController.text = '-';
      if (prefillCurrentLocation != null && prefillCurrentLocation.isNotEmpty) {
        _getCurrentLocation();
      }
    }
    
    // Prefill tugas lanjutan dari ListCarryOver
    if (widget.prefillTugasLanjutan != null && widget.prefillTugasLanjutan!.isNotEmpty) {
      final tasks = widget.prefillTugasLanjutan!.split('\n').where((task) => task.trim().isNotEmpty).toList();
      _tugasLanjutan = tasks;
      if (_tugasLanjutan.isNotEmpty) {
        _tugasLanjutanController.text = _tugasLanjutan.join('\n');
        print('✅ CheckInPage initState - Tugas lanjutan: ${_tugasLanjutan.length} tasks');
      }
    }
    
    // Verify dan update UI setelah initState selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Pastikan controller terisi jika prefill ada
      if (widget.prefillTugasLanjutan != null && widget.prefillTugasLanjutan!.isNotEmpty) {
        if (_tugasLanjutanController.text != widget.prefillTugasLanjutan) {
          _tugasLanjutanController.text = widget.prefillTugasLanjutan!;
          _tugasLanjutan = widget.prefillTugasLanjutan!.split('\n').where((task) => task.trim().isNotEmpty).toList();
        }
      } else if (_tugasLanjutanController.text.isNotEmpty && _tugasLanjutan.isEmpty) {
        _tugasLanjutan = _tugasLanjutanController.text.split('\n').where((task) => task.trim().isNotEmpty).toList();
      }
      
      setState(() {});
    });
  }

  Future<void> _loadShiftDetailIdFromStorage() async {
    if (_shiftDetailId == null || _shiftDetailId!.isEmpty) {
      final storedId = await SecurityManager.readSecurely(AppConstants.shiftDetailIdKey);
      if (storedId != null && storedId.isNotEmpty) {
        setState(() {
          _shiftDetailId = storedId;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = getIt<LocationService>();
      final pos = await locationService.getCurrentLatLng();
      if (pos == null) {
        print('⚠️ [CheckIn] Failed to get GPS location - pos is null');
        if (mounted) {
          setState(() {
            _currentLat = null;
            _currentLng = null;
          });
        }
        return;
      }
      print('📍 [CheckIn] GPS location obtained: lat=${pos.lat}, lng=${pos.lng}');
      if (mounted) {
        setState(() {
          _currentLat = pos.lat;
          _currentLng = pos.lng;
        });
        _prefillFromShiftApi(pos.lat, pos.lng);
      }
    } catch (e) {
      print('❌ [CheckIn] Error getting GPS location: $e');
      if (mounted) {
        setState(() {
          _currentLat = null;
          _currentLng = null;
        });
      }
    }
  }

  Future<void> _prefillFromShiftApi(double lat, double lng) async {
    try {
      final shiftDs = getIt<ShiftRemoteDataSource>();
      final ShiftCurrentLocationResponse res =
          await shiftDs.getCurrentLocation(latitude: lat, longitude: lng);
      final data = res.data;
      if (!mounted) return;
      setState(() {
        if (data?.fullname != null) {
          _namaPersonilController.text = data!.fullname!;
        }
        if (data?.location != null) {
          _lokasiPenugasanController.text = data!.location!;
        }
        _lokasiTerkiniController.text =
            (data?.currentLocation != null && data!.currentLocation!.isNotEmpty)
                ? data.currentLocation!
                : '-';
        final routeName =
            (data?.routeName != null && data!.routeName!.isNotEmpty)
                ? data.routeName!
                : '-';
        _rutePatroliController.text = routeName;
        final newShiftDetailId = data?.shiftDetailId;
        if (newShiftDetailId != null && newShiftDetailId.isNotEmpty) {
          _shiftDetailId = newShiftDetailId;
          print('📋 ShiftDetailId from getCurrentLocation: $_shiftDetailId');
          
          // Simpan IdShiftDetail ke storage jika ada
          SecurityManager.storeSecurely(
            AppConstants.shiftDetailIdKey,
            newShiftDetailId,
          ).then((_) {
            print('✅ ShiftDetailId saved to storage from getCurrentLocation: $newShiftDetailId');
          });
        }
        
        // Ambil tugas lanjutan dari ListCarryOver (status OPEN)
        final carryOverTasks = data?.carryOverTasks;
        
        if (carryOverTasks != null && carryOverTasks.isNotEmpty) {
          _tugasLanjutan = carryOverTasks.split('\n').where((task) => task.trim().isNotEmpty).toList();
          _tugasLanjutanController.text = carryOverTasks;
          print('✅ _prefillFromShiftApi - Tugas lanjutan: ${_tugasLanjutan.length} tasks');
        }
        
        if (newShiftDetailId == null || newShiftDetailId.isEmpty) {
          print('⚠️ ShiftDetailId is null or empty from getCurrentLocation response');
          print('Response data - fullname: ${data?.fullname}, location: ${data?.location}');
        }
      });
    } catch (e) {
      // Fallback UI values unchanged on failure
    }
  }

  Future<void> _captureSelfie() async {
    if (!mounted) return;

    final permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin kamera diperlukan untuk mengambil foto.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengakses kamera: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cameras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera tidak tersedia.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final image = await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        builder: (_) => _SelfieCameraPage(cameras: cameras),
      ),
    );

    if (image != null && mounted) {
      setState(() {
        _fotoWajah = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: Build method should NOT do state mutation - this causes infinite rebuilds
    // Sync logic is handled in initState and PostFrameCallback only
    // Only display the current state without modifying it

    return BlocProvider.value(
      value: _attendanceBloc,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: const RumaraAppBar(title: 'Mulai Bekerja'),
        body: BlocConsumer<AttendanceBloc, AttendanceState>(
          listener: (context, state) {
            if (state is AttendanceCheckedIn) {
              // Simpan attendanceId ke storage jika ada (meskipun biasanya kosong dari backend)
              if (state.attendance.id.isNotEmpty) {
                SecurityManager.storeSecurely(
                  AppConstants.attendanceIdKey,
                  state.attendance.id,
                ).then((_) {
                  print('✅ CheckIn - attendanceId saved to storage: ${state.attendance.id}');
                });
              } else {
                // Simpan flag bahwa user sudah check-in (menggunakan timestamp sebagai identifier)
                final checkInTimestamp = DateTime.now().toIso8601String();
                SecurityManager.storeSecurely(
                  AppConstants.attendanceIdKey,
                  'checkin_$checkInTimestamp',
                ).then((_) {
                  print('✅ CheckIn - Check-in flag saved to storage (no attendanceId from backend)');
                });
              }
              
              // Update lokasi ke CurrentLocation/update setelah check-in berhasil
              // Skip verifikasi karena kita tahu user baru saja check-in
              try {
                final locationUpdateService = getIt<LocationUpdateService>();
                print('📍 [CheckIn] Updating location to CurrentLocation/update (skip verification)...');
                locationUpdateService.updateLocation(skipCheckInVerification: true).then((success) {
                  if (success) {
                    print('✅ [CheckIn] Location updated successfully to CurrentLocation/update');
                  } else {
                    print('⚠️ [CheckIn] Failed to update location to CurrentLocation/update');
                  }
                }).catchError((error) {
                  print('❌ [CheckIn] Error updating location: $error');
                });
              } catch (e) {
                print('❌ [CheckIn] Error getting LocationUpdateService: $e');
              }
              LiveLocationTracker.instance.start();
              
              // Show success dialog when check-in is successful
              // Return true to indicate successful check-in, so home page can reload data
              _showSuccessDialog().then((shouldReload) {
                if (shouldReload == true && mounted) {
                  Navigator.of(context).pop(true);
                }
              });
            } else if (state is AttendanceFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is CheckInFormState) {
              _syncCheckInState(state);
            }

            if (state is AttendanceLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Progress Indicator
                Container(
                  padding: REdgeInsets.all(20),
                  color: primaryColor,
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        Expanded(
                          child: Container(
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: i <= currentStep
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                        if (i < 2) 8.horizontalSpace,
                      ],
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: REdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 24.h,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: REdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _buildStepContent(),
                    ),
                  ),
                ),

                BottomActionBar(child: _buildBottomButtons()),
              ],
            );
          },
        ),
      ),
    );
  }

  void _syncCheckInState(CheckInFormState state) {
    final tasks = state.tugasLanjutan;
    if (!listEquals(tasks, _tugasLanjutan)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _tugasLanjutan = List<String>.from(tasks);
        });
      });
    }
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Face Scan Section
        InkWell(
          onTap: _captureSelfie,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            height: 280.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.blue.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Stack(
              children: [
                // Corner brackets
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.blue.shade700, width: 4),
                        left: BorderSide(color: Colors.blue.shade700, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.blue.shade700, width: 4),
                        right:
                            BorderSide(color: Colors.blue.shade700, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.blue.shade700, width: 4),
                        left: BorderSide(color: Colors.blue.shade700, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.blue.shade700, width: 4),
                        right:
                            BorderSide(color: Colors.blue.shade700, width: 4),
                      ),
                    ),
                  ),
                ),
                // Center content
                Center(
                  child: _fotoWajah == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 48.sp,
                              color: Colors.grey.shade600,
                            ),
                            12.verticalSpace,
                            Text(
                              'Ketuk untuk mengambil foto wajah',
                              style: TS.bodyMedium.copyWith(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            File(_fotoWajah!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        24.verticalSpace,

        // Form Fields
        InputPrimary(
          label: 'Nama Personil',
          controller: _namaPersonilController,
          readOnly: true,
          margin: REdgeInsets.only(bottom: 16),
        ),

        InputPrimary(
          label: 'Lokasi Penjagaan',
          controller: _lokasiPenugasanController,
          readOnly: true,
          margin: REdgeInsets.only(bottom: 16),
        ),

        InputPrimary(
          label: 'Lokasi Terkini',
          controller: _lokasiTerkiniController,
          readOnly: true,
          margin: REdgeInsets.only(bottom: 16),
          suffixIcon: IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ),

        InputPrimary(
          label: 'Rute Patroli',
          controller: _rutePatroliController,
          enable: false,
          margin: REdgeInsets.only(bottom: 16),
        ),

        // Location validation warning
        if (_lokasiTerkiniController.text != _lokasiPenugasanController.text)
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 20.sp,
                ),
                8.horizontalSpace,
                Expanded(
                  child: Text(
                    'Di luar area penjagaan, harap dekat lokasi.',
                    style: TS.bodySmall.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoPickerField(
          label: 'Pakaian Personil',
          photos: _pakaianPersonil.isEmpty ? [] : [_pakaianPersonil],
          onPhotosChanged: (photos) {
            setState(() {
              _pakaianPersonil = photos.isNotEmpty ? photos.first : '';
            });
          },
          isRequired: true,
          maxPhotos: 1,
          margin: REdgeInsets.only(bottom: 16),
        ),

        InputPrimary(
          label: 'Laporan Pengamanan',
          controller: _laporanPengamananController,
          hint: 'Keterangan Pengamanan',
          maxLines: 4,
          maxLength: TextField.noMaxLength,
          margin: REdgeInsets.only(bottom: 16),
          isRequired: true,
        ),

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

        // Gunakan ValueKey dengan controller text untuk memaksa rebuild ketika controller berubah
        InputPrimary(
          key: ValueKey('tugas_lanjutan_${_tugasLanjutanController.text}'),
          label: 'Tugas Lanjutan',
          controller: _tugasLanjutanController,
          hint: 'Tugas lanjutan akan terisi otomatis',
          enable: false,
          readOnly: true,
          maxLines: (_tugasLanjutan.isEmpty && _tugasLanjutanController.text.isEmpty)
              ? 1
              : (_tugasLanjutan.isNotEmpty
                  ? (_tugasLanjutan.length > 3 ? 4 : _tugasLanjutan.length)
                  : (_tugasLanjutanController.text.split('\n').length > 3 
                      ? 4 
                      : _tugasLanjutanController.text.split('\n').length)),
          margin: REdgeInsets.only(bottom: 12),
        ),

        if (_tugasLanjutan.isEmpty && _tugasLanjutanController.text.isEmpty)
          Container(
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'Belum ada data tugas lanjutan. Data akan tampil otomatis setelah tersedia dari sistem.',
              style: TS.bodySmall.copyWith(
                color: Colors.amber.shade900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: REdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48.sp,
                color: Colors.green,
              ),
              12.verticalSpace,
              Text(
                'Konfirmasi Data',
                style: TS.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              8.verticalSpace,
              Text(
                'Pastikan semua data yang Anda masukkan sudah benar',
                style: TS.bodyMedium.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        24.verticalSpace,

        // Summary
        _buildSummaryItem('Nama Personil', _namaPersonilController.text),
        _buildSummaryItem('Lokasi Penugasan', _lokasiPenugasanController.text),
        _buildSummaryItem('Lokasi Terkini', _lokasiTerkiniController.text),
        _buildSummaryItem('Foto Wajah', _fotoWajah != null ? 'Tersimpan' : '-'),
        _buildSummaryItem('Rute Patroli', _rutePatroliController.text),
        _buildSummaryItemWithImage('Pakaian Personil', _pakaianPersonil),
        _buildSummaryItem(
            'Laporan Pengamanan', _laporanPengamananController.text),
        _buildSummaryItemWithImages('Foto Pengamanan', _fotoPengamanan),
        _buildSummaryItem(
          'Tugas Lanjutan',
          _tugasLanjutan.isEmpty ? '-' : _tugasLanjutan.join(', '),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: REdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(': ', style: TS.bodyMedium),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TS.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemWithImage(String label, String imagePath) {
    final hasImage = imagePath.isNotEmpty;
    final isLocalFile = hasImage && 
                       !imagePath.startsWith('http://') && 
                       !imagePath.startsWith('https://');
    
    return Padding(
      padding: REdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(': ', style: TS.bodyMedium),
          Expanded(
            child: hasImage
                ? GestureDetector(
                    onTap: () => _showFullImageInSummary(imagePath, 0),
                    child: Container(
                      width: 80.w,
                      height: 80.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: isLocalFile
                            ? Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 24.sp,
                                      color: Colors.grey.shade400,
                                    ),
                                  );
                                },
                              )
                            : Image.network(
                                imagePath,
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
                  )
                : Text(
                    '-',
                    style: TS.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemWithImages(String label, List<String> imagePaths) {
    return Padding(
      padding: REdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(': ', style: TS.bodyMedium),
          Expanded(
            child: imagePaths.isEmpty
                ? Text(
                    '-',
                    style: TS.bodyMedium,
                  )
                : Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: imagePaths.asMap().entries.map((entry) {
                      final index = entry.key;
                      final imagePath = entry.value;
                      final isLocalFile = !imagePath.startsWith('http://') && 
                                         !imagePath.startsWith('https://');
                      
                      return GestureDetector(
                        onTap: () => _showFullImageInSummary(imagePath, index, allImages: imagePaths),
                        child: Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: isLocalFile
                                ? Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 24.sp,
                                          color: Colors.grey.shade400,
                                        ),
                                      );
                                    },
                                  )
                                : Image.network(
                                    imagePath,
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
          ),
        ],
      ),
    );
  }

  void _showFullImageInSummary(String imagePath, int index, {List<String>? allImages}) {
    final isLocalFile = !imagePath.startsWith('http://') && 
                       !imagePath.startsWith('https://');
    final images = allImages ?? [imagePath];
    
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
                child: isLocalFile
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
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
                      )
                    : Image.network(
                        imagePath,
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
            if (images.length > 1)
              Positioned(
                bottom: 20.h,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1} / ${images.length}',
                      style: TS.bodyMedium.copyWith(
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (currentStep == 0) {
      return Row(
        children: [
          Expanded(
            child: UIButton(
              text: 'Kembali',
              buttonType: UIButtonType.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: UIButton(
              text: 'Lanjut',
              onPressed: _canProceedFromStep1()
                  ? () {
                      setState(() {
                        currentStep = 1;
                      });
                    }
                  : null,
            ),
          ),
        ],
      );
    } else if (currentStep == 1) {
      return Row(
        children: [
          Expanded(
            child: UIButton(
              text: 'Kembali',
              buttonType: UIButtonType.outline,
              onPressed: () {
                setState(() {
                  currentStep = 0;
                });
              },
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: UIButton(
              text: 'Lanjut',
              onPressed: _canProceedFromStep2()
                  ? () {
                      setState(() {
                        currentStep = 2;
                      });
                    }
                  : null,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: UIButton(
              text: 'Kembali',
              buttonType: UIButtonType.outline,
              onPressed: () {
                setState(() {
                  currentStep = 1;
                });
              },
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: UIButton(
              text: 'Mulai Bekerja',
              onPressed: _submitCheckIn,
            ),
          ),
        ],
      );
    }
  }

  bool _canProceedFromStep1() {
    final routeName = _rutePatroliController.text.trim();
    return routeName.isNotEmpty && routeName != '-' && _fotoWajah != null;
  }

  bool _canProceedFromStep2() {
    return _pakaianPersonil.isNotEmpty &&
        _laporanPengamananController.text.isNotEmpty &&
        _fotoPengamanan.isNotEmpty;
  }

  void _submitCheckIn() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 30,
              ),
            ),
            20.verticalSpace,
            Text(
              'Apakah Anda yakin\nmengirim laporan bekerja?',
              textAlign: TextAlign.center,
              style: TS.titleMedium.copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: REdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    'Ya',
                    style: TS.labelLarge.copyWith(fontSize: 16.sp),
                  ),
                ),
              ),
              10.verticalSpace,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: REdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Tidak',
                    style: TS.labelLarge.copyWith(fontSize: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      print('🚀 Submit CheckIn - Starting...');
      print('🚀 Submit CheckIn - _shiftDetailId: $_shiftDetailId');
      
      // Cek jika shiftDetailId kosong, ambil dari storage atau hit API
      String? shiftDetailId = _shiftDetailId;
      print('🚀 Submit CheckIn - shiftDetailId initial: $shiftDetailId');
      
      if (shiftDetailId == null || shiftDetailId.isEmpty) {
        print('⚠️ Submit CheckIn - shiftDetailId is empty, checking storage...');
        // Cek dari storage dulu
        shiftDetailId = await SecurityManager.readSecurely(AppConstants.shiftDetailIdKey);
        
        // Jika masih kosong, hit API /Shift/get_current untuk mendapatkan IdShiftDetail
        if (shiftDetailId == null || shiftDetailId.isEmpty) {
          try {
            final scheduleDs = getIt<ScheduleRemoteDataSource>();
            final userId = widget.userId;
            final body = {'IdUser': userId};
            
            final resp = await scheduleDs.getCurrentShift(body);
            
            print('📋 Full response from /Shift/get_current:');
            print('  - succeeded: ${resp.succeeded}');
            print('  - code: ${resp.code}');
            print('  - message: ${resp.message}');
            print('  - data: ${resp.data != null ? "exists" : "null"}');
            if (resp.data != null) {
              print('  - data.id: ${resp.data!.id}');
              print('  - data.name: ${resp.data!.name}');
              print('  - data.checkin: ${resp.data!.checkin}');
            }
            
            // Ambil Id dari response sebagai IdShiftDetail (field IdShiftDetail tidak ada di response)
            shiftDetailId = resp.data?.id;
            
            print('📋 ShiftDetailId extracted from /Shift/get_current API (using data.id): $shiftDetailId');
            
            // Simpan ke storage jika berhasil mendapatkan
            if (shiftDetailId != null && shiftDetailId.isNotEmpty) {
              await SecurityManager.storeSecurely(
                AppConstants.shiftDetailIdKey,
                shiftDetailId,
              );
              print('✅ ShiftDetailId saved to storage: $shiftDetailId');
              // Update state juga
              setState(() {
                _shiftDetailId = shiftDetailId;
              });
            } else {
              print('⚠️ ShiftDetailId is null or empty from /Shift/get_current API response');
            }
          } catch (e) {
            // Jika API gagal, tetap lanjut submit dengan shiftDetailId kosong
            print('❌ Error getting shiftDetailId from /Shift/get_current: $e');
          }
        } else {
          print('✅ ShiftDetailId from storage: $shiftDetailId');
        }
      } else {
        print('✅ ShiftDetailId already set: $shiftDetailId');
      }
      
      print('📤 Submitting with ShiftDetailId: $shiftDetailId');
      
      // Validasi: Pastikan shiftDetailId tidak kosong sebelum submit
      if (shiftDetailId == null || shiftDetailId.isEmpty) {
        print('❌ ERROR: ShiftDetailId is still empty/null before submit!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift Detail tidak ditemukan. Silakan coba lagi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Validasi: Pastikan GPS location sudah tersedia sebelum submit
      // Jika masih null, coba ambil lagi
      double? finalLat = _currentLat;
      double? finalLng = _currentLng;
      
      if (finalLat == null || finalLng == null || finalLat == 0.0 || finalLng == 0.0) {
        print('⚠️ [CheckIn] GPS location is null or 0, attempting to get location again...');
        print('  Current values: lat=$finalLat, lng=$finalLng');
        
        try {
          final locationService = getIt<LocationService>();
          final pos = await locationService.getCurrentLatLng();
          if (pos != null && pos.lat != 0.0 && pos.lng != 0.0) {
            finalLat = pos.lat;
            finalLng = pos.lng;
            print('✅ [CheckIn] GPS location obtained before submit: lat=$finalLat, lng=$finalLng');
          } else {
            print('❌ [CheckIn] Failed to get GPS location before submit - pos is null or 0');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal mendapatkan lokasi GPS. Pastikan GPS aktif dan izin lokasi sudah diberikan.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        } catch (e) {
          print('❌ [CheckIn] Error getting GPS location before submit: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error mendapatkan lokasi GPS: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } else {
        print('✅ [CheckIn] GPS location already available: lat=$finalLat, lng=$finalLng');
      }
      
      // Submit to bloc - success dialog will be shown by listener
      // Safety limit: prevent sending massive tugasLanjutan lists
      List<String> safeTugasLanjutan = _tugasLanjutan;
      if (_tugasLanjutan.length > 100) {
        print('⚠️ [CheckIn] tugasLanjutan list too large (${_tugasLanjutan.length}), limiting to first 100');
        safeTugasLanjutan = _tugasLanjutan.take(100).toList();
      }
      
      final request = CheckInRequest(
        userId: widget.userId,
        shift: 'Pagi',
        lokasiPenugasan: _lokasiPenugasanController.text,
        lokasiTerkini: _lokasiTerkiniController.text,
        latitude: finalLat,
        longitude: finalLng,
        ratePatrol: _rutePatroliController.text,
        pakaianPersonil: _pakaianPersonil,
        laporanPengamanan: _laporanPengamananController.text,
        fotoPengamanan: _fotoPengamanan,
        tugasLanjutan: safeTugasLanjutan,
        fotoWajah: _fotoWajah,
        shiftDetailId: shiftDetailId, // Pastikan ini tidak null/kosong
      );
      
      print('✅ [CheckIn] CheckInRequest created with GPS: lat=${request.latitude}, lng=${request.longitude}');
      
      print('✅ CheckInRequest created with shiftDetailId: ${request.shiftDetailId}');

      _attendanceBloc.add(CheckInSubmittedEvent(request));
    }
  }

  Future<bool> _showSuccessDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.w,
              height: 60.h,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 30,
              ),
            ),
            20.verticalSpace,
            Text(
              'Check In Berhasil',
              style: TS.titleLarge.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            8.verticalSpace,
            Text(
              'Selamat Bekerja!',
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Return true to indicate success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: REdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text(
                'OK',
                style: TS.labelLarge.copyWith(fontSize: 16.sp),
              ),
            ),
          ),
        ],
      ),
    );
    
    // Return result (true jika user klik OK, false jika dialog ditutup)
    return result ?? false;
  }

  @override
  void dispose() {
    _attendanceBloc.close();
    _namaPersonilController.dispose();
    _lokasiPenugasanController.dispose();
    _lokasiTerkiniController.dispose();
    _rutePatroliController.dispose();
    _laporanPengamananController.dispose();
    _tugasLanjutanController.dispose();
    super.dispose();
  }
}

class _SelfieCameraPage extends StatefulWidget {
  const _SelfieCameraPage({required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<_SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<_SelfieCameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _currentCameraIndex = 0;
  bool _isControllerCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera(0);
  }

  void _initializeCamera(int index) {
    if (_isControllerCreated) {
      _controller.dispose();
    }
    _controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _isControllerCreated = true;
    _initializeControllerFuture = _controller.initialize();
  }

  void _switchCamera() {
    if (widget.cameras.length < 2) return;
    
    setState(() {
      _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
      _initializeCamera(_currentCameraIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RumaraAppBar(title: 'Ambil Foto Wajah'),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      widget.cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: CameraPreview(_controller),
                            )
                          : CameraPreview(_controller),
                      if (widget.cameras.length > 1)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton(
                            onPressed: _switchCamera,
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 32,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: REdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  color: Colors.black,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Posisikan wajah dalam frame lalu tekan tombol kamera.',
                        style: TS.bodyMedium.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      16.verticalSpace,
                      SizedBox(
                        width: 72.r,
                        height: 72.r,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                            elevation: 6,
                          ),
                          onPressed: () async {
                            try {
                              await _initializeControllerFuture;
                              final image = await _controller.takePicture();
                              if (!mounted) return;
                              Navigator.of(context).pop(image);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal mengambil foto: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Icon(
                            Icons.camera_alt,
                            color: primaryColor,
                            size: 32.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
