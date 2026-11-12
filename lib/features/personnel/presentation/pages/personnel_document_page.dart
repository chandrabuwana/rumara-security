import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfx/pdfx.dart';
import '../../../../core/design/colors.dart';
import '../bloc/personnel_bloc.dart';
import '../bloc/personnel_event.dart';
import '../../domain/entities/personnel.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

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
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class PersonnelDocumentPage extends StatefulWidget {
  final Personnel personnel;

  const PersonnelDocumentPage({super.key, required this.personnel});

  @override
  State<PersonnelDocumentPage> createState() => _PersonnelDocumentPageState();
}

class _PersonnelDocumentPageState extends State<PersonnelDocumentPage> {
  final TextEditingController _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral10,
      appBar: const RumaraAppBar(title: 'Dokumen Personil'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            16.verticalSpace,

            // Documents Section
            if (_hasDocuments(widget.personnel))
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [        
                    if (widget.personnel.ktpUrl != null) ...[
                      _buildDocumentItem('KTP', widget.personnel.ktpUrl!),
                      SizedBox(height: 16.h),
                    ],
                    if (widget.personnel.ktaUrl != null) ...[
                      _buildDocumentItem('KTA', widget.personnel.ktaUrl!),
                      SizedBox(height: 16.h),
                    ],
                    if (widget.personnel.fotoUrl != null) ...[
                      _buildDocumentItem('Foto', widget.personnel.fotoUrl!),
                      SizedBox(height: 16.h),
                    ],
                    if (widget.personnel.p3tdK3lhUrl != null) ...[
                      _buildDocumentItem(
                          'P3TD K3LH', widget.personnel.p3tdK3lhUrl!),
                      SizedBox(height: 16.h),
                    ],
                    if (widget.personnel.p3tdSecurityUrl != null) ...[
                      _buildDocumentItem(
                          'P3TD Security', widget.personnel.p3tdSecurityUrl!),
                      SizedBox(height: 16.h),
                    ],
                    if (widget.personnel.pernyataanTidakMerokokUrl != null)
                      _buildDocumentItem(
                        'Pernyataan Tidak Merokok',
                        widget.personnel.pernyataanTidakMerokokUrl!,
                      ),
                  ],
                ),
              ),

            // 24.verticalSpace,

            // Feedback Form for Pending Status
            if (widget.personnel.status == 'Pending')
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.all(24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Umpan Balik',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: neutral90,
                        ),
                      ),
                      16.verticalSpace,
                      TextFormField(
                        controller: _feedbackController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Tulis umpan balik di sini...',
                          hintStyle: TextStyle(
                            fontSize: 14.sp,
                            color: neutral50,
                          ),
                          filled: true,
                          fillColor: neutral10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(16.w),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Umpan balik wajib diisi';
                          }
                          return null;
                        },
                      ),
                      24.verticalSpace,
                      Row(
                        children: [
                          // Revisi Button
                          Expanded(
                            child: SizedBox(
                              height: 52.h,
                              child: OutlinedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _showReviseConfirmation(
                                        context, widget.personnel.id);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: neutral70,
                                  side: BorderSide(color: neutral50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Revisi',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          16.horizontalSpace,
                          // Setujui Button
                          Expanded(
                            child: SizedBox(
                              height: 52.h,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _showApproveConfirmation(
                                        context, widget.personnel.id);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Setujui',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
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

            24.verticalSpace,
          ],
        ),
      ),
    );
  }

  void _showApproveConfirmation(BuildContext context, String personnelId) {
    final personnelBloc = context.read<PersonnelBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Persetujuan'),
        content: const Text('Apakah Anda yakin ingin menyetujui personil ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              personnelBloc.add(
                    ApprovePersonnelEvent(
                      personnelId,
                      _feedbackController.text.trim(),
                    ),
                  );
              _feedbackController.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showReviseConfirmation(BuildContext context, String personnelId) {
    final personnelBloc = context.read<PersonnelBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Revisi'),
        content: const Text(
            'Apakah Anda yakin ingin meminta revisi untuk personil ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              personnelBloc.add(
                    RevisePersonnelEvent(
                      personnelId,
                      _feedbackController.text.trim(),
                    ),
                  );
              _feedbackController.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: neutral70,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revisi'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String title, String documentUrl) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showDocumentPreview(title: title, source: documentUrl),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: neutral10,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: primaryColor,
                size: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      documentUrl,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
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
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title tidak tersedia'),
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                title,
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: isImage
                  ? InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          trimmed,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                'Gagal memuat gambar',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : isPdf
                      ? _PdfPreview(url: trimmed)
                      : Center(
                          child: Text(
                            'Format file tidak didukung',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasDocuments(Personnel personnel) {
    return personnel.ktpUrl != null ||
        personnel.ktaUrl != null ||
        personnel.fotoUrl != null ||
        personnel.p3tdK3lhUrl != null ||
        personnel.p3tdSecurityUrl != null ||
        personnel.pernyataanTidakMerokokUrl != null;
  }
}
