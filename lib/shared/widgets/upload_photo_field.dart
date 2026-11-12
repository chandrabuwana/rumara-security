import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/design/colors.dart';
import '../../core/design/styles.dart';

class UploadPhotoField extends StatefulWidget {
  final String label;
  final List<String> photos;
  final Function(List<String>) onPhotosChanged;
  final String? errorText;
  final bool isRequired;
  final EdgeInsets margin;
  final bool multiple;
  final int maxPhotos;

  const UploadPhotoField({
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
  State<UploadPhotoField> createState() => _UploadPhotoFieldState();
}

class _UploadPhotoFieldState extends State<UploadPhotoField> {
  Future<void> _pickPhoto() async {
    try {
      if (widget.multiple && widget.photos.length >= widget.maxPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maksimal ${widget.maxPhotos} foto'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // TODO: Implement camera/gallery picker
      // For now, we'll simulate adding a photo path
      final updatedPhotos = List<String>.from(widget.photos);
      if (widget.multiple) {
        updatedPhotos
            .add('/path/to/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      } else {
        updatedPhotos.clear();
        updatedPhotos
            .add('/path/to/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      widget.onPhotosChanged(updatedPhotos);
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
                _pickPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto();
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
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: rumaraBorder),
                        color: rumaraSurfaceMuted,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 24.sp,
                              color: rumaraMutedText,
                            ),
                            4.verticalSpace,
                            Text(
                              'Foto ${index + 1}',
                              style: TS.bodySmall.copyWith(
                                color: rumaraMutedText,
                              ),
                            ),
                          ],
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
          if (!widget.multiple || widget.photos.length < widget.maxPhotos)
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
                        color: rumaraMutedText,
                      ),
                    ),
                    if (widget.multiple) ...[
                      2.verticalSpace,
                      Text(
                        '${widget.photos.length}/${widget.maxPhotos}',
                        style: TS.bodySmall.copyWith(
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
