import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';
import '../cubit/visitor_action_cubit.dart';
import '../widgets/gate_widgets.dart';
import 'visitor_done_page.dart';

class VisitorConfirmPage extends StatelessWidget {
  const VisitorConfirmPage({
    super.key,
    required this.repository,
    required this.result,
  });

  final VisitorGateRepository repository;
  final VisitorScanResult result;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VisitorActionCubit(repository),
      child: _VisitorConfirmView(result: result),
    );
  }
}

class _VisitorConfirmView extends StatefulWidget {
  const _VisitorConfirmView({required this.result});

  final VisitorScanResult result;

  @override
  State<_VisitorConfirmView> createState() => _VisitorConfirmViewState();
}

class _VisitorConfirmViewState extends State<_VisitorConfirmView> {
  late int _guests =
      widget.result.guestCount < 1 ? 1 : widget.result.guestCount;

  bool get _isCheckOut => widget.result.action == VisitorScanAction.checkOut;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  void _submit() {
    final cubit = context.read<VisitorActionCubit>();
    final result = widget.result;
    if (_isCheckOut) {
      final visitId = result.visitId;
      if (visitId != null) cubit.checkOut(visitId);
    } else {
      cubit.checkIn(result.code, _guests);
    }
  }

  Future<void> _done(VisitorVisitRecord record) async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VisitorDonePage(
          record: record,
          isCheckOut: _isCheckOut,
          fallbackName: widget.result.name,
          fallbackUnit: widget.result.unit,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return BlocConsumer<VisitorActionCubit, VisitorActionState>(
      listener: (context, state) {
        if (state.status == VisitorActionStatus.success &&
            state.record != null) {
          _done(state.record!);
        } else if (state.status == VisitorActionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? 'Gagal menyimpan.')),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              GateHeader(
                title: _isCheckOut ? 'Konfirmasi Keluar' : 'Konfirmasi Masuk',
                subtitle: result.kindLabel,
                trailing: result.residentPhone == null
                    ? null
                    : IconButton(
                        tooltip: 'Telepon penghuni',
                        onPressed: () => _call(result.residentPhone!),
                        icon: const Icon(Icons.call_outlined,
                            color: Colors.white),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _banner(result),
                    const SizedBox(height: 16),
                    GateCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.name ?? '-',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: neutral90,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GateInfoRow(
                              label: 'Jenis tamu', value: result.visitorType),
                          if (result.code.isNotEmpty)
                            GateInfoRow(label: 'Kode', value: result.code),
                          GateInfoRow(label: 'Tujuan unit', value: result.unit),
                          GateInfoRow(
                              label: 'Penghuni', value: result.invitedBy),
                          GateInfoRow(label: 'Jadwal', value: result.schedule),
                          if (result.phone != null)
                            GateInfoRow(
                                label: 'No. HP tamu', value: result.phone),
                          if (result.vehicleType != null ||
                              result.plateNumber != null)
                            GateInfoRow(
                              label: 'Kendaraan',
                              value: [result.vehicleType, result.plateNumber]
                                  .whereType<String>()
                                  .join(' · '),
                            ),
                          if (_isCheckOut) ...[
                            GateInfoRow(
                              label: 'Masuk',
                              value: GateFormat.dateTime(result.checkInAt),
                            ),
                            GateInfoRow(
                              label: 'Lama berkunjung',
                              value:
                                  GateFormat.duration(result.durationMinutes),
                            ),
                            GateInfoRow(
                                label: 'Petugas masuk',
                                value: result.verifiedBy),
                            GateInfoRow(
                                label: 'Jumlah tamu',
                                value: '${result.guestCount} orang'),
                          ],
                          if (result.securityNote != null)
                            GateInfoRow(
                                label: 'Catatan', value: result.securityNote),
                        ],
                      ),
                    ),
                    if (!_isCheckOut && result.guestCount > 1) ...[
                      const SizedBox(height: 12),
                      _GuestStepper(
                        value: _guests,
                        max: result.guestCount,
                        onChanged: (value) => setState(() => _guests = value),
                      ),
                    ],
                    if (result.timeline.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Timeline(entries: result.timeline),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _isCheckOut
                      ? GateButton(
                          label: 'Konfirmasi Keluar',
                          icon: Icons.logout,
                          loading: state.busy,
                          onPressed: _submit,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: GateButton(
                                label: 'Tolak',
                                tone: GateButtonTone.danger,
                                outlined: true,
                                onPressed: state.busy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: GateButton(
                                label: 'Izinkan Masuk',
                                icon: Icons.login,
                                tone: GateButtonTone.success,
                                loading: state.busy,
                                onPressed: _submit,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _banner(VisitorScanResult result) {
    if (_isCheckOut) {
      return result.overdue
          ? GateBanner(
              icon: Icons.schedule,
              title: 'Lewat batas waktu kunjungan',
              message: result.validUntil == null
                  ? null
                  : 'Batas ${GateFormat.time(result.validUntil)}',
              color: gateWarningColor,
            )
          : GateBanner(
              icon: Icons.meeting_room_outlined,
              title: 'Tamu sedang di dalam',
              message: 'Konfirmasi untuk mencatat waktu keluar.',
              color: primaryColor,
            );
    }
    return GateBanner(
      icon: Icons.verified_outlined,
      title: '${result.kindLabel} valid',
      message: result.validUntil == null
          ? null
          : 'Berlaku sampai ${GateFormat.time(result.validUntil)}',
      color: successColor,
    );
  }
}

class _GuestStepper extends StatelessWidget {
  const _GuestStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GateCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah tamu masuk',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: neutral90),
                ),
                Text(
                  'Maksimal $max orang sesuai undangan',
                  style: TextStyle(fontSize: 12, color: neutral50),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$value',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: neutral90),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<VisitorTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linimasa',
            style: TextStyle(fontWeight: FontWeight.w700, color: neutral90),
          ),
          const SizedBox(height: 8),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 10, color: primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: neutral90,
                          ),
                        ),
                        Text(
                          [
                            GateFormat.time(entry.at),
                            if (entry.by != null) entry.by!
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: neutral50),
                        ),
                        if (entry.note != null)
                          Text(
                            entry.note!,
                            style: TextStyle(fontSize: 12, color: neutral70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
