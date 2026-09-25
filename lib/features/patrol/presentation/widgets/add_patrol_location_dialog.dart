import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/patrol_location.dart';
import '../../domain/repositories/patrol_repository.dart';
import '../../domain/usecases/verify_location.dart';
import '../../data/models/route_detail_api_response.dart';
import '../../../schedule/domain/repositories/schedule_repository.dart';

class AddPatrolLocationDialog extends StatefulWidget {
  final String routeId;
  final List<String> existingLocations; // Locations already in the route
  final VoidCallback onLocationAdded;
  final List<RouteTask>? listRoute;

  const AddPatrolLocationDialog({
    super.key,
    required this.routeId,
    required this.existingLocations,
    required this.onLocationAdded,
    this.listRoute,
  });

  @override
  State<AddPatrolLocationDialog> createState() =>
      _AddPatrolLocationDialogState();
}

class _SearchablePatrolLocationSheet extends StatefulWidget {
  final String? selectedLocation;

  const _SearchablePatrolLocationSheet({
    required this.selectedLocation,
  });

  @override
  State<_SearchablePatrolLocationSheet> createState() =>
      _SearchablePatrolLocationSheetState();
}

class _SearchablePatrolLocationSheetState
    extends State<_SearchablePatrolLocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PatrolLocation> _filtered = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAreas(); // Load initial areas
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to avoid too many API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadAreas();
    });
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final patrolRepository = getIt<PatrolRepository>();
      final searchQuery = _searchController.text.trim();
      
      // Create filter for search if query is not empty
      List<FilterModel>? filter;
      if (searchQuery.isNotEmpty) {
        filter = [
          FilterModel(
            field: 'Name',
            search: searchQuery,
          ),
        ];
      }

      final result = await patrolRepository.getAreaList(
        start: 0,
        length: 0, // Get all results
        filter: filter,
      );

      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _error = 'Gagal memuat lokasi: ${failure.message}';
              _isLoading = false;
            });
          }
        },
        (locations) {
          if (mounted) {
            setState(() {
              _filtered = locations;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat lokasi: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              'Pilih lokasi patroli',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari lokasi...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAreas,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Lokasi tidak ditemukan',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final area = _filtered[index];
        return ListTile(
          title: Text(
            area.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: (widget.selectedLocation == area.name)
              ? const Icon(Icons.check)
              : null,
          onTap: () => Navigator.of(context).pop(area),
        );
      },
    );
  }
}

class _AddPatrolLocationDialogState extends State<AddPatrolLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  String? _selectedLocation;
  PatrolLocation? _selectedPatrolLocation;
  String _currentLocationText = 'Menunggu...';
  double? _latitude;
  double? _longitude;
  bool _isLocationVerified = false;
  bool _isLoading = false;
  bool _isLoadingAreas = true;
  bool _isLoadingLocation = false;
  bool _isVerifyingLocation = false;
  List<PatrolLocation> _availableAreas = [];
  String? _errorMessage;
  String? _verificationMessage;
  File? _proofImage;

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _getCurrentLocation();
  }

  Future<PatrolLocation?> _showSearchableLocationPicker() {
    return showModalBottomSheet<PatrolLocation?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _SearchablePatrolLocationSheet(
          selectedLocation: _selectedLocation,
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoadingAreas = true;
      _errorMessage = null;
    });

    try {
      final repository = getIt<PatrolRepository>();
      final result = await repository.getAllAreas();

      result.fold(
        (failure) {
          setState(() {
            _isLoadingAreas = false;
            _errorMessage = 'Gagal memuat daftar area: ${failure.message}';
            _availableAreas = [];
          });
        },
        (areas) {
          // Filter out existing locations
          print('🔍 [AddPatrolLocationDialog] Total areas from API: ${areas.length}');
          print('🔍 [AddPatrolLocationDialog] Existing locations to exclude: ${widget.existingLocations}');
          
          final filteredAreas = areas
              .where((area) => !widget.existingLocations.contains(area.name))
              .toList();

          print('🔍 [AddPatrolLocationDialog] Filtered areas (available to add): ${filteredAreas.length}');
          print('🔍 [AddPatrolLocationDialog] Available area names: ${filteredAreas.map((a) => a.name).toList()}');

          setState(() {
            _isLoadingAreas = false;
            _availableAreas = filteredAreas;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoadingAreas = false;
        _errorMessage = 'Terjadi kesalahan: $e';
        _availableAreas = [];
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _currentLocationText = 'Mengambil lokasi GPS...';
      _isLocationVerified = false;
    });

    try {
      final locationService = getIt<LocationService>();
      final position = await locationService.getCurrentLatLng();

      if (position != null) {
        setState(() {
          _latitude = position.lat;
          _longitude = position.lng;
          // Show area name if within radius, otherwise show lat/long
          final areaName = _getClosestAreaInRadius();
          _currentLocationText = areaName ?? 
              '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}';
          _isLoadingLocation = false;
        });
        
        // Verify location with selected area if area is selected
        if (_selectedLocation != null) {
          await _verifyLocationWithArea();
        }
      } else {
        // GPS tidak tersedia, minta user untuk mengaktifkan GPS
        if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _isLocationVerified = false;
          _verificationMessage = 'GPS tidak tersedia';
          _currentLocationText = 'GPS tidak tersedia. Silakan aktifkan GPS dan coba lagi.';
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
          _isLoadingLocation = false;
          _isLocationVerified = false;
          _verificationMessage = 'Error mengambil lokasi GPS';
          _currentLocationText = 'Error mengambil lokasi GPS: $e';
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
      print('🔴 [AddPatrolLocationDialog] listRoute is null or empty');
      return null;
    }

    if (_latitude == null || _longitude == null) {
      print('🔴 [AddPatrolLocationDialog] Current location is null');
      return null;
    }

    print('🟡 [AddPatrolLocationDialog] Checking ${widget.listRoute!.length} areas');
    print('🟡 [AddPatrolLocationDialog] Current location: $_latitude, $_longitude');

    RouteTask? closestArea;
    double closestDistance = double.infinity;

    for (final area in widget.listRoute!) {
      // Skip if latitude, longitude, or radius is null
      if (area.latitude == null || area.longitude == null || area.radius == null) {
        print('🔴 [AddPatrolLocationDialog] Skipping ${area.areasName} - missing data');
        continue;
      }

      final distance = _calculateDistance(
        _latitude!,
        _longitude!,
        area.latitude!,
        area.longitude!,
      );

      print('🟡 [AddPatrolLocationDialog] ${area.areasName}: distance=${distance.toStringAsFixed(2)}m, radius=${area.radius}m, inRadius=${distance <= area.radius!}');

      // Check if within radius and closer than previous closest
      if (distance <= area.radius! && distance < closestDistance) {
        closestArea = area;
        closestDistance = distance;
        print('✅ [AddPatrolLocationDialog] Found closest area: ${area.areasName} (${distance.toStringAsFixed(2)}m)');
      }
    }

    if (closestArea != null) {
      print('✅ [AddPatrolLocationDialog] Returning area name: ${closestArea.areasName}');
      return closestArea.areasName;
    } else {
      print('🔴 [AddPatrolLocationDialog] No area found within radius');
      return null;
    }
  }

  Future<void> _verifyLocationWithArea() async {
    if (_selectedLocation == null || _latitude == null || _longitude == null) {
      setState(() {
        _isLocationVerified = false;
        _verificationMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifyingLocation = true;
      _verificationMessage = 'Memverifikasi lokasi...';
    });

    try {
      // Get selected area details
      final selectedArea = _availableAreas.firstWhere(
        (area) => area.name == _selectedLocation!,
        orElse: () => _availableAreas.first,
      );

      // Use VerifyLocation usecase
      final verifyLocation = getIt<VerifyLocation>();
      final result = await verifyLocation.call(
        VerifyLocationParams(
          currentLatitude: _latitude!,
          currentLongitude: _longitude!,
          targetLatitude: selectedArea.latitude,
          targetLongitude: selectedArea.longitude,
        ),
      );

      result.fold(
        (failure) {
          setState(() {
            _isLocationVerified = false;
            _verificationMessage = 'Verifikasi gagal: ${failure.message}';
            _isVerifyingLocation = false;
          });
        },
        (isVerified) {
          setState(() {
            _isLocationVerified = isVerified;
            _verificationMessage = isVerified
                ? 'Verifikasi lokasi berhasil'
                : 'Verifikasi lokasi gagal';
            _isVerifyingLocation = false;
          });

          if (!isVerified && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Lokasi saat ini tidak berada dalam radius area "${_selectedLocation}". '
                  'Pastikan Anda berada di lokasi yang benar.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      );
    } catch (e) {
      setState(() {
        _isLocationVerified = false;
        _verificationMessage = 'Error verifikasi lokasi: $e';
        _isVerifyingLocation = false;
      });
    }
  }

  Future<void> _showImagePickerDialog() async {
    final source = await showDialog<ImageSource>(
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
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _proofImage = File(image.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil dipilih'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih lokasi patroli'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi belum tersedia, mohon tunggu...'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti patroli (foto) wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi radius dihapus - tidak perlu cek lokasi lagi

    setState(() {
      _isLoading = true;
    });

    try {
      // Get shift id from storage (saved from home when get_current is called)
      // No need to hit API again, just read from storage
      final idShiftDetail = await SecurityManager.readSecurely(
        AppConstants.shiftDetailIdKey,
      );
      
      if (idShiftDetail == null || idShiftDetail.isEmpty) {
        print('⚠️ Shift id tidak ditemukan di storage');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift id tidak ditemukan. Silakan kembali ke home untuk memuat data shift.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('✅ Shift id dari storage: $idShiftDetail');

      // Use the selected PatrolLocation object which contains the actual GUID
      print('🔍 DEBUG: Using selected location: "$_selectedLocation"');
      print('🔍 DEBUG: Selected location GUID: "${_selectedPatrolLocation?.id}"');
      
      if (_selectedPatrolLocation == null) {
        print('🔍 DEBUG: _selectedPatrolLocation is null, creating fallback');
        // Fallback - create area with name as ID (this shouldn't happen with the new flow)
        final selectedArea = PatrolLocation(
          id: _selectedLocation!, 
          name: _selectedLocation!,
          description: 'Lokasi patroli tambahan',
          latitude: _latitude!,
          longitude: _longitude!,
          address: 'Alamat tidak tersedia',
          radius: 50.0,
        );
        print('🔍 DEBUG: Created fallback area: ${selectedArea.name} (ID: ${selectedArea.id})');
      } else {
        print('🔍 DEBUG: Using existing PatrolLocation: ${_selectedPatrolLocation!.name} (ID: ${_selectedPatrolLocation!.id})');
      }
      
      final selectedArea = _selectedPatrolLocation ?? PatrolLocation(
        id: _selectedLocation!, 
        name: _selectedLocation!,
        description: 'Lokasi patroli tambahan',
        latitude: _latitude!,
        longitude: _longitude!,
        address: 'Alamat tidak tersedia',
        radius: 50.0,
      );

      // Get device name
      final deviceName = await _resolveDeviceName();

      // Get actual lat/long from GPS (must be available)
      if (_latitude == null || _longitude == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lokasi GPS belum tersedia. Silakan tunggu atau refresh lokasi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final actualLat = _latitude!;
      final actualLng = _longitude!;

      // Call new endpoint /AttendanceDetail/insert
      final repository = getIt<PatrolRepository>();
      final result = await repository.insertAttendanceDetail(
        idShiftDetail: idShiftDetail,
        device: deviceName,
        idAreas: selectedArea.id, // IdAreas from selected location
        photoPath: _proofImage?.path,
        latitude: actualLat,
        locationName: selectedArea.name, // LocationName from selected location
        longitude: actualLng,
      );

      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal menambahkan lokasi: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (success) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lokasi patroli berhasil ditambahkan'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
            widget.onLocationAdded();
          }
        },
      );
    } catch (e) {
      if (mounted) {
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
  }

  Future<String> _resolveDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown Device';
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        final machine = info.utsname.machine;
        deviceName = machine.isNotEmpty ? machine : 'iPhone';
      }
    } catch (_) {}
    return deviceName;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Title
                      const Center(
                        child: Text(
                          'Absensi Patroli',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Lokasi Patroli Dropdown
                      const Text(
                        'Lokasi Patroli*',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoadingAreas
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Memuat daftar area...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _errorMessage != null
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _loadAreas,
                                        child: const Text('Coba Lagi'),
                                      ),
                                    ],
                                  ),
                                )
                                  : _availableAreas.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Tidak ada lokasi patroli yang tersedia',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                  : FormField<String>(
                                      initialValue: _selectedLocation,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Lokasi patroli harus dipilih';
                                        }
                                        return null;
                                      },
                                      builder: (field) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                final selectedLocation =
                                                    await _showSearchableLocationPicker();
                                                if (selectedLocation == null) return;
                                                print('🔍 DEBUG: Location selected from picker: "${selectedLocation.name}" (ID: ${selectedLocation.id})');
                                                field.didChange(selectedLocation.name);
                                                setState(() {
                                                  _selectedLocation = selectedLocation.name;
                                                  _selectedPatrolLocation = selectedLocation;
                                                  _isLocationVerified = false;
                                                  _verificationMessage = null;
                                                });
                                                print('🔍 DEBUG: _selectedLocation set to: "$_selectedLocation"');
                                                print('🔍 DEBUG: _selectedPatrolLocation ID: ${_selectedPatrolLocation?.id}');
                                                if (_latitude != null && _longitude != null) {
                                                  _verifyLocationWithArea();
                                                } else {
                                                  _getCurrentLocation();
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: Colors.grey[100],
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  hintText: 'Pilih lokasi patroli',
                                                  errorText: field.errorText,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        (_selectedLocation ?? '').isNotEmpty
                                                            ? _selectedLocation!
                                                            : 'Pilih lokasi patroli',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: (_selectedLocation ?? '')
                                                                  .isNotEmpty
                                                              ? Colors.black87
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.search,
                                                      color: Colors.grey,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                          const SizedBox(height: 20),

                          const Text(
                            'Lokasi Saat Ini',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _latitude != null && _longitude != null
                                  ? (_getClosestAreaInRadius() != null ? Colors.green[100] : Colors.red[100])
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _isLoadingLocation
                                          ? const Row(
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Mengambil lokasi...',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              _currentLocationText,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _isLocationVerified
                                                    ? Colors.black87
                                                    : Colors.red,
                                              ),
                                            ),
                                    ),
                                    if (_isLocationVerified)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    if (!_isLocationVerified && !_isLoadingLocation)
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        iconSize: 20,
                                        color: primaryColor,
                                        onPressed: _getCurrentLocation,
                                        tooltip: 'Refresh Lokasi',
                                      ),
                                  ],
                                ),
                                if (_latitude != null && _longitude != null && !_isLoadingLocation)
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

                      const SizedBox(height: 20),

                      // Bukti Patroli
                      const Text(
                        'Bukti Patroli*',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                IconButton(
                                  onPressed: _showImagePickerDialog,
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color: primaryColor,
                                  ),
                                  tooltip: 'Ambil Foto',
                                ),
                                IconButton(
                                  onPressed: _showImagePickerDialog,
                                  icon: Icon(
                                    Icons.photo_library,
                                    color: primaryColor,
                                  ),
                                  tooltip: 'Pilih dari Galeri',
                                ),
                              ],
                            ),
                            // Display selected image
                            if (_proofImage != null)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _proofImage!,
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _proofImage = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Verifikasi Lokasi Berhasil
                      if (_selectedLocation != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isLocationVerified
                                ? Colors.green[50]
                                : (_isVerifyingLocation
                                    ? Colors.blue[50]
                                    : Colors.orange[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isLocationVerified
                                  ? Colors.green[300]!
                                  : (_isVerifyingLocation
                                      ? Colors.blue[300]!
                                      : Colors.orange[300]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isVerifyingLocation)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  _isLocationVerified
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  color: _isLocationVerified
                                      ? Colors.green[700]
                                      : Colors.orange[800],
                                  size: 20,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isVerifyingLocation
                                      ? 'Memverifikasi lokasi...'
                                      : (_verificationMessage ??
                                          (_isLocationVerified
                                              ? 'Verifikasi lokasi berhasil'
                                              : 'Menunggu verifikasi lokasi...')),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _isLocationVerified
                                        ? Colors.green[700]
                                        : (_isVerifyingLocation
                                            ? Colors.blue[700]
                                            : Colors.orange[800]),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color:
                                      _isLoading ? Colors.grey : primaryColor,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  color:
                                      _isLoading ? Colors.grey : primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
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
                                        fontSize: 15,
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

            // Close button (X)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Text(
                  'X',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
