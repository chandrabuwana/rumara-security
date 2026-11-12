import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'package:dio/dio.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../domain/entities/document_entity.dart';
import '../../../../shared/widgets/rumara_app_bar.dart';

/// Halaman preview dokumen (PDF atau gambar)
class DocumentPreviewPage extends StatefulWidget {
  final DocumentEntity document;

  const DocumentPreviewPage({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  PdfController? _pdfController;
  bool _isPdfLoading = true;
  String? _pdfError;

  bool get _isImage {
    if (widget.document.fileType == null) return false;
    final type = widget.document.fileType!.toLowerCase();
    return type == 'jpg' || type == 'jpeg' || type == 'png' || type == 'gif' || type == 'webp';
  }

  bool get _isPdf {
    if (widget.document.fileType == null) return false;
    return widget.document.fileType!.toLowerCase() == 'pdf';
  }

  @override
  void initState() {
    super.initState();
    
    // Validasi jika fileUrl kosong
    if (widget.document.fileUrl.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFileNotAvailableDialog();
      });
      return;
    }
    
    if (_isPdf) {
      _loadPdf();
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isPdfLoading = true;
        _pdfError = null;
      });

      final pdfData = await _loadPdfData(widget.document.fileUrl);
      final document = PdfDocument.openData(pdfData);
      final controller = PdfController(
        document: document,
      );

      setState(() {
        _pdfController = controller;
        _isPdfLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPdfLoading = false;
        _pdfError = e.toString();
      });
    }
  }

  Future<Uint8List> _loadPdfData(String url) async {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.black,
      enableScrolling: false,
      appBar: RumaraAppBar(title: widget.document.title, actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Buka di Browser',
            onPressed: () => _openInBrowser(context),
          ),
        ]),
      child: _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_isImage) {
      return _buildImagePreview(context);
    } else if (_isPdf) {
      return _buildPdfPreview(context);
    } else {
      return _buildUnsupportedPreview(context);
    }
  }

  Widget _buildImagePreview(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          widget.document.fileUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: primaryColor,
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
                    size: 64.sp,
                    color: Colors.white54,
                  ),
                  16.verticalSpace,
                  Text(
                    'Gagal memuat gambar',
                    style: TS.bodyMedium.copyWith(color: Colors.white70),
                  ),
                  16.verticalSpace,
                  ElevatedButton.icon(
                    onPressed: () => _openInBrowser(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Buka di Browser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context) {
    if (_isPdfLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: primaryColor,
            ),
            24.verticalSpace,
            Text(
              'Memuat PDF...',
              style: TS.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_pdfError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Colors.red[300],
            ),
            16.verticalSpace,
            Text(
              'Gagal memuat PDF',
              style: TS.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            8.verticalSpace,
            Text(
              _pdfError!,
              style: TS.bodySmall.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            24.verticalSpace,
            ElevatedButton.icon(
              onPressed: () {
                _loadPdf();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            16.verticalSpace,
            OutlinedButton.icon(
              onPressed: () => _openInBrowser(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka di Browser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 80.sp,
              color: Colors.white54,
            ),
            24.verticalSpace,
            Text(
              'PDF tidak tersedia',
              style: TS.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return PdfView(
      controller: _pdfController!,
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
        pageLoaderBuilder: (_) => Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
        errorBuilder: (_, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: Colors.red[300]),
              16.verticalSpace,
              Text(
                'Error: $error',
                style: TS.bodySmall.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedPreview(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 80.sp,
            color: Colors.white54,
          ),
          24.verticalSpace,
          Text(
            'Preview Tidak Tersedia',
            style: TS.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          8.verticalSpace,
          Text(
            'Format file ${widget.document.fileType ?? "tidak diketahui"} tidak dapat di-preview.\nGunakan tombol di bawah untuk membuka di browser.',
            style: TS.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          32.verticalSpace,
          ElevatedButton.icon(
            onPressed: () => _openInBrowser(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka di Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: REdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser(BuildContext context) async {
    try {
      final uri = Uri.parse(widget.document.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat membuka: ${widget.document.fileUrl}'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _showFileNotAvailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: primaryColor,
              size: 24.sp,
            ),
            8.horizontalSpace,
            Expanded(
              child: Text(
                'File Tidak Tersedia',
                style: TS.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: neutral90,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File untuk dokumen "${widget.document.title}" tidak tersedia.',
              style: TS.bodyMedium.copyWith(color: Colors.black),
            ),
            8.verticalSpace,
            Text(
              'Silakan hubungi administrator untuk informasi lebih lanjut.',
              style: TS.bodySmall.copyWith(color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close preview page
            },
            child: Text(
              'Tutup',
              style: TS.labelLarge.copyWith(color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

