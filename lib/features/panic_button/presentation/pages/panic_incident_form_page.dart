import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/utils/image_compress_util.dart';
import '../../../patrol/domain/entities/patrol_location.dart';
import '../../../patrol/domain/repositories/patrol_repository.dart';
import '../../data/models/incident_request_model.dart';
import '../../domain/repositories/panic_button_repository.dart';
import '../bloc/panic_button_bloc.dart';
import '../bloc/panic_button_state.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

class PanicIncidentFormPage extends StatelessWidget {
  const PanicIncidentFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PanicIncidentFormView();
  }
}

class _PanicIncidentFormView extends StatefulWidget {
  const _PanicIncidentFormView();

  @override
  State<_PanicIncidentFormView> createState() => _PanicIncidentFormViewState();
}

class _PanicIncidentFormViewState extends State<_PanicIncidentFormView> {
  final TextEditingController _kejadianController = TextEditingController();
  final TextEditingController _tindakanController = TextEditingController();
  String? _selectedLocation;
  int? _selectedIncidentTypeId;

  // File attachments
  List<File> _kejadianFiles = [];
  List<File> _tindakanFiles = [];

  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  // Areas from API
  List<PatrolLocation> _availableAreas = [];
  bool _isLoadingAreas = true;
  String? _areasErrorMessage;

