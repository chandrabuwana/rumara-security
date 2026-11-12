import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/patrol_location.dart';
import '../bloc/attendance_bloc.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';
import '../../../../core/design/colors.dart';

class AttendanceFormPage extends StatefulWidget {
  final PatrolLocation location;

  const AttendanceFormPage({
    super.key,
    required this.location,
  });

  @override
  State<AttendanceFormPage> createState() => _AttendanceFormPageState();
}

class _AttendanceFormPageState extends State<AttendanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _currentLocationController = TextEditingController();
  
  String? _selectedPatrolLocation;
  File? _proofImage;
  bool _isLocationVerified = false;
  String _verificationMessage = '';
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _selectedPatrolLocation = widget.location.name;
    
    // Get GPS location on init
    _getCurrentGPSLocation();
    
    // Add delay to ensure BlocProvider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatrolAttendanceBloc>().add(GetCurrentLocationEvent());
    });
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS tidak tersedia. Silakan aktifkan GPS.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil lokasi GPS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _currentLocationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Show picker dialog to choose between Camera and Gallery
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Sumber Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Kamera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Galeri'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      if (source == ImageSource.camera) {
        // Initialize camera if not already done
        if (_cameras == null) {
          _cameras = await availableCameras();
        }

        if (_cameras!.isNotEmpty) {
          final result = await Navigator.push<XFile?>(
            context,
            MaterialPageRoute(
              builder: (_) => CameraCapturePage(cameras: _cameras!),
            ),
          );

          if (result != null) {
            setState(() {
              _proofImage = File(result.path);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto berhasil diambil'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // Pick from gallery
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _proofImage = File(image.path);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil dipilih dari galeri'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyLocation() async {
    // Check if current location is loaded, if not show message
    if (_currentLocationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sedang memuat lokasi saat ini...'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Trigger location loading again
      context.read<PatrolAttendanceBloc>().add(GetCurrentLocationEvent());
      return;
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Memverifikasi lokasi...'),
          ],
        ),
      ),
    );
    
    // Get GPS location if not available
    if (_currentLatitude == null || _currentLongitude == null) {
      await _getCurrentGPSLocation();
    }
    
    if (_currentLatitude == null || _currentLongitude == null) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi GPS belum tersedia. Silakan aktifkan GPS dan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    context.read<PatrolAttendanceBloc>().add(
      VerifyLocationEvent(
        currentLatitude: _currentLatitude!,
        currentLongitude: _currentLongitude!,
        targetLatitude: widget.location.latitude,
        targetLongitude: widget.location.longitude,
      ),
    );
  }

  Future<void> _submitAttendance() async {
    if (_formKey.currentState!.validate()) {
      if (_proofImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap ambil foto bukti terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (!_isLocationVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap verifikasi lokasi terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Get GPS location if not available
      if (_currentLatitude == null || _currentLongitude == null) {
        await _getCurrentGPSLocation();
      }
      
      if (_currentLatitude == null || _currentLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi GPS belum tersedia. Silakan aktifkan GPS dan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      context.read<PatrolAttendanceBloc>().add(
        SubmitAttendanceEvent(
          patrolLocationId: widget.location.id,
          currentAddress: _currentLocationController.text,
          proofImagePath: _proofImage!.path,
          currentLatitude: _currentLatitude!,
          currentLongitude: _currentLongitude!,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PatrolAttendanceBloc, AttendanceState>(
      listener: (context, state) {
          if (state is AttendanceSubmitted) {
            // Close any existing dialog
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            _showSuccessDialog(state.message);
          } else if (state is LocationVerified) {
            // Close loading dialog
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            // Show verification result popup
            _showLocationVerificationDialog(state.isVerified, state.message);
            
            setState(() {
              _isLocationVerified = state.isVerified;
              _verificationMessage = state.message;
            });
          } else if (state is CurrentLocationLoaded) {
            setState(() {
              _currentLocationController.text = state.address;
            });
          } else if (state is AttendanceError) {
            // Close loading dialog if exists
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: const RumaraAppBar(title: 'Patroli Hari Ini'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '3/5',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Patroli Selesai',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Attendance Form Modal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Modal Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Absensi Patroli',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Lokasi Patroli Dropdown
                        const Text(
                          'Lokasi Patroli',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedPatrolLocation,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: [widget.location.name]
                              .map((location) => DropdownMenuItem(
                                    value: location,
                                    child: Text(location),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPatrolLocation = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Pilih lokasi patroli';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Lokasi Saat Ini
                        const Text(
                          'Lokasi Saat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _currentLocationController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            hintText: 'Lokasi akan terdeteksi otomatis',
                          ),
                          readOnly: true,
                        ),

                        const SizedBox(height: 20),

                        // Bukti Patroli
                        const Text(
                          'Bukti Patroli*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: _proofImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      height: 120,
                                      color: Colors.green[100],
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 32,
                                              color: Colors.green,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Foto berhasil diambil',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Ambil Foto Bukti Patroli',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Location Verification Status
                        if (_verificationMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isLocationVerified
                                  ? Colors.green[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isLocationVerified
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _isLocationVerified
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _verificationMessage,
                                  style: TextStyle(
                                    color: _isLocationVerified
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Verify Location Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _verifyLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Verifikasi Lokasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BlocBuilder<PatrolAttendanceBloc, AttendanceState>(
                                builder: (context, state) {
                                  return ElevatedButton(
                                    onPressed: state is AttendanceLoading
                                        ? null
                                        : _submitAttendance,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: state is AttendanceLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Simpan',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.thumb_up,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Absen Patroli Berhasil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Terima Kasih',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to detail page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationVerificationDialog(bool isVerified, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isVerified ? Icons.check_circle : Icons.error,
              color: isVerified ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isVerified ? 'Verifikasi Berhasil' : 'Verifikasi Gagal'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Camera Capture Page
class CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraCapturePage({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
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
      appBar: const RumaraAppBar(title: 'Ambil Foto Bukti'),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      CameraPreview(_controller),
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
                  height: 120,
                  color: Colors.black,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: () async {
                        try {
                          await _initializeControllerFuture;
                          final image = await _controller.takePicture();
                          Navigator.of(context).pop(image);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.camera_alt, color: Colors.black),
                    ),
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