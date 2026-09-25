// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';
// import '../../../../core/design/colors.dart';
// import '../../../../core/design/styles.dart';
// import '../../../../core/constants/app_constants.dart';
// import '../../../../core/di/injection.dart';
// import '../../../../shared/widgets/app_scaffold.dart';
// import '../../../../shared/widgets/Buttons/ui_button.dart';
// import '../../domain/entities/attendance_rekap_detail_entity.dart';
// import '../../domain/entities/attendance_update_request.dart';
// import '../bloc/attendance_rekap_detail_bloc.dart';
// import '../bloc/attendance_rekap_detail_event.dart';
// import '../bloc/attendance_rekap_detail_state.dart';

// class AttendanceRekapEditScreen extends StatefulWidget {
//   final String idAttendance;
//   final AttendanceRekapDetailEntity detail;
//   final bool isAttendanceDetail; // true for Detail Kehadiran, false for Detail Laporan Kegiatan

//   const AttendanceRekapEditScreen({
//     super.key,
//     required this.idAttendance,
//     required this.detail,
//     this.isAttendanceDetail = false,
//   });

//   @override
//   State<AttendanceRekapEditScreen> createState() =>
//       _AttendanceRekapEditScreenState();
// }

// class _AttendanceRekapEditScreenState extends State<AttendanceRekapEditScreen> {
//   final TextEditingController _laporanController = TextEditingController();
//   File? _photoAbsenFile;
//   File? _photoPengamananFile;
//   File? _photoPakaianFile;
//   File? _photoOvertimeFile;
//   bool? _isOvertime;
//   String? _initializedDetailId;
//   final ImagePicker _imagePicker = ImagePicker();

//   @override
//   void initState() {
//     super.initState();
//     // Initialize form fields
//     if (widget.detail.checkOut != null) {
//       if (widget.detail.notesCheckout != null) {
//         _laporanController.text = widget.detail.notesCheckout!;
//       }
//     } else {
//       if (widget.detail.notes != null) {
//         _laporanController.text = widget.detail.notes!;
//       }
//     }
//     _isOvertime = widget.detail.isOvertime;
//   }

