import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/manual_code_sheet.dart';

class VisitorScanPage extends StatefulWidget {
  const VisitorScanPage({super.key});

  @override
  State<VisitorScanPage> createState() => _VisitorScanPageState();
}

class _VisitorScanPageState extends State<VisitorScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String? code) {
    if (_done || code == null || code.trim().isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code.trim());
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _finish(value);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torch = !_torch);
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final capture = await _controller.analyzeImage(file.path);
    if (!mounted) return;
    final value = capture?.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere((raw) => raw != null && raw.trim().isNotEmpty,
            orElse: () => null);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR tidak ditemukan pada gambar.')),
      );
      return;
    }
    _finish(value);
  }

  Future<void> _manual() async {
    final code = await ManualCodeSheet.show(context);
    if (!mounted) return;
    _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.68;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan QR Visitor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Arahkan kamera ke QR undangan. Sistem otomatis menentukan tamu masuk atau keluar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ScanAction(
                      icon: _torch ? Icons.flash_on : Icons.flash_off,
                      label: 'Senter',
                      onTap: _toggleTorch,
                    ),
                    _ScanAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: _pickImage,
                    ),
                    _ScanAction(
                      icon: Icons.keyboard_alt_outlined,
                      label: 'Kode manual',
                      onTap: _manual,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
