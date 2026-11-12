import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:math';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/patrol_location.dart';
import '../../domain/entities/patrol_route.dart';
import '../../domain/repositories/patrol_repository.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';
import '../bloc/patrol_bloc.dart';
import '../../../../core/design/colors.dart';

class PatrolAttendanceDialog extends StatefulWidget {
  final String routeId;
  final List<PatrolLocation> locations;
  final PatrolLocation currentLocation;
  final List<RouteTask>? listRoute;

  const PatrolAttendanceDialog({
    super.key,
    required this.routeId,
    required this.locations,
    required this.currentLocation,
    this.listRoute,
  });

  @override
  State<PatrolAttendanceDialog> createState() => _PatrolAttendanceDialogState();
}

class _PatrolAttendanceDialogState extends State<PatrolAttendanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _proofController = TextEditingController();
  File? _imageFile;
  File? _attachmentFile;
  bool _isLoading = false;
  bool _isLocationVerified = false;
  double? _currentLatitude;
  double? _currentLongitude;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeCameras();
  }

  @override
  void dispose() {
    _proofController.dispose();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000; // Earth radius in meters
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Find the closest area within radius
  /// Returns area name if found, otherwise null
  String? _getClosestAreaInRadius() {
    if (widget.listRoute == null || widget.listRoute!.isEmpty) {
      print('🔴 [PatrolAttendanceDialog] listRoute is null or empty');
      return null;
    }

    if (_currentLatitude == null || _currentLongitude == null) {
      print('🔴 [PatrolAttendanceDialog] Current location is null');
      return null;
    }

    print('🟡 [PatrolAttendanceDialog] Checking ${widget.listRoute!.length} areas');
    print('🟡 [PatrolAttendanceDialog] Current location: $_currentLatitude, $_currentLongitude');

    RouteTask? closestArea;
    double closestDistance = double.infinity;

    for (final area in widget.listRoute!) {
      // Skip if latitude, longitude, or radius is null
      if (area.latitude == null || area.longitude == null || area.radius == null) {
        print('🔴 [PatrolAttendanceDialog] Skipping ${area.areasName} - missing data');
        continue;
      }

      final distance = _calculateDistance(
        _currentLatitude!,
        _currentLongitude!,
        area.latitude!,
        area.longitude!,
      );

      print('🟡 [PatrolAttendanceDialog] ${area.areasName}: distance=${distance.toStringAsFixed(2)}m, radius=${area.radius}m, inRadius=${distance <= area.radius!}');

      // Check if within radius and closer than previous closest
      if (distance <= area.radius! && distance < closestDistance) {
        closestArea = area;
        closestDistance = distance;
        print('✅ [PatrolAttendanceDialog] Found closest area: ${area.areasName} (${distance.toStringAsFixed(2)}m)');
      }
    }

    if (closestArea != null) {
      print('✅ [PatrolAttendanceDialog] Returning area name: ${closestArea.areasName}');
      return closestArea.areasName;
    } else {
      print('🔴 [PatrolAttendanceDialog] No area found within radius');
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationVerified = false;
    });

    try {
      final locationService = getIt<LocationService>();
      final position = await locationService.getCurrentLatLng();

      if (position != null) {
        setState(() {
          _currentLatitude = position.lat;
          _currentLongitude = position.lng;
          _isLocationVerified = true;
        });
      } else {
        // GPS tidak tersedia
        if (mounted) {
          setState(() {
            _isLocationVerified = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS tidak tersedia. Silakan aktifkan GPS dan coba lagi.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Error mendapatkan GPS
      if (mounted) {
        setState(() {
          _isLocationVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil lokasi GPS: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
        // Request camera permission
        final cameraPermission = await Permission.camera.request();
        if (cameraPermission != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akses kamera ditolak'),
                backgroundColor: Colors.red,
              ),
            );  
          }
          return;
        }

        // Initialize cameras if not already done
        if (_cameras == null) {
          _cameras = await availableCameras();
        }

        if (_cameras == null || _cameras!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kamera tidak tersedia'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Navigate to camera capture page
        final result = await Navigator.push<XFile?>(
          context,
          MaterialPageRoute(
            builder: (_) => _CameraCapturePage(cameras: _cameras!),
          ),
        );

        if (result != null && mounted) {
          setState(() {
            _imageFile = File(result.path);
          });
          print('🔍 DEBUG: Camera photo set - path: ${result.path}');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil diambil'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Pick from gallery
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          setState(() {
            _imageFile = File(image.path);
          });
          print('🔍 DEBUG: Gallery photo set - path: ${image.path}');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil dipilih dari galeri'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachmentFile = File(image.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil dipilih dari galeri'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memilih foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewFullImage(File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black87,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  // Tap hint
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tap anywhere to close',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitAttendance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageFile == null && _attachmentFile == null) {
      print('🔍 DEBUG: Both _imageFile and _attachmentFile are null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti patroli (foto) wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } else {
      if (_imageFile != null) {
        print('🔍 DEBUG: Using _imageFile - path: ${_imageFile!.path}');
      }
      if (_attachmentFile != null) {
        print('🔍 DEBUG: Using _attachmentFile - path: ${_attachmentFile!.path}');
      }
    }

    if (!_isLocationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifikasi lokasi terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentLatitude == null || _currentLongitude == null || !_isLocationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi GPS belum tersedia. Silakan tunggu atau refresh lokasi GPS.'),
          backgroundColor: Colors.red,
        ),
      );
      // Try to get location again
      await _getCurrentLocation();
      return;
    }

    // Validasi: lat/long tidak boleh 0
    if (_currentLatitude == 0.0 || _currentLongitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koordinat GPS tidak valid (0,0). Silakan refresh lokasi GPS atau pastikan GPS aktif.'),
          backgroundColor: Colors.red,
        ),
      );
      // Try to get location again
      await _getCurrentLocation();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get IdShiftDetail from storage
      final shiftDetailId = await SecurityManager.readSecurely(
        AppConstants.shiftDetailIdKey,
      );

      if (shiftDetailId == null || shiftDetailId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IdShiftDetail tidak ditemukan. Silakan check-in terlebih dahulu.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get patrol repository
      final patrolRepository = getIt<PatrolRepository>();

      // Submit check point using new API
      // Use currentLocation.id as idAreas since it's the selected location from the list
      // Use either _imageFile or _attachmentFile for the photo
      final photoFile = _imageFile ?? _attachmentFile;
      final result = await patrolRepository.submitCheckPoint(
        idShiftDetail: shiftDetailId,
        idAreas: widget.currentLocation.id, // Use the selected location's id from the list
        photoPath: photoFile?.path,
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
      );

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
          });
          
          // Show error dialog popup
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                failure.message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        (success) {
          setState(() {
            _isLoading = false;
          });
          
          // Reload patrol list BEFORE closing dialog (context is still valid)
          try {
            // Try to access PatrolBloc from context if available
            final patrolBloc = context.read<PatrolBloc>();
            print('[PatrolAttendanceDialog] ✅ Success! Reloading areas for route: ${widget.routeId}');
            
            // Get listRoute from current state if available
            final currentState = patrolBloc.state;
            List<RouteTask>? listRoute;
            PatrolRoute? existingRoute;
            
            if (currentState is PatrolLoaded) {
              listRoute = currentState.listRoute;
              // Find existing route
              existingRoute = currentState.routes
                  .where((route) => route.id == widget.routeId)
                  .firstOrNull;
            }
            
            // Reload areas to refresh the list (use listRoute from state)
            patrolBloc.add(LoadAreasByRouteId(widget.routeId, existingRoute, listRoute));
          } catch (e) {
            print('[PatrolAttendanceDialog] Could not access PatrolBloc: $e');
            // If bloc is not available, parent will handle reload via return value
          }
          
          // Close attendance dialog and return success
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Absensi Patroli',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Lokasi Patroli (Read-only)
                        const Text(
                          'Lokasi Patroli',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.currentLocation.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Lokasi Saat Ini (Read-only with GPS)
                        const Text(
                          'Lokasi Saat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _currentLatitude != null && _currentLongitude != null
                                ? (_getClosestAreaInRadius() != null ? Colors.green[100] : Colors.red[100])
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentLatitude != null &&
                                        _currentLongitude != null
                                    ? (_getClosestAreaInRadius() ?? 'Lat: ${_currentLatitude!.toStringAsFixed(6)}, Long: ${_currentLongitude!.toStringAsFixed(6)}')
                                    : 'Mendeteksi lokasi...',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              if (_currentLatitude != null && _currentLongitude != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _getClosestAreaInRadius() != null
                                        ? 'Anda sudah berada di lokasi patroli'
                                        : 'Silahkan mendekati lokasi patroli',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getClosestAreaInRadius() != null ? Colors.green[800] : Colors.red[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bukti Patroli (Proof input with camera)
                        const Text(
                          'Bukti Patroli (Foto)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '*',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _proofController,
                          decoration: InputDecoration(
                            hintText: 'Lokasi Kejadian ---',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: _isLoading ? null : _pickImage,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.attach_file,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed:
                                      _isLoading ? null : _pickAttachment,
                                ),
                              ],
                            ),
                          ),
                          validator: (value) {
                            return null;
                          },
                        ),
                        
                        // Photo Preview
                        if (_imageFile != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _imageFile!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _imageFile = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Attachment Preview (Photo Thumbnail)
                        if (_attachmentFile != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                              color: Colors.grey[50],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Foto Terlampir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _viewFullImage(_attachmentFile!),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _attachmentFile!,
                                          width: double.infinity,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _attachmentFile = null;
                                            });
                                          },
                                        ),
                                      ),
                                      // Tap hint overlay
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Tap to view',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Verifikasi Lokasi Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLocationVerified
                                ? null
                                : _getCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLocationVerified
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                              foregroundColor: _isLocationVerified
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _isLocationVerified
                                      ? Colors.green[700]!
                                      : Colors.blue[700]!,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLocationVerified)
                                  const Icon(Icons.check_circle, size: 20),
                                if (_isLocationVerified)
                                  const SizedBox(width: 8),
                                Text(
                                  _isLocationVerified
                                      ? 'Verifikasi lokasi berhasil'
                                      : 'Verifikasi lokasi',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(
                                      color: primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _submitAttendance,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Simpan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        ],
                      ),
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

// Camera Capture Page
class _CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const _CameraCapturePage({
    required this.cameras,
  });

  @override
  State<_CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<_CameraCapturePage> {
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
      appBar: AppBar(
        title: const Text('Ambil Foto Bukti Patroli'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              );
            }
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
                          if (mounted) {
                            Navigator.of(context).pop(image);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
