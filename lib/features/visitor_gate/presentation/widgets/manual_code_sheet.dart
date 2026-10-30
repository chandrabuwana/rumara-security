import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import 'gate_widgets.dart';

class ManualCodeSheet extends StatefulWidget {
  const ManualCodeSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ManualCodeSheet(),
    );
  }

  @override
  State<ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<ManualCodeSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: neutral20,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Masukkan kode visitor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: neutral90,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kode undangan, kode akses rutin, atau kode delivery dari penghuni.',
            style: TextStyle(fontSize: 12, color: neutral50),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Contoh: RMR-123456',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          GateButton(
              label: 'Periksa kode', icon: Icons.search, onPressed: _submit),
        ],
      ),
    );
  }
}
