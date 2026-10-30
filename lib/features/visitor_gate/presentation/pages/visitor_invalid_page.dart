import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../data/visitor_gate_models.dart';
import '../widgets/gate_widgets.dart';

class VisitorInvalidPage extends StatelessWidget {
  const VisitorInvalidPage({
    super.key,
    required this.result,
    required this.canWalkIn,
  });

  final VisitorScanResult result;
  final bool canWalkIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_2, color: errorColor, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                'QR Tidak Valid',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: neutral90,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.reason ?? 'Kode tidak dapat digunakan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: neutral70),
              ),
              if (result.code.isNotEmpty) ...[
                const SizedBox(height: 8),
                GateChip(label: result.code, color: neutral70),
              ],
              const Spacer(),
              GateButton(
                label: 'Scan ulang',
                icon: Icons.qr_code_scanner,
                onPressed: () =>
                    Navigator.of(context).pop(VisitorFlowAction.scan),
              ),
              const SizedBox(height: 12),
              GateButton(
                label: 'Kode manual',
                icon: Icons.keyboard_alt_outlined,
                outlined: true,
                onPressed: () =>
                    Navigator.of(context).pop(VisitorFlowAction.manual),
              ),
              if (canWalkIn) ...[
                const SizedBox(height: 12),
                GateButton(
                  label: 'Minta persetujuan penghuni',
                  icon: Icons.person_add_alt_1_outlined,
                  outlined: true,
                  onPressed: () =>
                      Navigator.of(context).pop(VisitorFlowAction.walkIn),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