  // Submit state
  bool _isSubmitting = false;
  bool _hasInitializedArgs = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadAreas();
  }

  Future<void> _pickLocation() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? _availableAreas
                : _availableAreas
                    .where((a) => a.name.toLowerCase().contains(query))
                    .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari lokasi...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final area = filtered[index];
                          return ListTile(
                            title: Text(area.name),
                            onTap: () => Navigator.pop(context, area.name),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedLocation = selected;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get incident type ID from route arguments after context is available
    if (!_hasInitializedArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _selectedIncidentTypeId = args;
        _hasInitializedArgs = true;
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoadingAreas = true;
      _areasErrorMessage = null;
    });

    try {
      final repository = getIt<PatrolRepository>();
      final result = await repository.getAllAreas();

      result.fold(
        (failure) {
          setState(() {
            _isLoadingAreas = false;
            _areasErrorMessage = 'Gagal memuat daftar area: ${failure.message}';
            _availableAreas = [];
          });
        },
        (areas) {
          setState(() {
            _isLoadingAreas = false;
            _availableAreas = areas;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoadingAreas = false;
        _areasErrorMessage = 'Terjadi kesalahan: $e';
        _availableAreas = [];
      });
    }
  }

  @override
  void dispose() {
    _kejadianController.dispose();
    _tindakanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const RumaraAppBar(title: 'Tombol Darurat'),
      child: BlocBuilder<PanicButtonBloc, PanicButtonState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Padding(
              padding: REdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jenis keadaan darurat yang sesuai',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  24.verticalSpace,

                  // Lokasi Kejadian Dropdown
                  Text(
                    'Lokasi Kejadian',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding: REdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5484D)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: _isLoadingAreas
                        ? Padding(
                            padding: REdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16.w,
                                  height: 16.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                12.horizontalSpace,
                                Text(
                                  'Memuat daftar area...',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _areasErrorMessage != null
                            ? Padding(
                                padding: REdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _areasErrorMessage!,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                    8.verticalSpace,
                                    TextButton(
                                      onPressed: _loadAreas,
                                      child: Text(
                                        'Coba Lagi',
                                        style: TextStyle(fontSize: 12.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _availableAreas.isEmpty
                                ? Padding(
                                    padding:
                                        REdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'Tidak ada lokasi yang tersedia',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  )
                                : InkWell(
                                    onTap: _pickLocation,
                                    child: Padding(
                                      padding: REdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _selectedLocation ??
                                                  'Lokasi Kejadian ---',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: _selectedLocation == null
                                                    ? Colors.grey[600]
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.search,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                  ),
                  24.verticalSpace,

                  // Kejadian field
                  Text(
                    'Kejadian',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5484D)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: TextField(
                      controller: _kejadianController,
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Kejadian ---',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        contentPadding: REdgeInsets.all(12),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                _showImagePickerDialog(context, 'kejadian');
                              },
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.grey[600],
                                size: 20.r,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _showAttachmentDialog(context, 'kejadian');
                              },
                              icon: Icon(
                                Icons.attach_file,
                                color: Colors.grey[600],
                                size: 20.r,
                              ),
                            ),
                          ],
                        ),
                      ),
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ),
                  // Display kejadian attachments
                  if (_kejadianFiles.isNotEmpty) ...[
                    8.verticalSpace,
                    _buildAttachmentsList('kejadian', _kejadianFiles),
                  ],
                  24.verticalSpace,

                  // Tindakan field
                  Text(
                    'Tindakan',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  8.verticalSpace,
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8.r),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _tindakanController,
                      enabled: true,
                      maxLines: 3,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Masukkan tindakan yang dilakukan',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: REdgeInsets.all(12),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  60.verticalSpace,

                  // Bottom button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: (_isFormValid() && !_isSubmitting)
                          ? _submitIncident
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isFormValid() && !_isSubmitting)
                            ? const Color(0xFFE5484D)
                            : Colors.grey[300],
                        foregroundColor: (_isFormValid() && !_isSubmitting)
                            ? Colors.white
                            : Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'AKTIFKAN',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  20.verticalSpace,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachmentsList(String fieldType, List<File> files) {
    return Container(
      padding: REdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File terlampir ($fieldType):',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          8.verticalSpace,
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final fileName = file.path.split('/').last;
            final isImage = _isImageFile(fileName);

            return Container(
              margin: REdgeInsets.only(bottom: 8),
              padding: REdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image : _getFileIcon(fileName),
                    color: Colors.grey[600],
                    size: 20.r,
                  ),
                  8.horizontalSpace,
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (fieldType == 'kejadian') {
                          _kejadianFiles.removeAt(index);
                        } else {
                          _tindakanFiles.removeAt(index);
                        }
                      });
                    },
                    icon: Icon(
                      Icons.delete,
                      color: Colors.red[400],
                      size: 18.r,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  bool _isImageFile(String fileName) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    final extension = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool _isFormValid() {
    // Incident type, location, kejadian must have text and at least one image
    // Tindakan must have text (no images required)
    return _selectedIncidentTypeId != null &&
           _selectedLocation != null && 
           _kejadianController.text.isNotEmpty && 
           _kejadianFiles.isNotEmpty &&
           _tindakanController.text.isNotEmpty;
  }

  /// Convert image file to base64
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final compressed =
          await ImageCompressUtil.ensureMax1MbIfImage(imageFile.path);
      final bytes = await compressed.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  /// Get MIME type from file extension
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
        return 'image/jpeg'; // Default to jpeg
    }
  }

  /// Convert all image files to base64
  Future<List<IncidentFileModel>> _convertFilesToBase64(
      List<File> files) async {
    final List<IncidentFileModel> fileModels = [];

    for (final file in files) {
      // Only convert image files
      if (_isImageFile(file.path)) {
        try {
          final base64 = await _convertImageToBase64(file);
          final fileName = path.basename(file.path);
          final mimeType = _getMimeType(fileName);
          fileModels.add(IncidentFileModel(
            filename: fileName,
            mimeType: mimeType,
            base64: base64,
          ));
        } catch (e) {
          print('Error converting file ${file.path} to base64: $e');
          // Continue with other files
        }
      }
    }
    return fileModels;
  }

  /// Submit incident report
  Future<void> _submitIncident() async {
    // ========== LOGGING START ==========
    print('═══════════════════════════════════════════════════════════');
    print('🚨 [PANIC BUTTON] SUBMIT INCIDENT START');
    print('═══════════════════════════════════════════════════════════');

    if (!_isFormValid()) {
      print('❌ Form validation failed');
      print('  - Selected Location: $_selectedLocation');
      print(
          '  - Kejadian: ${_kejadianController.text.isEmpty ? "EMPTY" : "FILLED"}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Harap lengkapi semua field yang wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('✅ Form validation passed');
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get user ID from secure storage
      print('📋 Step 1: Getting user ID from secure storage...');
      final reporterId =
          await SecurityManager.readSecurely(AppConstants.userIdKey);
      if (reporterId == null || reporterId.isEmpty) {
        print('❌ User ID not found in secure storage');
        throw Exception('User ID tidak ditemukan. Silakan login ulang.');
      }
      print('✅ User ID retrieved: $reporterId');

      // Get AreasId from selected location
      print('📋 Step 2: Getting AreasId from selected location...');
      print('  - Selected Location Name: $_selectedLocation');
      print('  - Available Areas Count: ${_availableAreas.length}');
      final selectedArea = _availableAreas.firstWhere(
        (area) => area.name == _selectedLocation,
        orElse: () => _availableAreas.first,
      );
      print('✅ Area selected:');
      print('  - Area ID: ${selectedArea.id}');
      print('  - Area Name: ${selectedArea.name}');

      // Combine all image files (kejadian + tindakan)
      print('📋 Step 3: Processing image files...');
      final allImageFiles = <File>[];
      allImageFiles
          .addAll(_kejadianFiles.where((file) => _isImageFile(file.path)));
      allImageFiles
          .addAll(_tindakanFiles.where((file) => _isImageFile(file.path)));
      print('  - Kejadian Files Count: ${_kejadianFiles.length}');
      print('  - Tindakan Files Count: ${_tindakanFiles.length}');
      print('  - Total Image Files: ${allImageFiles.length}');
      for (int i = 0; i < allImageFiles.length; i++) {
        final file = allImageFiles[i];
        final fileSize = await file.length();
        print(
            '    File[$i]: ${file.path} (${(fileSize / 1024).toStringAsFixed(2)} KB)');
      }

      // Convert images to base64
      print('📋 Step 4: Converting images to base64...');
      final files = await _convertFilesToBase64(allImageFiles);
      print('✅ Images converted to base64:');
      print('  - Total Files: ${files.length}');
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final base64Length = file.base64.length;
        print(
            '    File[$i]: ${file.filename} (${file.mimeType}, base64Length: $base64Length)');
      }

      // Format date as YYYY-MM-DD
      print('📋 Step 5: Formatting date...');
      final now = DateTime.now();
      final reporterDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      print('✅ Reporter Date: $reporterDate');
      final description = _kejadianController.text; // Hanya kejadian
      final resolveAction = _tindakanController.text.isNotEmpty
          ? _tindakanController.text
          : null; // ResolveAction dari tindakan, null jika kosong
      print('✅ Description: $description');
      print('✅ Description length: ${description.length} characters');
      print('✅ ResolveAction: ${resolveAction ?? "null"}');
      if (resolveAction != null) {
        print('✅ ResolveAction length: ${resolveAction.length} characters');
      }

      // Get selected incident type ID
      print('📋 Step 7: Getting selected incident type...');
      if (_selectedIncidentTypeId == null) {
        print('❌ Incident type not selected');
        throw Exception('Jenis keadaan darurat harus dipilih');
      }
      print('✅ Selected Incident Type ID: $_selectedIncidentTypeId');

      // Create request model
      print('📋 Step 8: Creating request model...');
      final request = IncidentRequestModel(
        action: null,
        areasId: selectedArea.id,
        description: description,
        feedback: null,
        idIncidentType: _selectedIncidentTypeId!,
        reporterDate: reporterDate,
        reporterId: reporterId,
        resolveAction: resolveAction, // ResolveAction dari tindakan
        solverDate: null,
        solverId: null,
        status: 'OPEN',
        files: files,
      );
      print('✅ Request model created:');
      print('  - Action: ${request.action ?? "null"}');
      print('  - AreasId: ${request.areasId}');
      print('  - Description: ${request.description}');
      print('  - Feedback: ${request.feedback ?? "null"}');
      print('  - IdIncidentType: ${request.idIncidentType}');
      print('  - ReporterDate: ${request.reporterDate}');
      print('  - ReporterId: ${request.reporterId}');
      print('  - ResolveAction: ${request.resolveAction ?? "null"}');
      print('  - SolverDate: ${request.solverDate ?? "null"}');
      print('  - SolverId: ${request.solverId ?? "null"}');
      print('  - Status: ${request.status}');
      print('  - Files Count: ${request.files.length}');

      // Submit via repository
      print('📋 Step 9: Submitting to repository...');
      final repository = getIt<PanicButtonRepository>();
      final startTime = DateTime.now();
      await repository.submitIncident(request);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('✅ Submit completed in ${duration.inMilliseconds}ms');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        print('✅ Showing success dialog...');
        // Show success dialog with button to go to home
        _showSuccessDialog(context);
        print('═══════════════════════════════════════════════════════════');
        print('✅ [PANIC BUTTON] SUBMIT INCIDENT SUCCESS');
        print('═══════════════════════════════════════════════════════════');
      }
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [PANIC BUTTON] SUBMIT INCIDENT ERROR');
      print('═══════════════════════════════════════════════════════════');
      print('❌ Error: $e');
      print('📚 Stack Trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════════════');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Show success dialog after submitting incident
  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28.r,
              ),
              12.horizontalSpace,
              Expanded(
                child: Text(
                  'Berhasil',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Laporan incident berhasil dikirim',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushReplacementNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5484D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: REdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Kembali ke Home',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImagePickerDialog(BuildContext context, String fieldType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Pilih Sumber Gambar',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera(fieldType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery(fieldType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentDialog(BuildContext context, String fieldType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Pilih File',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Dokumen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument(fieldType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAudio(fieldType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickImageFromCamera(String fieldType) async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        _showErrorSnackBar('Akses kamera ditolak');
        return;
      }

      if (_cameras == null || _cameras!.isEmpty) {
        _showErrorSnackBar('Kamera tidak tersedia');
        return;
      }

      // Navigate to camera screen
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _CameraScreen(
              fieldType: fieldType,
              cameras: _cameras!,
            ),
          ),
        );

        if (result != null && result is File) {
          setState(() {
            if (fieldType == 'kejadian') {
              _kejadianFiles.add(result);
            } else {
              _tindakanFiles.add(result);
            }
          });
          _showSuccessSnackBar('Gambar berhasil ditambahkan untuk $fieldType');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error mengambil gambar: $e');
    }
  }

  void _pickImageFromGallery(String fieldType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          if (fieldType == 'kejadian') {
            _kejadianFiles.add(file);
          } else {
            _tindakanFiles.add(file);
          }
        });
        _showSuccessSnackBar('Gambar berhasil ditambahkan untuk $fieldType');
      }
    } catch (e) {
      _showErrorSnackBar('Error memilih gambar: $e');
    }
  }

  void _pickDocument(String fieldType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          if (fieldType == 'kejadian') {
            _kejadianFiles.add(file);
          } else {
            _tindakanFiles.add(file);
          }
        });
        _showSuccessSnackBar('Dokumen berhasil ditambahkan untuk $fieldType');
      }
    } catch (e) {
      _showErrorSnackBar('Error memilih dokumen: $e');
    }
  }

  void _pickAudio(String fieldType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          if (fieldType == 'kejadian') {
            _kejadianFiles.add(file);
          } else {
            _tindakanFiles.add(file);
          }
        });
        _showSuccessSnackBar(
            'File audio berhasil ditambahkan untuk $fieldType');
      }
    } catch (e) {
      _showErrorSnackBar('Error memilih file audio: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }
}

// Camera Screen Widget
class _CameraScreen extends StatefulWidget {
  final String fieldType;
  final List<CameraDescription> cameras;

  const _CameraScreen({
    required this.fieldType,
    required this.cameras,
  });

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
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
      backgroundColor: Colors.black,
      appBar: RumaraAppBar(title: 'Ambil Foto - ${widget.fieldType}'),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
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
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          Container(
            height: 100.h,
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30.r,
                  ),
                ),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70.w,
                    height: 70.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 30.r,
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

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final file = File(image.path);
      if (mounted) {
        Navigator.pop(context, file);
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
}
