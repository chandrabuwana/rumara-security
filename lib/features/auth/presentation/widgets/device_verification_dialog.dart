import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceVerificationDialog extends StatefulWidget {
  const DeviceVerificationDialog({
    super.key,
    required this.message,
    required this.onRequestOtp,
  });

  final String message;
  final Future<({bool ok, String message})> Function() onRequestOtp;

  @override
  State<DeviceVerificationDialog> createState() =>
      _DeviceVerificationDialogState();
}

class _DeviceVerificationDialogState extends State<DeviceVerificationDialog> {
  static const int _length = 6;
  final _codeController = TextEditingController();
  bool _sending = false;
  String? _info;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final sent = await widget.onRequestOtp();
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent.ok) {
        _info = sent.message;
      } else {
        _error = sent.message;
      }
    });
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.length != _length) {
      setState(() => _error = 'Kode OTP harus $_length digit');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verifikasi Perangkat Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _sending ? null : _sendOtp,
              child: Text(
                _sending
                    ? 'Mengirim...'
                    : _info == null
                        ? 'Kirim Kode OTP ke Email'
                        : 'Kirim Ulang Kode OTP',
              ),
            ),
            if (_info != null) ...[
              const SizedBox(height: 8),
              Text(_info!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: _length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Kode OTP',
                errorText: _error,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Verifikasi')),
      ],
    );
  }
}