//   @override
//   void dispose() {
//     _laporanController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => getIt<AttendanceRekapDetailBloc>(),
//       child: AppScaffold(
//         backgroundColor: const Color(0xFFF8F9FA),
//         enableScrolling: true,
//         appBar: AppBar(
//           backgroundColor: primaryColor,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           title: Text(
//             widget.isAttendanceDetail ? 'Detail Kehadiran' : 'Detail Laporan Kegiatan',
//             style: TS.titleLarge.copyWith(color: Colors.white),
//           ),
//           centerTitle: true,
//         ),
//         child: BlocConsumer<AttendanceRekapDetailBloc,
//             AttendanceRekapDetailState>(
//           listener: (context, state) {
//             if (state is AttendanceRekapDetailFailure) {
//               Navigator.of(context, rootNavigator: true).popUntil(
//                 (route) => route.isFirst || !route.willHandlePopInternally,
//               );
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(state.message),
//                   backgroundColor: Colors.red,
//                 ),
//               );
//             }
//             if (state is AttendanceRekapDetailUpdateSuccess) {
//               debugPrint(
//                 '[AttendanceRekapEditScreen] UpdateSuccess for idAttendance=${widget.idAttendance}',
//               );
//               // Close loading dialog if open
//               Navigator.of(context, rootNavigator: true).popUntil(
//                 (route) => route.isFirst || !route.willHandlePopInternally,
//               );
//               // Show success dialog
//               _showSuccessDialog(context);
//             }
//             if (state is AttendanceRekapDetailUpdating) {
//               debugPrint(
//                 '[AttendanceRekapEditScreen] Updating... showing blocking dialog for idAttendance=${widget.idAttendance}',
//               );
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (context) => const Center(
//                   child: CircularProgressIndicator(),
//                 ),
//               );
//             }
//           },
//           builder: (context, state) {
//             final detail = state is AttendanceRekapDetailLoaded
//                 ? state.detail
//                 : widget.detail;

//             debugPrint(
//               '[AttendanceRekapEditScreen] build state=${state.runtimeType} '
//               'id=${detail.idAttendance} checkIn=${detail.checkIn != null} '
//               'checkOut=${detail.checkOut != null} statusLaporan=${detail.statusLaporan}',
//             );

//             if (_initializedDetailId != detail.idAttendance) {
//               _initializedDetailId = detail.idAttendance;

//               debugPrint(
//                 '[AttendanceRekapEditScreen] init fields for id=${detail.idAttendance} '
//                 'mode=${detail.checkOut != null ? "CHECKOUT" : "CHECKIN"} '
//                 'notesLen=${detail.notes?.length ?? 0} notesCheckoutLen=${detail.notesCheckout?.length ?? 0}',
//               );

//               if (detail.checkOut != null) {
//                 _laporanController.text = detail.notesCheckout ?? '';
//               } else {
//                 _laporanController.text = detail.notes ?? '';
//               }

//               _isOvertime = detail.isOvertime;
//             }

//             if (state is AttendanceRekapDetailUpdating) {
//               final currentState = context.read<AttendanceRekapDetailBloc>().state;
//               if (currentState is AttendanceRekapDetailLoaded) {
//                 return Stack(
//                   children: [
//                     _buildEditContent(context, detail),
//                     Container(
//                       color: Colors.black.withOpacity(0.3),
//                       child: const Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                     ),
//                   ],
//                 );
//               }
//               return const Center(
//                 child: CircularProgressIndicator(color: primaryColor),
//               );
//             }
//             return _buildEditContent(context, detail);
//           },
//         ),
//       ),
//     );
//   }
//   // when page mulai bekerja in detail kehadiran ,laporan pengamanan mulai bekerja editable ,
//   // foto pengaman mulai bekerja, and when in page selesai bekerja in detail kehadiran ,
//   // laporan pengamanan selesai bekerja editable also , foto pengaman mulai bekerja editable, photo overtime
//   //  "PhotoPakaianCheckIn": {
//   //   "Filename": "string",
//   //   "MimeType": "string",
//   //   "Base64": "string"
//   // },
//   // "PhotoPengamananCheckIn": {
//   //   "Filename": "string",
//   //   "MimeType": "string",
//   //   "Base64": "string"
//   // },
//   // "PhotoAbsenCheckOut": {
//   //   "Filename": "string",
//   //   "MimeType": "string",
//   //   "Base64": "string"
//   // },
//   // "PhotoPengamananCheckOut": {
//   //   "Filename": "string",
//   //   "MimeType": "string",
//   //   "Base64": "string"
//   // },
//   // "PhotoLemburCheckOut": {
//   //   "Filename": "string",
//   //   "MimeType": "string",
//   //   "Base64": "string"
//   // },
//   // "Laporan": "string",
//   // "LaporanCheckout": "string",

//   Widget _buildEditContent(
//       BuildContext context, AttendanceRekapDetailEntity detail) {
    
//     return SingleChildScrollView(
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(8.r),
//           border: Border.all(color: Colors.grey.shade200),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Profile Section
//             _buildProfileSectionInCard(detail),

//             16.verticalSpace,

//             // Fields Section
//             Padding(
//               padding: REdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Selesai Bekerja Section
//                   if (detail.checkOut != null) ...[
//                     Text(
//                       'Selesai Bekerja',
//                       style: TS.titleMedium.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: neutral90,
//                       ),
//                     ),
//                     8.verticalSpace,
//                     _buildEditablePhotoFieldInCard(
//                       'Pakaian Personil',
//                       detail.photoCheckoutPakaian?.url,
//                       detail.photoCheckoutPakaian?.filename,
//                       _photoPakaianFile,
//                       (file) {
//                         setState(() {
//                           _photoPakaianFile = file.path.isNotEmpty ? file : null;
//                         });
//                       },
//                     ),
//                     16.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Lokasi Pengamanan',
//                       detail.location ?? '-',
//                     ),

//                     // Patroli Section
//                     if (detail.patrol == 'Yes' && detail.route != null) ...[
//                       16.verticalSpace,
//                       _buildPatrolSectionInCard(detail.route!, detail.listCarryOver),
//                     ],

//                     // Bukti Penyelesaian Tugas Lanjutan
//                     if (detail.photoCheckout?.hasPhoto == true) ...[
//                       16.verticalSpace,
//                       _buildImageCard(
//                         'Bukti Penyelesaian Tugas Lanjutan',
//                         detail.photoCheckout?.url,
//                       ),
//                     ],

//                     // Laporan Pengamanan (Editable)
//                     16.verticalSpace,
//                     _buildEditableTextAreaFieldInCard('Laporan Pengamanan 3 as', _laporanController),

//                     // Foto Pengamanan (Editable)
//                     16.verticalSpace,
//                     _buildEditablePhotoFieldInCard(
//                       'Foto Pengamanan',
//                       detail.photoCheckoutPengamanan?.url,
//                       detail.photoCheckoutPengamanan?.filename,
//                       _photoPengamananFile,
//                       (file) {
//                         setState(() {
//                           _photoPengamananFile = file.path.isNotEmpty ? file : null;
//                         });
//                       },
//                     ),

//                     // Tugas Tertunda
//                     if (detail.carryOver != null && detail.carryOver!.isNotEmpty) ...[
//                       16.verticalSpace,
//                       _buildTextAreaFieldInCard('Tugas Tertunda', detail.carryOver!),
//                     ],

//                     // Jam Selesai Bekerja
//                     16.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Jam Selesai Bekerja',
//                       _formatTime(detail.checkOut!),
//                     ),

//                     // Lembur (Editable)
//                     16.verticalSpace,
//                     _buildEditableOvertimeFieldInCard(),

//                     // Bukti Lembur (Editable)
//                     if (_isOvertime == true) ...[
//                       16.verticalSpace,
//                       _buildEditablePhotoFieldInCard(
//                         'Bukti Lembur',
//                         detail.photoOvertime?.url,
//                         detail.photoOvertime?.filename,
//                         _photoOvertimeFile,
//                         (file) {
//                           setState(() {
//                             _photoOvertimeFile = file.path.isNotEmpty ? file : null;
//                           });
//                         },
//                       ),
//                     ],

//                     // Status Selesai Bekerja
//                     if (detail.statusKerja != null) ...[
//                       16.verticalSpace,
//                       _buildInfoFieldInCard(
//                         'Status Selesai Bekerja',
//                         detail.statusKerja!,
//                       ),
//                     ],

//                     // Tanggal Verifikasi
//                     16.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Tanggal Verifikasi',
//                       () {
//                         if (detail.updateDate != null) {
//                           final formattedDate = _formatDate(detail.updateDate!);
//                           return formattedDate;
//                         } else {
//                           return '-';
//                         }
//                       }(),
//                     ),

//                     // Diverifikasi Oleh
//                     16.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Diverifikasi Oleh',
//                       () {
//                         final result = detail.updateBy ?? '-';
//                         return result;
//                       }(),
//                     ),
//                     16.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Feedback',
//                       () {
//                         final result = detail.feedback ?? '-';
//                         return result;
//                       }(),
//                     ),
//                   ] else if (detail.checkIn != null) ...[
//                     // Mulai Bekerja Section - Editable fields
//                     Text(
//                       'Mulai Bekerja',
//                       style: TS.titleMedium.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: neutral90,
//                       ),
//                     ),
//                     8.verticalSpace,
//                     _buildInfoFieldInCard(
//                       'Jam Absensi',
//                       _formatTime(detail.checkIn!),
//                     ),
//                     16.verticalSpace,
//                     _buildEditablePhotoFieldInCard(
//                       'Pakaian Personil',
//                       detail.photoPakaian?.url,
//                       detail.photoPakaian?.filename,
//                       _photoAbsenFile,
//                       (file) {
//                         setState(() {
//                           _photoAbsenFile = file.path.isNotEmpty ? file : null;
//                         });
//                       },
//                     ),
//                     16.verticalSpace,
//                     _buildEditableTextAreaFieldInCard('Laporan Pengamanan', _laporanController),
//                     16.verticalSpace,
//                     _buildEditablePhotoFieldInCard(
//                       'Foto Pengamanan',
//                       detail.photoPengamanan?.url,
//                       detail.photoPengamanan?.filename,
//                       _photoPengamananFile,
//                       (file) {
//                         setState(() {
//                           _photoPengamananFile = file.path.isNotEmpty ? file : null;
//                         });
//                       },
//                     ),
//                   ],
//                 ],
//               ),
//             ),

//             32.verticalSpace,

//             // Save Button
//             Padding(
//               padding: REdgeInsets.symmetric(horizontal: 16, vertical: 16),
//               child: UIButton(
//                 text: 'Simpan',
//                 onPressed: () => _handleSave(context),
//                 variant: UIButtonVariant.primary,
//                 size: UIButtonSize.large,
//                 fullWidth: true,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _handleSave(BuildContext context) async {
//     // Helper function to get path or null if empty, with validation
//     Future<String?> _getPathOrNull(File? file) async {
//       if (file == null) {
//         return null;
//       }
      
//       final filePath = file.path;
//       if (filePath.isEmpty) {
//         return null;
//       }
      
//       try {
//         final exists = await file.exists();
//         if (!exists) {
//           return null;
//         }
        
//         final size = await file.length();
//         if (size == 0) {
//           return null;
//         }
        
//         return filePath;
//       } catch (e) {
//         return null;
//       }
//     }

//     // PhotoAbsen harus diambil dari pakaian personil
//     // Untuk check-in: dari _photoAbsenFile (Pakaian Personil di section Mulai Bekerja)
//     // Untuk check-out: dari _photoPakaianFile (Pakaian Personil di section Selesai Bekerja)
//     final isCheckOut = widget.detail.checkOut != null;
//     final photoAbsenPath =
//         await _getPathOrNull(isCheckOut ? _photoPakaianFile : _photoAbsenFile);
//     final photoPengamananPath = await _getPathOrNull(_photoPengamananFile);
//     final photoPakaianPath = await _getPathOrNull(_photoPakaianFile);
//     final photoOvertimePath = await _getPathOrNull(_photoOvertimeFile);

//     final laporanText = _laporanController.text.trim();

//     final request = AttendanceUpdateRequest(
//       idAttendance: widget.idAttendance,
//       photoAbsenPath: photoAbsenPath,
//       photoPengamananPath: photoPengamananPath,
//       photoPakaianPath: photoPakaianPath,
//       laporan: !isCheckOut && laporanText.isNotEmpty ? laporanText : null,
//       laporanCheckout: isCheckOut && laporanText.isNotEmpty ? laporanText : null,
//       isOvertime: _isOvertime,
//       photoOvertimePath: photoOvertimePath,
//     );

//     context
//         .read<AttendanceRekapDetailBloc>()
//         .add(UpdateAttendanceRekapDetailEvent(request));
//   }

//   void _showSuccessDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16.r),
//         ),
//         contentPadding: REdgeInsets.all(24),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Success Icon with animation background
//             Container(
//               width: 80.w,
//               height: 80.h,
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 Icons.check_circle,
//                 size: 48.sp,
//                 color: Colors.green,
//               ),
//             ),
//             20.verticalSpace,
//             // Title
//             Text(
//               'Perubahan Berhasil Disimpan!',
//               style: TS.titleMedium.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             12.verticalSpace,
//             // Message
//             Text(
//               'Data laporan kegiatan telah berhasil diperbarui.',
//               style: TS.bodyMedium.copyWith(
//                 color: Colors.grey.shade600,
//                 height: 1.4,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             24.verticalSpace,
//             // Button
//             UIButton(
//               text: 'OK',
//               fullWidth: true,
//               variant: UIButtonVariant.success,
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close dialog
//                 Navigator.of(context).pop(true); // Pop edit screen with result
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickImage(ImageSource source, Function(File) onPicked) async {
//     try {
//       final image = await _imagePicker.pickImage(source: source);
      
//       if (image != null) {
//         final originalFile = File(image.path);
//         final originalExists = await originalFile.exists();
        
//         if (originalExists) {
//           final originalSize = await originalFile.length();
          
//           final appDir = await getApplicationDocumentsDirectory();
//           final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
//           final savedFile = await originalFile.copy('${appDir.path}/$fileName');
          
//           final savedExists = await savedFile.exists();
//           final savedSize = await savedFile.length();
          
//           if (savedExists && savedSize > 0) {
//             onPicked(savedFile);
//           }
//         }
//       }
//     } catch (e) {
//       // Handle error silently or show a snackbar
//     }
//   }

//   void _showImagePickerDialog(Function(File) onPicked) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(
//           'Pilih Sumber Gambar',
//           style: TS.titleMedium,
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: const Icon(Icons.camera_alt),
//               title: const Text('Kamera'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.camera, onPicked);
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.photo_library),
//               title: const Text('Galeri'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.gallery, onPicked);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProfileSectionInCard(AttendanceRekapDetailEntity detail) {
//     return Padding(
//       padding: REdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         mainAxisAlignment: MainAxisAlignment.center,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Center(
//             child: detail.photoPegawai != null
//                 ? CircleAvatar(
//                     radius: 40.r,
//                     backgroundImage: NetworkImage(detail.photoPegawai!),
//                   )
//                 : CircleAvatar(
//                     radius: 40.r,
//                     backgroundColor: primaryColor.withOpacity(0.1),
//                     child: Icon(
//                       Icons.person,
//                       size: 40.r,
//                       color: primaryColor,
//                     ),
//                   ),
//           ),
//           12.verticalSpace,
//           Center(
//             child: Text(
//               detail.fullname,
//               style: TS.titleMedium.copyWith(
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           4.verticalSpace,
//           Center(
//             child: Text(
//               '${detail.jabatan} - ${detail.nrp}',
//               style: TS.bodyMedium.copyWith(
//                 color: Colors.grey.shade600,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           if (detail.checkIn != null || detail.checkOut != null) ...[
//             8.verticalSpace,
//             Center(
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
//                 decoration: BoxDecoration(
//                   color: Colors.green.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12.r),
//                 ),
//                 child: Text(
//                   'Hadir',
//                   style: TS.bodySmall.copyWith(
//                     color: Colors.green,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoFieldInCard(
//     String label,
//     String value, {
//     bool isClickable = false,
//     VoidCallback? onTap,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TS.bodyMedium.copyWith(
//             fontWeight: FontWeight.bold,
//             color: neutral90,
//           ),
//         ),
//         8.verticalSpace,
//         GestureDetector(
//           onTap: isClickable ? onTap : null,
//           child: Container(
//             width: double.infinity,
//             padding: REdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade100,
//               borderRadius: BorderRadius.circular(8.r),
//             ),
//             child: Text(
//               value,
//               style: TS.bodyMedium.copyWith(
//                 color: isClickable ? Colors.blue : neutral90,
//                 decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   /// Helper method to build full image URL from relative or absolute URL
//   String _buildImageUrl(String? imageUrl) {
//     if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'Foto.jpg') {
//       return '';
//     }
    
//     // If already a full URL, return as is
//     if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
//       return imageUrl;
//     }
    
//     // Get base URL
//     String baseUrl = AppConstants.baseUrl;
    
//     // Check if URL is just a filename (no slashes, but has file extension)
//     final hasFileExtension = imageUrl.toLowerCase().contains('.jpg') || 
//         imageUrl.toLowerCase().contains('.jpeg') || 
//         imageUrl.toLowerCase().contains('.png') || 
//         imageUrl.toLowerCase().contains('.gif') || 
//         imageUrl.toLowerCase().contains('.webp');
    
//     // If URL is just a filename (contains extension but no slashes), 
//     // construct URL with file endpoint
//     if (!imageUrl.contains('/') && hasFileExtension) {
//       // Use /api/v1/file/{filename} endpoint
//       return '$baseUrl/file/$imageUrl';
//     }
    
//     // If relative path, construct full URL using base URL
//     // Remove leading slash if present
//     final cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    
//     // If path doesn't start with api/v1, add it
//     if (!cleanPath.startsWith('api/')) {
//       return '$baseUrl/$cleanPath';
//     }
    
//     // If path already has api, use base URL without /api/v1
//     String fileBaseUrl = baseUrl;
//     if (fileBaseUrl.endsWith('/api/v1')) {
//       fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 7);
//     } else if (fileBaseUrl.endsWith('/api')) {
//       fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 4);
//     }
    
//     // Construct full URL
//     return '$fileBaseUrl/$cleanPath';
//   }

//   Widget _buildEditablePhotoFieldInCard(
//     String label,
//     String? existingUrl,
//     String? filename,
//     File? selectedFile,
//     Function(File) onFileSelected,
//   ) {
//     final hasImage = selectedFile != null || (existingUrl != null && existingUrl.isNotEmpty);
//     final fullImageUrl = existingUrl != null ? _buildImageUrl(existingUrl) : '';

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               label,
//               style: TS.bodyMedium.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: neutral90,
//               ),
//             ),
//             Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.camera_alt),
//                   onPressed: () => _showImagePickerDialog(onFileSelected),
//                   color: primaryColor,
//                 ),
//                 if (hasImage && selectedFile != null)
//                   IconButton(
//                     icon: const Icon(Icons.delete),
//                     onPressed: () {
//                       // Pass empty file to trigger null in callback
//                       onFileSelected(File(''));
//                     },
//                     color: Colors.red,
//                   ),
//               ],
//             ),
//           ],
//         ),
//         if (hasImage) ...[
//           8.verticalSpace,
//           GestureDetector(
//             onTap: () {
//               if (selectedFile != null) {
//                 // Show preview for selected file
//                 _showFullImageFromFile(selectedFile);
//               } else if (fullImageUrl.isNotEmpty) {
//                 // Show preview for existing URL
//                 _showFullImage(fullImageUrl);
//               }
//             },
//             child: Container(
//               width: double.infinity,
//               height: 200.h,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(8.r),
//                 border: Border.all(color: Colors.grey.shade300),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(8.r),
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     // Show selected file if available, otherwise show existing URL
//                     selectedFile != null
//                         ? Image.file(
//                             selectedFile,
//                             fit: BoxFit.cover,
//                             errorBuilder: (context, error, stackTrace) {
//                               return Container(
//                                 color: Colors.grey[100],
//                                 child: Center(
//                                   child: Column(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(
//                                         Icons.broken_image,
//                                         size: 48.sp,
//                                         color: Colors.grey.shade400,
//                                       ),
//                                       8.verticalSpace,
//                                       Text(
//                                         'Gagal memuat gambar',
//                                         style: TS.bodySmall.copyWith(
//                                           color: Colors.grey.shade600,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           )
//                         : (fullImageUrl.isNotEmpty
//                             ? Image.network(
//                                 fullImageUrl,
//                                 fit: BoxFit.cover,
//                                 loadingBuilder: (context, child, loadingProgress) {
//                                   if (loadingProgress == null) return child;
//                                   return Container(
//                                     color: Colors.grey[100],
//                                     child: Center(
//                                       child: CircularProgressIndicator(
//                                         value: loadingProgress.expectedTotalBytes != null
//                                             ? loadingProgress.cumulativeBytesLoaded /
//                                                 loadingProgress.expectedTotalBytes!
//                                             : null,
//                                         strokeWidth: 2,
//                                         color: primaryColor,
//                                       ),
//                                     ),
//                                   );
//                                 },
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return Container(
//                                     color: Colors.grey[100],
//                                     child: Center(
//                                       child: Column(
//                                         mainAxisAlignment: MainAxisAlignment.center,
//                                         children: [
//                                           Icon(
//                                             Icons.broken_image,
//                                             size: 48.sp,
//                                             color: Colors.grey.shade400,
//                                           ),
//                                           8.verticalSpace,
//                                           Text(
//                                             'Gagal memuat gambar',
//                                             style: TS.bodySmall.copyWith(
//                                               color: Colors.grey.shade600,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               )
//                             : Container(
//                                 color: Colors.grey[100],
//                                 child: Center(
//                                   child: Icon(
//                                     Icons.image_outlined,
//                                     size: 48.sp,
//                                     color: Colors.grey.shade400,
//                                   ),
//                                 ),
//                               )),
//                     // Overlay untuk indikasi bisa diklik
//                     Positioned(
//                       bottom: 8.h,
//                       right: 8.w,
//                       child: Container(
//                         padding: REdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.6),
//                           borderRadius: BorderRadius.circular(6.r),
//                         ),
//                         child: Icon(
//                           Icons.zoom_in,
//                           color: Colors.white,
//                           size: 16.sp,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ] else ...[
//           8.verticalSpace,
//           GestureDetector(
//             onTap: () => _showImagePickerDialog(onFileSelected),
//             child: Container(
//               height: 100.h,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(8.r),
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.add_photo_alternate,
//                       size: 32.sp,
//                       color: Colors.grey.shade400,
//                     ),
//                     8.verticalSpace,
//                     Text(
//                       'Tambah Foto',
//                       style: TS.bodySmall.copyWith(
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ],
//     );
//   }

//   void _showFullImage(String imageUrl) {
//     showDialog(
//       context: context,
//       barrierColor: Colors.black87,
//       builder: (context) => Dialog(
//         backgroundColor: Colors.transparent,
//         insetPadding: REdgeInsets.all(0),
//         child: Stack(
//           children: [
//             Center(
//               child: InteractiveViewer(
//                 minScale: 0.5,
//                 maxScale: 4.0,
//                 child: Image.network(
//                   imageUrl,
//                   fit: BoxFit.contain,
//                   loadingBuilder: (context, child, loadingProgress) {
//                     if (loadingProgress == null) return child;
//                     return Container(
//                       padding: REdgeInsets.all(20),
//                       child: CircularProgressIndicator(
//                         value: loadingProgress.expectedTotalBytes != null
//                             ? loadingProgress.cumulativeBytesLoaded /
//                                 loadingProgress.expectedTotalBytes!
//                             : null,
//                         color: Colors.white,
//                       ),
//                     );
//                   },
//                   errorBuilder: (context, error, stackTrace) {
//                     return Container(
//                       padding: REdgeInsets.all(20),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.broken_image,
//                             size: 64.sp,
//                             color: Colors.white,
//                           ),
//                           16.verticalSpace,
//                           Text(
//                             'Gagal memuat gambar',
//                             style: TS.bodyMedium.copyWith(
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ),
//             // Close button
//             Positioned(
//               top: 40.h,
//               right: 20.w,
//               child: IconButton(
//                 icon: const Icon(
//                   Icons.close,
//                   color: Colors.white,
//                   size: 32,
//                 ),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showFullImageFromFile(File imageFile) {
//     showDialog(
//       context: context,
//       barrierColor: Colors.black87,
//       builder: (context) => Dialog(
//         backgroundColor: Colors.transparent,
//         insetPadding: REdgeInsets.all(0),
//         child: Stack(
//           children: [
//             Center(
//               child: InteractiveViewer(
//                 minScale: 0.5,
//                 maxScale: 4.0,
//                 child: Image.file(
//                   imageFile,
//                   fit: BoxFit.contain,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Container(
//                       padding: REdgeInsets.all(20),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.broken_image,
//                             size: 64.sp,
//                             color: Colors.white,
//                           ),
//                           16.verticalSpace,
//                           Text(
//                             'Gagal memuat gambar',
//                             style: TS.bodyMedium.copyWith(
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ),
//             // Close button
//             Positioned(
//               top: 40.h,
//               right: 20.w,
//               child: IconButton(
//                 icon: const Icon(
//                   Icons.close,
//                   color: Colors.white,
//                   size: 32,
//                 ),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildEditableOvertimeFieldInCard() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Lembur',
//           style: TS.bodyMedium.copyWith(
//             fontWeight: FontWeight.bold,
//             color: neutral90,
//           ),
//         ),
//         8.verticalSpace,
//         Container(
//           width: double.infinity,
//           padding: REdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade100,
//             borderRadius: BorderRadius.circular(8.r),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 _isOvertime == true ? 'Ya' : 'Tidak',
//                 style: TS.bodyMedium.copyWith(
//                   color: neutral90,
//                 ),
//               ),
//               Switch(
//                 value: _isOvertime == true,
//                 onChanged: (value) {
//                   setState(() {
//                     _isOvertime = value;
//                   });
//                 },
//                 activeColor: primaryColor,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildEditableTextAreaFieldInCard(
//     String label,
//     TextEditingController controller,
//   ) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TS.bodyMedium.copyWith(
//             fontWeight: FontWeight.bold,
//             color: neutral90,
//           ),
//         ),
//         8.verticalSpace,
//         TextField(
//           controller: controller,
//           maxLines: 5,
//           decoration: InputDecoration(
//             hintText: 'Masukkan laporan pengamanan...',
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.r),
//               borderSide: BorderSide(color: Colors.grey.shade300),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.r),
//               borderSide: BorderSide(color: Colors.grey.shade300),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.r),
//               borderSide: BorderSide(color: primaryColor, width: 2),
//             ),
//             contentPadding: REdgeInsets.all(12),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTextAreaFieldInCard(String label, String value) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TS.bodyMedium.copyWith(
//             fontWeight: FontWeight.bold,
//             color: neutral90,
//           ),
//         ),
//         8.verticalSpace,
//         Container(
//           width: double.infinity,
//           padding: REdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade100,
//             borderRadius: BorderRadius.circular(8.r),
//           ),
//           child: Text(
//             value,
//             style: TS.bodyMedium,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPatrolSectionInCard(String routeName, List<CarryOverItem> listCarryOver) {
//     final allChecked = listCarryOver.isNotEmpty && 
//         listCarryOver.every((item) => item.isCompleted);
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               routeName,
//               style: TS.bodyMedium.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: neutral90,
//               ),
//             ),
//             if (!allChecked && listCarryOver.isNotEmpty) ...[
//               8.horizontalSpace,
//               Text(
//                 '(Belum Selesai Diperiksa)',
//                 style: TS.bodySmall.copyWith(
//                   color: Colors.red,
//                 ),
//               ),
//             ],
//           ],
//         ),
//         if (listCarryOver.isEmpty) ...[
//           16.verticalSpace,
//           Text(
//             'Belum ada data patroli',
//             style: TS.bodyMedium.copyWith(
//               color: Colors.grey.shade600,
//             ),
//           ),
//         ] else ...[
//           16.verticalSpace,
//           ...listCarryOver.map((item) => _buildPatrolItem(item)),
//         ],
//       ],
//     );
//   }

