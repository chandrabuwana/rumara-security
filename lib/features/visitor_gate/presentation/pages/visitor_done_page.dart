import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../data/visitor_gate_models.dart';
import '../widgets/gate_widgets.dart';

class VisitorDonePage extends StatelessWidget {
  const VisitorDonePage({
    super.key,
    required this.record,
    required this.isCheckOut,
    this.fallbackName,
    this.fallbackUnit,
  });

  final VisitorVisitRecord record;
  final bool isCheckOut;
  final String? fallbackName;
  final String? fallbackUnit;

  @override
  Widget build(BuildContext context) {
    final color = isCheckOut ? primaryColor : successColor;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckOut ? Icons.logout : Icons.check_circle,
                  color: color,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCheckOut ? 'Keluar Tercatat' : 'Masuk Tercatat',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: neutral90,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Penghuni sudah menerima notifikasi.',
                style: TextStyle(color: neutral50),
              ),
              const SizedBox(height: 24),
              GateCard(
                child: Column(
                  children: [
                    GateInfoRow(
                        label: 'Nama', value: record.name ?? fallbackName),
                    GateInfoRow(
                        label: 'Tujuan unit',
                        value: record.unit ?? fallbackUnit),
                    GateInfoRow(
                        label: 'Jumlah tamu',
                        value: '${record.guestCount} orang'),
                    GateInfoRow(
                      label: 'Waktu masuk',
                      value: GateFormat.dateTime(record.checkInAt),
                    ),
                    if (isCheckOut) ...[
                      GateInfoRow(
                        label: 'Waktu keluar',
                        value: GateFormat.dateTime(record.checkOutAt),
                      ),
                      GateInfoRow(
                        label: 'Lama berkunjung',
                        value: GateFormat.duration(record.durationMinutes),
                      ),
                    ],
                    GateInfoRow(label: 'Petugas', value: record.verifiedBy),
                  ],
                ),
              ),
              const Spacer(),
              GateButton(
                label: 'Scan berikutnya',
                icon: Icons.qr_code_scanner,
                onPressed: () =>
                    Navigator.of(context).pop(VisitorFlowAction.scan),
              ),
              const SizedBox(height: 12),
              GateButton(
                label: 'Kembali ke Visitor',
                outlined: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
