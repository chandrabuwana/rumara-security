import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/Buttons/ui_button.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/profile_detail_item.dart';
import 'edit_name_screen.dart';

/// Layar detail profil yang menampilkan semua informasi profil lengkap
class ProfileDetailsScreen extends StatelessWidget {
  final String userId;

  const ProfileDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ProfileBloc>()..add(LoadProfileEvent(userId)),
      child: ProfileDetailsScreenView(userId: userId),
    );
  }
}

class _PdfPreview extends StatefulWidget {
  final String url;

  const _PdfPreview({required this.url});

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: _loadDocument(widget.url),
    );
  }

  Future<PdfDocument> _loadDocument(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    return PdfDocument.openData(bytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(
      controller: _controller,
      scrollDirection: Axis.vertical,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const CircularProgressIndicator(
          color: Colors.white,
        ),
        pageLoaderBuilder: (_) => const CircularProgressIndicator(
          color: Colors.white,
        ),
        errorBuilder: (_, error) => Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'Gagal memuat PDF',
            style: TS.bodyMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class ProfileDetailsScreenView extends StatefulWidget {
  final String userId;

  const ProfileDetailsScreenView({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileDetailsScreenView> createState() =>
      _ProfileDetailsScreenViewState();
}

class _ProfileDetailsScreenViewState extends State<ProfileDetailsScreenView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey.shade50,
      enableScrolling: false, // Disable scrolling since we're using TabBarView
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profil Saya',
          style: TS.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Info Pribadi'),
            Tab(text: 'Dokumen'),
          ],
        ),
      ),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          // Handle profile update success
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Handle profile update failure
          if (state is ProfileUpdateFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }

          // Handle document upload success
          if (state is DocumentUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Dokumen ${state.documentType} berhasil diupload'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Handle document upload failure
          if (state is DocumentUploadFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64.w,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error: ${state.message}',
                    style: TS.bodyMedium.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  UIButton(
                    text: 'Coba Lagi',
                    onPressed: () {
                      context
                          .read<ProfileBloc>()
                          .add(LoadProfileEvent(widget.userId));
                    },
                  ),
                ],
              ),
            );
          }

          if (state is ProfileLoaded ||
              state is ProfileUpdateInProgress ||
              state is DocumentUploadInProgress) {
            final profile = _getProfileFromState(state);
            final isLoading = state is ProfileUpdateInProgress ||
                state is DocumentUploadInProgress;

            return Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab Info Pribadi
                    _buildInfoPribadiTab(profile),

                    // Tab Dokumen
                    _buildDokumenTab(profile),
                  ],
                ),

                // Loading overlay
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  /// Build tab info pribadi
  Widget _buildInfoPribadiTab(dynamic profile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          // Foto profil
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100.w,
                  height: 100.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2.w,
                    ),
                  ),
                  child: ClipOval(
                    child: profile.profileImageUrl != null
                        ? Image.network(
                            profile.profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 50.w,
                                color: Colors.grey.shade400,
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            size: 50.w,
                            color: Colors.grey.shade400,
                          ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          Text(
            'Foto Profile',
            style: TS.bodyMedium.copyWith(color: Colors.grey.shade600),
          ),

          SizedBox(height: 24.h),

          // Data profil
          ProfileDetailItem(
            label: 'Nama',
            value: profile.name,
            // onTap: () => _navigateToEditName(profile),
          ),
          ProfileDetailItem(
            label: 'No NRP',
            value: profile.nrp,
          ),
          ProfileDetailItem(
            label: 'Email',
            value: profile.email,
          ),

          ProfileDetailItem(
            label: 'No KTP',
            value: profile.noKtp,
          ),

          ProfileDetailItem(
            label: 'Tempat Lahir',
            value: profile.tempatLahir,
          ),

          if (profile.tanggalLahir != null)
            ProfileDetailItem(
              label: 'Tanggal Lahir',
              value: _formatDate(profile.tanggalLahir!),
            ),

          ProfileDetailItem(
            label: 'Jenis Kelamin',
            value: profile.jenisKelamin,
          ),

          ProfileDetailItem(
            label: 'Pendidikan',
            value: profile.pendidikan,
          ),

          ProfileDetailItem(
            label: 'Telepon Pribadi',
            value: profile.teleponPribadi,
          ),

          ProfileDetailItem(
            label: 'Telepon Darurat',
            value: profile.teleponDarurat,
          ),

          ProfileDetailItem(
            label: 'Site',
            value: profile.site,
          ),

          ProfileDetailItem(
            label: 'Jabatan',
            value: profile.jabatan,
          ),

          ProfileDetailItem(
            label: 'Atasan',
            value: profile.namaAtasan ?? '-',
          ),

          if (profile.tglPenerimaanKaryawan != null)
            ProfileDetailItem(
              label: 'Tgl Penerimaan Karyawan',
              value: _formatDate(profile.tglPenerimaanKaryawan!),
            ),

          if (profile.masaBerlakuPermit != null)
            ProfileDetailItem(
              label: 'Masa Berlaku Permit',
              value: _formatDate(profile.masaBerlakuPermit!),
            ),

          ProfileDetailItem(
            label: 'Kompetensi Pekerjaan',
            value: profile.kompetensiPekerjaan,
          ),

          ProfileDetailItem(
            label: 'Warga Negara',
            value: profile.wargaNegara,
          ),

          ProfileDetailItem(
            label: 'Provinsi',
            value: profile.provinsi,
          ),

          ProfileDetailItem(
            label: 'Kota / Kabupaten',
            value: profile.kotaKabupaten,
          ),

          ProfileDetailItem(
            label: 'Kecamatan',
            value: profile.kecamatan,
          ),

          ProfileDetailItem(
            label: 'Kelurahan',
            value: profile.kelurahan,
          ),

          ProfileDetailItem(
            label: 'Alamat Domisili',
            value: profile.alamatDomisili,
            isLastItem: true,
          ),
        ],
      ),
    );
  }

  /// Build tab dokumen
  Widget _buildDokumenTab(dynamic profile) {
    final documents = profile.documents as Map<String, String>?;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          _buildDocumentItem(
            'KTP',
            documents?['ktp'] ?? 'Belum diupload',
            () => _uploadDocument('KTP'),
            hasDocument: documents?['ktp']?.isNotEmpty ?? false,
          ),
          SizedBox(height: 16.h),
          _buildDocumentItem(
            'KTA',
            documents?['kta'] ?? 'Belum diupload',
            () => _uploadDocument('KTA'),
            hasDocument: documents?['kta']?.isNotEmpty ?? false,
          ),
          SizedBox(height: 16.h),
          _buildDocumentItem(
            'Foto',
            documents?['foto'] ?? 'Belum diupload',
            () => _uploadDocument('Foto'),
            hasDocument: documents?['foto']?.isNotEmpty ?? false,
          ),
          SizedBox(height: 16.h),
          _buildDocumentItem(
            'P3TD K3LH',
            documents?['p3td_k3lh'] ?? 'Belum diupload',
            () => _uploadDocument('P3TD_K3LH'),
            hasDocument: documents?['p3td_k3lh']?.isNotEmpty ?? false,
          ),
          SizedBox(height: 16.h),
          _buildDocumentItem(
            'P3TD Security',
            documents?['p3td_security'] ?? 'Belum diupload',
            () => _uploadDocument('P3TD_Security'),
            hasDocument: documents?['p3td_security']?.isNotEmpty ?? false,
          ),
          SizedBox(height: 16.h),
          _buildDocumentItem(
            'Pernyataan Tidak Merokok',
            documents?['pernyataan_tidak_merokok'] ?? 'Belum diupload',
            () => _uploadDocument('Tidak_Merokok'),
            hasDocument:
                documents?['pernyataan_tidak_merokok']?.isNotEmpty ?? false,
          ),
        ],
      ),
    );
  }

  /// Build document item widget
  Widget _buildDocumentItem(
      String title, String filename, VoidCallback onUpload,
      {bool hasDocument = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () {
          if (hasDocument) {
            _showDocumentPreview(title: title, source: filename);
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title belum diupload'),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasDocument
                  ? primaryColor.withOpacity(0.3)
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasDocument ? Icons.check_circle : Icons.upload_file,
                color: hasDocument ? Colors.green : Colors.grey.shade400,
                size: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TS.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      filename,
                      style: TS.bodySmall.copyWith(
                        color:
                            hasDocument ? Colors.green : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16.w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentPreview({required String title, required String source}) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'belum diupload') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title belum diupload'),
        ),
      );
      return;
    }

    final lower = trimmed.toLowerCase();
    final isImage = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
    final isPdf = lower.endsWith('.pdf');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TS.titleMedium.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: Center(
                    child: isImage
                        ? InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              trimmed,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const CircularProgressIndicator(
                                  color: Colors.white,
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: Text(
                                    'Gagal memuat gambar',
                                    style: TS.bodyMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          )
                        : isPdf
                            ? _PdfPreview(url: trimmed)
                            : Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'Preview hanya tersedia untuk gambar.\nSumber: $trimmed',
                                  style: TS.bodyMedium
                                      .copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper method untuk mendapatkan profile dari berbagai state
  dynamic _getProfileFromState(ProfileState state) {
    if (state is ProfileLoaded) return state.profile;
    if (state is ProfileUpdateInProgress) return state.currentProfile;
    if (state is DocumentUploadInProgress) return state.currentProfile;
    return null;
  }

  /// Navigate ke halaman edit nama
  void _navigateToEditName(dynamic profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditNameScreen(
          userId: widget.userId,
          currentName: profile.name,
        ),
      ),
    );
  }

  /// Upload dokumen
  void _uploadDocument(String documentType) {
    // TODO: Implement file picker dan upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur upload $documentType akan segera tersedia'),
      ),
    );
  }

  /// Format date with error handling
  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      // Fallback to basic formatting if locale data is not available
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}