//   Widget _buildPatrolItem(CarryOverItem item) {
//     final isCompleted = item.isCompleted;
//     return Container(
//       margin: EdgeInsets.only(bottom: 8.h),
//       padding: REdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8.r),
//         border: Border.all(
//           color: isCompleted ? Colors.green : Colors.orange,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 8.w,
//             height: 8.h,
//             decoration: BoxDecoration(
//               color: isCompleted ? Colors.green : Colors.orange,
//               shape: BoxShape.circle,
//             ),
//           ),
//           12.horizontalSpace,
//           Expanded(
//             child: Text(
//               item.note,
//               style: TS.bodyMedium.copyWith(
//                 color: neutral90,
//               ),
//             ),
//           ),
//           8.horizontalSpace,
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
//             decoration: BoxDecoration(
//               color: isCompleted
//                   ? Colors.green.withOpacity(0.1)
//                   : Colors.orange.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(4.r),
//             ),
//             child: Text(
//               item.status,
//               style: TS.bodySmall.copyWith(
//                 color: isCompleted ? Colors.green : Colors.orange,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatTime(DateTime dateTime) {
//     return DateFormat('dd MMMM yyyy - HH.mm', 'id_ID').format(dateTime) + ' WIB';
//   }

//   Widget _buildImageCard(String label, String? imageUrl) {
//     // Build full image URL
//     final fullImageUrl = _buildImageUrl(imageUrl);
//     final isValidImage = fullImageUrl.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TS.bodyMedium.copyWith(
//             fontWeight: FontWeight.bold,
//             color: neutral90,
//           ),
//         ),
//         8.verticalSpace,
//         if (isValidImage)
//           GestureDetector(
//             onTap: () => _showFullImage(fullImageUrl),
//             child: Container(
//               width: double.infinity,
//               height: 200.h,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(8.r),
//                 border: Border.all(color: Colors.grey.shade300),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(8.r),
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     Image.network(
//                       fullImageUrl,
//                       fit: BoxFit.cover,
//                       loadingBuilder: (context, child, loadingProgress) {
//                         if (loadingProgress == null) return child;
//                         return Container(
//                           color: Colors.grey[100],
//                           child: Center(
//                             child: CircularProgressIndicator(
//                               value: loadingProgress.expectedTotalBytes != null
//                                   ? loadingProgress.cumulativeBytesLoaded /
//                                       loadingProgress.expectedTotalBytes!
//                                   : null,
//                               strokeWidth: 2,
//                               color: primaryColor,
//                             ),
//                           ),
//                         );
//                       },
//                       errorBuilder: (context, error, stackTrace) {
//                         return GestureDetector(
//                           onTap: () => _showFullImage(fullImageUrl),
//                           child: Container(
//                             color: Colors.grey[100],
//                             padding: REdgeInsets.all(12),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.broken_image,
//                                   size: 48.sp,
//                                   color: Colors.grey.shade400,
//                                 ),
//                                 8.verticalSpace,
//                                 Text(
//                                   'Gagal memuat gambar',
//                                   style: TS.bodySmall.copyWith(
//                                     color: Colors.grey.shade600,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                 ),
//                                 4.verticalSpace,
//                                 Text(
//                                   fullImageUrl,
//                                   style: TS.bodySmall.copyWith(
//                                     color: primaryColor,
//                                     decoration: TextDecoration.underline,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                   maxLines: 2,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                     // Overlay untuk indikasi bisa diklik
//                     Positioned(
//                       bottom: 8.h,
//                       right: 8.w,
//                       child: Container(
//                         padding: REdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.6),
//                           borderRadius: BorderRadius.circular(6.r),
//                         ),
//                         child: Icon(
//                           Icons.zoom_in,
//                           color: Colors.white,
//                           size: 16.sp,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           )
//         else
//           Container(
//             padding: REdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(8.r),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.image_outlined,
//                   size: 20.sp,
//                   color: Colors.grey.shade600,
//                 ),
//                 8.horizontalSpace,
//                 Expanded(
//                   child: Text(
//                     'Tidak ada gambar',
//                     style: TS.bodyMedium.copyWith(
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   String _formatDate(DateTime date) {
//     try {
//       final formatter = DateFormat('dd-MM-yyyy HH:mm', 'id_ID');
//       return formatter.format(date);
//     } catch (e) {
//       final formatter = DateFormat('dd-MM-yyyy HH:mm');
//       return formatter.format(date);
//     }
//   }
// }


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../../domain/entities/attendance_rekap_detail_entity.dart';
import '../../domain/entities/attendance_update_request.dart';
import '../bloc/attendance_rekap_detail_bloc.dart';
import '../bloc/attendance_rekap_detail_event.dart';
import '../bloc/attendance_rekap_detail_state.dart';

enum AttendanceRekapEditMode {
  checkIn,
  checkOut,
}

class AttendanceRekapEditScreen extends StatefulWidget {
  final String idAttendance;
  final AttendanceRekapDetailEntity detail;
  final bool isAttendanceDetail; // true for Detail Kehadiran, false for Detail Laporan Kegiatan
  final AttendanceRekapEditMode? editMode;
  final bool returnDraftOnly;
  final bool showSaveButton;

  const AttendanceRekapEditScreen({
    super.key,
    required this.idAttendance,
    required this.detail,
    this.isAttendanceDetail = false,
    this.editMode,
    this.returnDraftOnly = false,
    this.showSaveButton = true,
  });

  @override
  State<AttendanceRekapEditScreen> createState() =>
      _AttendanceRekapEditScreenState();
}

class _AttendanceRekapEditScreenState extends State<AttendanceRekapEditScreen> {
  final TextEditingController _laporanController = TextEditingController();
  File? _photoAbsenFile;
  File? _photoPengamananFile;
  File? _photoPakaianFile;
  File? _photoOvertimeFile;
  bool? _isOvertime;
  bool _isLoadingDialogOpen = false;
  final ImagePicker _imagePicker = ImagePicker();

  AttendanceRekapEditMode get _effectiveMode {
    return widget.editMode ??
        (widget.detail.checkOut != null
            ? AttendanceRekapEditMode.checkOut
            : AttendanceRekapEditMode.checkIn);
  }

  @override
  void initState() {
    super.initState();
    // Initialize form fields
    if (_effectiveMode == AttendanceRekapEditMode.checkOut) {
      _laporanController.text = widget.detail.notesCheckout ?? '';
    } else {
      _laporanController.text = widget.detail.notes ?? '';
    }
    _isOvertime = widget.detail.isOvertime;
  }

  @override
  void dispose() {
    _laporanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttendanceRekapDetailBloc>(),
      child: AppScaffold(
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
            widget.isAttendanceDetail ? 'Detail Kehadiran' : 'Detail Laporan Kegiatan',
            style: TS.titleLarge.copyWith(color: Colors.white),
          ),
          centerTitle: true,
        ),
        child: BlocConsumer<AttendanceRekapDetailBloc,
            AttendanceRekapDetailState>(
          listener: (context, state) {
            if (state is AttendanceRekapDetailFailure) {
              if (_isLoadingDialogOpen) {
                Navigator.of(context, rootNavigator: true).pop();
                _isLoadingDialogOpen = false;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
            if (state is AttendanceRekapDetailUpdateSuccess) {
              if (_isLoadingDialogOpen) {
                Navigator.of(context, rootNavigator: true).pop();
                _isLoadingDialogOpen = false;
              }
              // Show success dialog
              _showSuccessDialog(context);
            }
            if (state is AttendanceRekapDetailUpdating) {
              if (!_isLoadingDialogOpen) {
                _isLoadingDialogOpen = true;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            }
          },
          builder: (context, state) {
            if (state is AttendanceRekapDetailUpdating) {
              final currentState = context.read<AttendanceRekapDetailBloc>().state;
              if (currentState is AttendanceRekapDetailLoaded) {
                return Stack(
                  children: [
                    _buildEditContent(context, widget.detail),
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                );
              }
              return Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }
            return _buildEditContent(context, widget.detail);
          },
        ),
      ),
    );
  }

  Widget _buildEditContent(
      BuildContext context, AttendanceRekapDetailEntity detail) {
    final isCheckOut = _effectiveMode == AttendanceRekapEditMode.checkOut;

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
            // Profile Section
            _buildProfileSectionInCard(detail),

            16.verticalSpace,

            // Fields Section
            Padding(
              padding: REdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selesai Bekerja Section
                  if (isCheckOut) ...[
                    Text(
                      'Selesai Bekerja',
                      style: TS.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: neutral90,
                      ),
                    ),
                    8.verticalSpace,
                    _buildEditablePhotoFieldInCard(
                      'Pakaian Personil',
                      detail.photoCheckoutPakaian?.url,
                      detail.photoCheckoutPakaian?.filename,
                      _photoPakaianFile,
                      (file) {
                        setState(() {
                          _photoPakaianFile = file.path.isNotEmpty ? file : null;
                        });
                      },
                    ),
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Lokasi Pengamanan',
                      detail.location ?? '-',
                    ),

                    // Patroli Section
                    if (detail.patrol == 'Yes' && detail.route != null) ...[
                      16.verticalSpace,
                      _buildPatrolSectionInCard(detail.route!, detail.listCarryOver),
                    ],
   
                    // Bukti Penyelesaian Tugas Lanjutan
                    if (detail.photoOvertime?.url != null) ...[
                      16.verticalSpace,
                      _buildImageCard(
                        'Bukti Penyelesaian Tugas Lanjutan',
                        detail.photoOvertime?.url,
                      ),
                    ],

                    // Laporan Pengamanan (Editable)
                    16.verticalSpace,
                    _buildEditableTextAreaFieldInCard('Laporan Pengamanan', _laporanController),

                    // Foto Pengamanan (Editable)
                    16.verticalSpace,
                    _buildEditablePhotoFieldInCard(
                      'Foto Pengamanan',
                      detail.photoCheckoutPengamanan?.url,
                      detail.photoCheckoutPengamanan?.filename,
                      _photoPengamananFile,
                      (file) {
                        setState(() {
                          _photoPengamananFile = file.path.isNotEmpty ? file : null;
                        });
                      },
                    ),

                    // Tugas Tertunda
                    if (detail.carryOver != null && detail.carryOver!.isNotEmpty) ...[
                      16.verticalSpace,
                      _buildTextAreaFieldInCard('Tugas Tertunda', detail.carryOver!),
                    ],

                    // Jam Selesai Bekerja
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Jam Selesai Bekerja',
                      _formatTime(detail.checkOut!),
                    ),

                    // Lembur (Editable)
                    16.verticalSpace,
                    _buildEditableOvertimeFieldInCard(),

                    // Bukti Lembur (Editable)
                    if (_isOvertime == true) ...[
                      16.verticalSpace,
                      _buildEditablePhotoFieldInCard(
                        'Bukti Lembur',
                        detail.photoOvertime?.url,
                        detail.photoOvertime?.filename,
                        _photoOvertimeFile,
                        (file) {
                          setState(() {
                            _photoOvertimeFile = file.path.isNotEmpty ? file : null;
                          });
                        },
                      ),
                    ],

                    // Status Selesai Bekerja
                    if (detail.statusKerja != null) ...[
                      16.verticalSpace,
                      _buildInfoFieldInCard(
                        'Status Selesai Bekerja',
                        detail.statusKerja!,
                      ),
                    ],

                    // Tanggal Verifikasi
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Tanggal Verifikasi',
                      () {
                        if (detail.updateDate != null) {
                          final formattedDate = _formatDate(detail.updateDate!);
                          return formattedDate;
                        } else {
                          return '-';
                        }
                      }(),
                    ),

                    // Diverifikasi Oleh
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Diverifikasi Oleh',
                      () {
                        final result = detail.updateBy ?? '-';
                        return result;
                      }(),
                    ),
                    16.verticalSpace,
                    _buildInfoFieldInCard(
                      'Feedback',
                      () {
                        final result = detail.feedback ?? '-';
                        return result;
                      }(),
                    ),
                  ] else if (detail.checkIn != null) ...[
                    // Mulai Bekerja Section - Editable fields
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
                      _formatTime(detail.checkIn!),
                    ),
                    16.verticalSpace,
                    _buildEditablePhotoFieldInCard(
                      'Pakaian Personil',
                      detail.photoPakaian?.url,
                      detail.photoPakaian?.filename,
                      _photoAbsenFile,
                      (file) {
                        setState(() {
                          _photoAbsenFile = file.path.isNotEmpty ? file : null;
                        });
                      },
                    ),
                    16.verticalSpace,
                    _buildEditableTextAreaFieldInCard('Laporan Pengamanan', _laporanController),
                    16.verticalSpace,
                    _buildEditablePhotoFieldInCard(
                      'Foto Pengamanan',
                      detail.photoPengamanan?.url,
                      detail.photoPengamanan?.filename,
                      _photoPengamananFile,
                      (file) {
                        setState(() {
                          _photoPengamananFile = file.path.isNotEmpty ? file : null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            32.verticalSpace,

            if (widget.showSaveButton)
              Padding(
                padding: REdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: UIButton(
                  text: 'Simpan',
                  onPressed: () => _handleSave(context),
                  variant: UIButtonVariant.primary,
                  size: UIButtonSize.large,
                  fullWidth: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    if (widget.detail.statusLaporan.toUpperCase() != 'REVISI') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan hanya dapat disimpan ketika status REVISI.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Helper function to get path or null if empty, with validation
    Future<String?> _getPathOrNull(File? file) async {
      if (file == null) {
        return null;
      }
      
      final filePath = file.path;
      if (filePath.isEmpty) {
        return null;
      }
      
      try {
        final exists = await file.exists();
        if (!exists) {
          return null;
        }
        
        final size = await file.length();
        if (size == 0) {
          return null;
        }
        
        return filePath;
      } catch (e) {
        return null;
      }
    }

    // PhotoAbsen harus diambil dari pakaian personil
    // Untuk check-in: dari _photoAbsenFile (Pakaian Personil di section Mulai Bekerja)
    // Untuk check-out: dari _photoPakaianFile (Pakaian Personil di section Selesai Bekerja)
    final isCheckOut = _effectiveMode == AttendanceRekapEditMode.checkOut;
    final photoAbsenPath =
        await _getPathOrNull(isCheckOut ? _photoPakaianFile : _photoAbsenFile);
    final photoPengamananPath = await _getPathOrNull(_photoPengamananFile);
    final photoPakaianPath = await _getPathOrNull(_photoPakaianFile);
    final photoOvertimePath = await _getPathOrNull(_photoOvertimeFile);

    final laporanText = _laporanController.text.trim();

    final request = AttendanceUpdateRequest(
      idAttendance: widget.idAttendance,
      photoAbsenPath: photoAbsenPath,
      photoPengamananPath: photoPengamananPath,
      photoPakaianPath: photoPakaianPath,
      photoPengamananCheckOutPath: isCheckOut ? photoPengamananPath : null,
      laporan: !isCheckOut && laporanText.isNotEmpty ? laporanText : null,
      laporanCheckout: isCheckOut && laporanText.isNotEmpty ? laporanText : null,
      isOvertime: _isOvertime,
      photoOvertimePath: photoOvertimePath,
    );

    if (widget.returnDraftOnly) {
      Navigator.of(context).pop(request);
      return;
    }

    context
        .read<AttendanceRekapDetailBloc>()
        .add(UpdateAttendanceRekapDetailEvent(request));
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        contentPadding: REdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon with animation background
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48.sp,
                color: Colors.green,
              ),
            ),
            20.verticalSpace,
            // Title
            Text(
              'Perubahan Berhasil Disimpan!',
              style: TS.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            12.verticalSpace,
            // Message
            Text(
              'Data laporan kegiatan telah berhasil diperbarui.',
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            // Button
            UIButton(
              text: 'OK',
              fullWidth: true,
              variant: UIButtonVariant.success,
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Pop edit screen with result
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, Function(File) onPicked) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      
      if (image != null) {
        final originalFile = File(image.path);
        final originalExists = await originalFile.exists();
        
        if (originalExists) {
          final originalSize = await originalFile.length();
          
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedFile = await originalFile.copy('${appDir.path}/$fileName');
          
          final savedExists = await savedFile.exists();
          final savedSize = await savedFile.length();
          
          if (savedExists && savedSize > 0) {
            onPicked(savedFile);
          }
        }
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  void _showImagePickerDialog(Function(File) onPicked) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Pilih Sumber Gambar',
          style: TS.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, onPicked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, onPicked);
              },
            ),
          ],
        ),
      ),
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
              style: TS.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          4.verticalSpace,
          Center(
            child: Text(
              '${detail.jabatan} - ${detail.nrp}',
              style: TS.bodyMedium.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (detail.checkIn != null || detail.checkOut != null) ...[
            8.verticalSpace,
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Hadir',
                  style: TS.bodySmall.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoFieldInCard(
    String label,
    String value, {
    bool isClickable = false,
    VoidCallback? onTap,
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
        GestureDetector(
          onTap: isClickable ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              value,
              style: TS.bodyMedium.copyWith(
                color: isClickable ? Colors.blue : neutral90,
                decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Helper method to build full image URL from relative or absolute URL
  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'Foto.jpg') {
      return '';
    }
    
    // If already a full URL, return as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Get base URL
    String baseUrl = AppConstants.baseUrl;
    
    // Check if URL is just a filename (no slashes, but has file extension)
    final hasFileExtension = imageUrl.toLowerCase().contains('.jpg') || 
        imageUrl.toLowerCase().contains('.jpeg') || 
        imageUrl.toLowerCase().contains('.png') || 
        imageUrl.toLowerCase().contains('.gif') || 
        imageUrl.toLowerCase().contains('.webp');
    
    // If URL is just a filename (contains extension but no slashes), 
    // construct URL with file endpoint
    if (!imageUrl.contains('/') && hasFileExtension) {
      // Use /api/v1/file/{filename} endpoint
      return '$baseUrl/file/$imageUrl';
    }
    
    // If relative path, construct full URL using base URL
    // Remove leading slash if present
    final cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    
    // If path doesn't start with api/v1, add it
    if (!cleanPath.startsWith('api/')) {
      return '$baseUrl/$cleanPath';
    }
    
    // If path already has api, use base URL without /api/v1
    String fileBaseUrl = baseUrl;
    if (fileBaseUrl.endsWith('/api/v1')) {
      fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 7);
    } else if (fileBaseUrl.endsWith('/api')) {
      fileBaseUrl = fileBaseUrl.substring(0, fileBaseUrl.length - 4);
    }
    
    // Construct full URL
    return '$fileBaseUrl/$cleanPath';
  }

  Widget _buildEditablePhotoFieldInCard(
    String label,
    String? existingUrl,
    String? filename,
    File? selectedFile,
    Function(File) onFileSelected,
  ) {
    final hasImage = selectedFile != null || (existingUrl != null && existingUrl.isNotEmpty);
    final fullImageUrl = existingUrl != null ? _buildImageUrl(existingUrl) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TS.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: neutral90,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () => _showImagePickerDialog(onFileSelected),
                  color: primaryColor,
                ),
                if (hasImage && selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      // Pass empty file to trigger null in callback
                      onFileSelected(File(''));
                    },
                    color: Colors.red,
                  ),
              ],
            ),
          ],
        ),
        if (hasImage) ...[
          8.verticalSpace,
          GestureDetector(
            onTap: () {
              if (selectedFile != null) {
                // Show preview for selected file
                _showFullImageFromFile(selectedFile);
              } else if (fullImageUrl.isNotEmpty) {
                // Show preview for existing URL
                _showFullImage(fullImageUrl);
              }
            },
            child: Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show selected file if available, otherwise show existing URL
                    selectedFile != null
                        ? Image.file(
                            selectedFile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 48.sp,
                                        color: Colors.grey.shade400,
                                      ),
                                      8.verticalSpace,
                                      Text(
                                        'Gagal memuat gambar',
                                        style: TS.bodySmall.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : (fullImageUrl.isNotEmpty
                            ? Image.network(
                                fullImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                        color: primaryColor,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 48.sp,
                                            color: Colors.grey.shade400,
                                          ),
                                          8.verticalSpace,
                                          Text(
                                            'Gagal memuat gambar',
                                            style: TS.bodySmall.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 48.sp,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              )),
                    // Overlay untuk indikasi bisa diklik
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: REdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          8.verticalSpace,
          GestureDetector(
            onTap: () => _showImagePickerDialog(onFileSelected),
            child: Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 32.sp,
                      color: Colors.grey.shade400,
                    ),
                    8.verticalSpace,
                    Text(
                      'Tambah Foto',
                      style: TS.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showFullImage(String imageUrl) {
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
                child: Image.network(
                  imageUrl,
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
            // Close button
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
          ],
        ),
      ),
    );
  }

  void _showFullImageFromFile(File imageFile) {
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
                child: Image.file(
                  imageFile,
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
                ),
              ),
            ),
            // Close button
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
          ],
        ),
      ),
    );
  }

  Widget _buildEditableOvertimeFieldInCard() {
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
          padding: REdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isOvertime == true ? 'Ya' : 'Tidak',
                style: TS.bodyMedium.copyWith(
                  color: neutral90,
                ),
              ),
              Switch(
                value: _isOvertime == true,
                onChanged: (value) {
                  setState(() {
                    _isOvertime = value;
                  });
                },
                activeColor: primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTextAreaFieldInCard(
    String label,
    TextEditingController controller,
  ) {
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
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Masukkan laporan pengamanan...',
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
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: REdgeInsets.all(12),
          ),
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
          child: Text(
            value,
            style: TS.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildPatrolSectionInCard(String routeName, List<CarryOverItem> listCarryOver) {
    final allChecked = listCarryOver.isNotEmpty && 
        listCarryOver.every((item) => item.isCompleted);
    
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
                style: TS.bodySmall.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        if (listCarryOver.isEmpty) ...[
          16.verticalSpace,
          Text(
            'Belum ada data patroli',
            style: TS.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ] else ...[
          16.verticalSpace,
          ...listCarryOver.map((item) => _buildPatrolItem(item)),
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
            child: Text(
              item.note,
              style: TS.bodyMedium.copyWith(
                color: neutral90,
              ),
            ),
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

  String _formatTime(DateTime dateTime) {
    return DateFormat('dd MMMM yyyy - HH.mm', 'id_ID').format(dateTime) + ' WIB';
  }

  Widget _buildImageCard(String label, String? imageUrl) {
    // Build full image URL
    final fullImageUrl = _buildImageUrl(imageUrl);
    final isValidImage = fullImageUrl.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;
    
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
        if (isValidImage)
          GestureDetector(
            onTap: () => _showFullImage(fullImageUrl),
            child: Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      fullImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return GestureDetector(
                          onTap: () => _showFullImage(fullImageUrl),
                          child: Container(
                            color: Colors.grey[100],
                            padding: REdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48.sp,
                                  color: Colors.grey.shade400,
                                ),
                                8.verticalSpace,
                                Text(
                                  'Gagal memuat gambar',
                                  style: TS.bodySmall.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                4.verticalSpace,
                                Text(
                                  fullImageUrl,
                                  style: TS.bodySmall.copyWith(
                                    color: primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Overlay untuk indikasi bisa diklik
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: REdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: REdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 20.sp,
                  color: Colors.grey.shade600,
                ),
                8.horizontalSpace,
                Expanded(
                  child: Text(
                    'Tidak ada gambar',
                    style: TS.bodyMedium.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    try {
      final formatter = DateFormat('dd-MM-yyyy HH:mm', 'id_ID');
      return formatter.format(date);
    } catch (e) {
      final formatter = DateFormat('dd-MM-yyyy HH:mm');
      return formatter.format(date);
    }
  }
}

