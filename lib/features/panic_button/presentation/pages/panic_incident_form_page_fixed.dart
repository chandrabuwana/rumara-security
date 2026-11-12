import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/app_scaffold.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickLocation() async {
    const options = <String>[
      'Gedung A',
      'Gedung B',
      'Gedung C',
      'Area Parkir',
      'Kantin',
      'Lainnya',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? options
                : options
                    .where((o) => o.toLowerCase().contains(query))
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
                          final value = filtered[index];
                          return ListTile(
                            title: Text(value),
                            onTap: () => Navigator.pop(context, value),
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
  void dispose() {
    _kejadianController.dispose();
    _tindakanController.dispose();
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
                    child: InkWell(
                      onTap: _pickLocation,
                      child: Padding(
                        padding: REdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLocation ?? 'Lokasi Kejadian ---',
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
                      border: Border.all(color: const Color(0xFFE5484D)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: TextField(
                      controller: _tindakanController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tindakan ---',
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
                                _showImagePickerDialog(context, 'tindakan');
                              },
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.grey[600],
                                size: 20.r,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _showAttachmentDialog(context, 'tindakan');
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

                  60.verticalSpace,

                  // Bottom button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _isFormValid()
                          ? () {
                              Navigator.pushNamed(
                                  context, '/panic-confirmation');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFormValid()
                            ? const Color(0xFFE5484D)
                            : Colors.grey[300],
                        foregroundColor:
                            _isFormValid() ? Colors.white : Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
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

  bool _isFormValid() {
    return _selectedLocation != null &&
        _kejadianController.text.isNotEmpty &&
        _tindakanController.text.isNotEmpty;
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

  void _pickImageFromCamera(String fieldType) {
    // TODO: Implement image picker from camera
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengambil gambar dari kamera untuk $fieldType'),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }

  void _pickImageFromGallery(String fieldType) {
    // TODO: Implement image picker from gallery
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengambil gambar dari galeri untuk $fieldType'),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }

  void _pickDocument(String fieldType) {
    // TODO: Implement document picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Memilih dokumen untuk $fieldType'),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }

  void _pickAudio(String fieldType) {
    // TODO: Implement audio picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Memilih file audio untuk $fieldType'),
        backgroundColor: const Color(0xFFE5484D),
      ),
    );
  }
}
