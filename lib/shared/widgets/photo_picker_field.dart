import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/design/colors.dart';
import '../../core/design/styles.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoPickerField extends StatefulWidget {
  final String label;
  final List<String> photos;
  final Function(List<String>) onPhotosChanged;
  final String? errorText;
  final bool isRequired;
  final EdgeInsets margin;
  final bool multiple;
  final int maxPhotos;

  const PhotoPickerField({
    Key? key,
    required this.label,
    required this.photos,
    required this.onPhotosChanged,
    this.errorText,
    this.isRequired = false,
    this.margin = EdgeInsets.zero,
    this.multiple = true,
    this.maxPhotos = 5,
  }) : super(key: key);

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _ensureCapacityOrToast() async {
    if (widget.multiple && widget.photos.length >= widget.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maksimal ${widget.maxPhotos} foto'),
          backgroundColor: Colors.red,
        ),
      );
      throw Exception('capacity_reached');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      await _ensureCapacityOrToast();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final updatedPhotos = List<String>.from(widget.photos);
        if (widget.multiple) {
          updatedPhotos.add(result.files.single.path!);
        } else {
          updatedPhotos
            ..clear()
            ..add(result.files.single.path!);
        }
        widget.onPhotosChanged(updatedPhotos);
      }
    } catch (e) {
      if (e.toString().contains('capacity_reached')) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      await _ensureCapacityOrToast();
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akses kamera ditolak'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_cameras == null || _cameras!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera tidak tersedia'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      final file = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => _CameraCaptureScreen(
            cameras: _cameras!,
          ),
        ),
      );

      if (file != null) {
        final updatedPhotos = List<String>.from(widget.photos);
        if (widget.multiple) {
          updatedPhotos.add(file.path);
        } else {
          updatedPhotos
            ..clear()
            ..add(file.path);
        }
        widget.onPhotosChanged(updatedPhotos);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    final updatedPhotos = List<String>.from(widget.photos);
    updatedPhotos.removeAt(index);
    widget.onPhotosChanged(updatedPhotos);
  }

  void _showFullImage(BuildContext context, String imagePath, int index) {
    final isLocalFile = !imagePath.startsWith('http://') && 
                       !imagePath.startsWith('https://');
    
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
            if (widget.photos.length > 1)
              Positioned(
                bottom: 20.h,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1} / ${widget.photos.length}',
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

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  widget.label,
                  style: TS.labelLarge,
                ),
                if (widget.isRequired)
                  Text(
                    '*',
                    style: TS.bodyLarge.copyWith(color: Colors.red),
                  ),
              ],
            ),
            8.verticalSpace,
          ],

          // Photos Grid
          if (widget.photos.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 1,
              ),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photoPath = widget.photos[index];
                final isLocalFile = !photoPath.startsWith('http://') && 
                                   !photoPath.startsWith('https://');
                
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullImage(context, photoPath, index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: rumaraBorder),
                          color: rumaraSurfaceMuted,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: isLocalFile
                              ? Image.file(
                                  File(photoPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 24.sp,
                                            color: rumaraMutedText,
                                          ),
                                          4.verticalSpace,
                                          Text(
                                            'Gagal memuat',
                                            style: TS.bodySmall.copyWith(
                                              color: const Color(0xFF333333),
                                              color: rumaraMutedText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Image.network(
                                  photoPath,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 24.sp,
                                            color: rumaraMutedText,
                                          ),
                                          4.verticalSpace,
                                          Text(
                                            'Gagal memuat',
                                            style: TS.bodySmall.copyWith(
                                              color: const Color(0xFF333333),
                                              color: rumaraMutedText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4.h,
                      right: 4.w,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: REdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            8.verticalSpace,
          ],

          // Add Photo Button
          // Show button only if:
          // - multiple is false and no photos yet, OR
          // - multiple is true and photos count < maxPhotos
          if ((!widget.multiple && widget.photos.isEmpty) || 
              (widget.multiple && widget.photos.length < widget.maxPhotos))
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                width: double.infinity,
                height: 100.h,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.errorText != null
                        ? Colors.red
                        : rumaraBorder,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                  color: rumaraSurfaceMuted,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 32.sp,
                      color: rumaraMutedText,
                    ),
                    4.verticalSpace,
                    Text(
                      widget.photos.isEmpty
                          ? 'Tambah Foto'
                          : 'Tambah Foto Lagi',
                      style: TS.bodyMedium.copyWith(
                        color: const Color(0xFF333333),
                        color: rumaraMutedText,
                      ),
                    ),
                    if (widget.multiple) ...[
                      2.verticalSpace,
                      Text(
                        '${widget.photos.length}/${widget.maxPhotos}',
                        style: TS.bodySmall.copyWith(
                          color: const Color(0xFF333333),
                          color: rumaraHintText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (widget.errorText != null) ...[
            4.verticalSpace,
            Text(
              widget.errorText!,
              style: TS.bodySmall.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraCaptureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraCaptureScreen({required this.cameras});

  @override
  State<_CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<_CameraCaptureScreen> {
  late CameraController _cameraController;
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
      _cameraController.dispose();
    }
    _cameraController = CameraController(
      widget.cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _isControllerCreated = true;
    _initializeControllerFuture = _cameraController.initialize();
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
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ambil Foto'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      CameraPreview(_cameraController),
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
                return const Center(
                  child: CircularProgressIndicator(),
                );
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
                  icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 70.w,
                    height: 70.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 30.sp),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _capture() async {
    try {
      await _initializeControllerFuture;
      final xfile = await _cameraController.takePicture();
      if (!mounted) return;
      Navigator.pop(context, File(xfile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

