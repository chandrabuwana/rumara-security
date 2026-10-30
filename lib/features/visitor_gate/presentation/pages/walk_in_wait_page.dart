import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/colors.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';
import '../cubit/walk_in_wait_cubit.dart';
import '../widgets/gate_widgets.dart';
import 'visitor_done_page.dart';

class WalkInWaitPage extends StatelessWidget {
  const WalkInWaitPage({
    super.key,
    required this.repository,
    required this.ticket,
  });

  final VisitorGateRepository repository;
  final WalkInTicket ticket;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WalkInWaitCubit(repository, ticket)..start(),
      child: const _WalkInWaitView(),
    );
  }
}

class _WalkInWaitView extends StatefulWidget {
  const _WalkInWaitView();

  @override
  State<_WalkInWaitView> createState() => _WalkInWaitViewState();
}

class _WalkInWaitViewState extends State<_WalkInWaitView> {
  bool _identityChecked = false;

  Future<void> _done(WalkInWaitState state) async {
    final record = state.record;
    if (record == null) return;
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VisitorDonePage(
          record: record,
          isCheckOut: false,
          fallbackName: state.ticket.name,
          fallbackUnit: state.ticket.unitLabel,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalkInWaitCubit, WalkInWaitState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase || previous.error != current.error,
      listener: (context, state) {
        if (state.phase == WalkInPhase.admitted) {
          _done(state);
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              GateHeader(
                  title: _title(state.phase), subtitle: 'Walk-In Visitor'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _status(state),
                    const SizedBox(height: 16),
                    _VisitorSummaryCard(ticket: state.ticket),
                    if (state.phase == WalkInPhase.noResponse) ...[
                      const SizedBox(height: 12),
                      GateCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: CheckboxListTile(
                          value: _identityChecked,
                          onChanged: (value) =>
                              setState(() => _identityChecked = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Identitas sudah diperiksa'),
                          subtitle: const Text(
                            'Wajib dicentang sebelum memberi akses default.',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _actions(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _title(WalkInPhase phase) {
    switch (phase) {
      case WalkInPhase.waiting:
        return 'Menunggu Penghuni';
      case WalkInPhase.noResponse:
        return 'Penghuni Belum Merespons';
      case WalkInPhase.approved:
      case WalkInPhase.admitted:
        return 'Disetujui';
      case WalkInPhase.rejected:
        return 'Ditolak';
      case WalkInPhase.expired:
        return 'Kedaluwarsa';
      case WalkInPhase.cancelled:
        return 'Dibatalkan';
    }
  }

  Widget _status(WalkInWaitState state) {
    final status = state.status;
    switch (state.phase) {
      case WalkInPhase.waiting:
        return GateCard(
          child: Column(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value:
                          state.total == 0 ? 0 : state.remaining / state.total,
                      strokeWidth: 10,
                      backgroundColor: primary10,
                      color: primaryColor,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${state.remaining}',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: neutral90,
                            ),
                          ),
                          Text('detik', style: TextStyle(color: neutral50)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Permintaan dikirim ke semua akun unit',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, color: neutral90),
              ),
              const SizedBox(height: 4),
              Text(
                'Tunggu penghuni menyetujui atau menolak tamu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: neutral50),
              ),
            ],
          ),
        );
      case WalkInPhase.noResponse:
        return GateBanner(
          icon: Icons.hourglass_bottom,
          title: 'Penghuni belum merespons',
          message:
              'Anda boleh memberi akses default setelah memeriksa identitas. Kunjungan ditandai tanpa persetujuan dan penghuni tetap menerima notifikasi.',
          color: gateWarningColor,
        );
      case WalkInPhase.approved:
      case WalkInPhase.admitted:
        return GateBanner(
          icon: Icons.verified_outlined,
          title: 'Disetujui ${status?.decidedBy ?? 'penghuni'}',
          message: [
            if (status?.decidedAt != null)
              'Pukul ${GateFormat.time(status!.decidedAt)}',
            if (status?.note != null) status!.note!,
          ].join(' · '),
          color: successColor,
        );
      case WalkInPhase.rejected:
        return GateBanner(
          icon: Icons.block,
          title: 'Ditolak ${status?.decidedBy ?? 'penghuni'}',
          message: status?.note ?? 'Tamu tidak diizinkan masuk.',
          color: errorColor,
        );
      case WalkInPhase.expired:
        return GateBanner(
          icon: Icons.timer_off_outlined,
          title: 'Permintaan kedaluwarsa',
          message: 'Buat permintaan baru bila tamu masih menunggu.',
          color: neutral70,
        );
      case WalkInPhase.cancelled:
        return GateBanner(
          icon: Icons.cancel_outlined,
          title: 'Permintaan dibatalkan',
          message: 'Tamu tidak diizinkan masuk.',
          color: neutral70,
        );
    }
  }

  Widget _actions(BuildContext context, WalkInWaitState state) {
    final cubit = context.read<WalkInWaitCubit>();
    switch (state.phase) {
      case WalkInPhase.waiting:
        return GateButton(
          label: 'Batalkan',
          tone: GateButtonTone.danger,
          outlined: true,
          loading: state.busy,
          onPressed: cubit.cancel,
        );
      case WalkInPhase.noResponse:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GateButton(
              label: 'Izinkan Masuk (default)',
              icon: Icons.login,
              tone: GateButtonTone.success,
              loading: state.busy,
              onPressed: _identityChecked ? cubit.admitDefault : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GateButton(
                    label: 'Tunggu lagi',
                    outlined: true,
                    onPressed: state.busy ? null : cubit.waitMore,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GateButton(
                    label: 'Tolak',
                    tone: GateButtonTone.danger,
                    outlined: true,
                    onPressed: state.busy ? null : cubit.cancel,
                  ),
                ),
              ],
            ),
          ],
        );
      case WalkInPhase.approved:
      case WalkInPhase.admitted:
        return GateButton(
          label: 'Izinkan Masuk',
          icon: Icons.login,
          tone: GateButtonTone.success,
          loading: state.busy,
          onPressed:
              state.phase == WalkInPhase.approved ? cubit.admitApproved : null,
        );
      case WalkInPhase.rejected:
      case WalkInPhase.expired:
      case WalkInPhase.cancelled:
        return GateButton(
          label: 'Kembali ke Visitor',
          onPressed: () => Navigator.of(context).pop(),
        );
    }
  }
}

class _VisitorSummaryCard extends StatelessWidget {
  const _VisitorSummaryCard({required this.ticket});

  final WalkInTicket ticket;

  @override
  Widget build(BuildContext context) {
    final photo = ticket.photoUrl;
    return GateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: neutral10,
                  child: photo == null
                      ? Icon(Icons.person_outline, color: neutral50)
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.person_outline, color: neutral50),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: neutral90,
                      ),
                    ),
                    Text(
                      ticket.phone ?? '-',
                      style: TextStyle(fontSize: 12, color: neutral50),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GateInfoRow(label: 'Tujuan unit', value: ticket.unitLabel),
          GateInfoRow(label: 'Jenis kunjungan', value: ticket.visitorType),
          GateInfoRow(
              label: 'Jumlah orang', value: '${ticket.guestCount} orang'),
          GateInfoRow(label: 'Plat kendaraan', value: ticket.plateNumber),
          GateInfoRow(label: 'Keperluan', value: ticket.purpose),
          GateInfoRow(
              label: 'Dikirim', value: GateFormat.time(ticket.requestedAt)),
        ],
      ),
    );
  }
}
