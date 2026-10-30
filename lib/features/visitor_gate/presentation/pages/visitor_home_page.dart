import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/gate_access_service.dart';
import '../../data/visitor_gate_models.dart';
import '../../data/visitor_gate_repository.dart';
import '../cubit/visitor_action_cubit.dart';
import '../cubit/visitor_home_cubit.dart';
import '../widgets/gate_widgets.dart';
import '../widgets/manual_code_sheet.dart';
import 'visitor_confirm_page.dart';
import 'visitor_invalid_page.dart';
import 'visitor_scan_page.dart';
import 'walk_in_form_page.dart';

class VisitorHomePage extends StatelessWidget {
  const VisitorHomePage({super.key, required this.access});

  final GateAccess access;

  static Future<void> open(BuildContext context, GateAccess access) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VisitorHomePage(access: access)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = VisitorGateRepository(getIt<Dio>());
    return RepositoryProvider.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => VisitorHomeCubit(repository)
              ..load()
              ..startAutoRefresh(),
          ),
          BlocProvider(create: (_) => VisitorActionCubit(repository)),
        ],
        child: _VisitorHomeView(access: access),
      ),
    );
  }
}

class _VisitorHomeView extends StatefulWidget {
  const _VisitorHomeView({required this.access});

  final GateAccess access;

  @override
  State<_VisitorHomeView> createState() => _VisitorHomeViewState();
}

class _VisitorHomeViewState extends State<_VisitorHomeView> {
  VisitorGateRepository get _repository =>
      context.read<VisitorGateRepository>();

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const VisitorScanPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    await context.read<VisitorActionCubit>().scan(code);
  }

  Future<void> _openManual() async {
    final code = await ManualCodeSheet.show(context);
    if (!mounted || code == null || code.trim().isEmpty) return;
    await context.read<VisitorActionCubit>().scan(code);
  }

  Future<void> _openWalkIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => WalkInFormPage(repository: _repository)),
    );
    if (mounted) await context.read<VisitorHomeCubit>().load(silent: true);
  }

  Future<void> _handleResult(VisitorScanResult result) async {
    context.read<VisitorActionCubit>().reset();
    String? next;
    if (result.action == VisitorScanAction.invalid) {
      next = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => VisitorInvalidPage(
            result: result,
            canWalkIn: widget.access.visitorCreate,
          ),
        ),
      );
    } else {
      next = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) =>
              VisitorConfirmPage(repository: _repository, result: result),
        ),
      );
    }
    if (!mounted) return;
    await context.read<VisitorHomeCubit>().load(silent: true);
    if (!mounted) return;
    switch (next) {
      case VisitorFlowAction.scan:
        await _openScanner();
        break;
      case VisitorFlowAction.manual:
        await _openManual();
        break;
      case VisitorFlowAction.walkIn:
        await _openWalkIn();
        break;
    }
  }

  void _openInside(VisitorGateItem item) {
    final result = VisitorScanResult(
      action: VisitorScanAction.checkOut,
      code: '',
      kind: item.source,
      visitId: item.id,
      name: item.name,
      visitorType: item.visitorType,
      guestCount: item.guestCount,
      unit: item.unit,
      schedule: item.schedule,
      checkInAt: item.checkInAt,
      plateNumber: item.plateNumber,
      durationMinutes: item.checkInAt == null
          ? null
          : DateTime.now().difference(item.checkInAt!).inMinutes,
      overdue: item.isOverdue(DateTime.now()),
    );
    _handleResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VisitorActionCubit, VisitorActionState>(
      listener: (context, state) {
        if (state.status == VisitorActionStatus.success &&
            state.result != null) {
          _handleResult(state.result!);
        } else if (state.status == VisitorActionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? 'Kode gagal diproses.')),
          );
          context.read<VisitorActionCubit>().reset();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: BlocBuilder<VisitorHomeCubit, VisitorHomeState>(
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  children: [
                    GateHeader(
                      title: 'Visitor',
                      subtitle: 'Kelola tamu masuk dan keluar',
                      child: _SummaryRow(summary: state.summary),
                    ),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
                BlocBuilder<VisitorActionCubit, VisitorActionState>(
                  builder: (context, action) {
                    if (!action.busy) return const SizedBox.shrink();
                    return Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: const GateCard(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Memeriksa kode...'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VisitorHomeState state) {
    if (state.forbidden) {
      return const GateStateView(
        icon: Icons.lock_outline,
        title: 'Tidak ada akses',
        message:
            'Akun Anda belum diberi akses Visitor. Hubungi admin residence.',
      );
    }
    final cubit = context.read<VisitorHomeCubit>();
    return RefreshIndicator(
      onRefresh: () => cubit.load(silent: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ScanCard(onTap: _openScanner),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GateButton(
                  label: 'Kode manual',
                  icon: Icons.keyboard_alt_outlined,
                  outlined: true,
                  onPressed: _openManual,
                ),
              ),
              if (widget.access.visitorCreate) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: GateButton(
                    label: 'Walk-In',
                    icon: Icons.person_add_alt_1_outlined,
                    outlined: true,
                    onPressed: _openWalkIn,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sedang di dalam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: neutral90,
                  ),
                ),
              ),
              Text(
                '${state.inside.length} tamu',
                style: TextStyle(fontSize: 12, color: neutral50),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.loading && state.inside.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null && state.inside.isEmpty)
            GateStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Data gagal dimuat',
              message: state.error,
              actionLabel: 'Coba lagi',
              onAction: cubit.load,
            )
          else if (state.inside.isEmpty)
            const GateStateView(
              icon: Icons.people_outline,
              title: 'Belum ada tamu di dalam',
              message: 'Tamu yang sudah masuk akan tampil di sini.',
            )
          else
            ...state.inside.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsideTile(
                  item: item,
                  canCheckOut: widget.access.visitorUpdate,
                  onTap: () => _openInside(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final VisitorSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(label: 'Akan datang', value: summary.expected),
        const SizedBox(width: 8),
        _SummaryTile(label: 'Di dalam', value: summary.inside),
        const SizedBox(width: 8),
        _SummaryTile(label: 'Sudah keluar', value: summary.out),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.qr_code_scanner,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan QR Visitor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Satu QR untuk masuk dan keluar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsideTile extends StatelessWidget {
  const _InsideTile({
    required this.item,
    required this.canCheckOut,
    required this.onTap,
  });

  final VisitorGateItem item;
  final bool canCheckOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue(DateTime.now());
    return GateCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: canCheckOut ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary10,
                child: Text(
                  item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
                  style: TextStyle(
                      color: primaryColor, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: neutral90,
                            ),
                          ),
                        ),
                        if (overdue) ...[
                          const SizedBox(width: 6),
                          GateChip(
                              label: 'Lewat batas', color: gateWarningColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        item.unit ?? '-',
                        if (item.visitorType != null) item.visitorType!,
                        '${item.guestCount} orang',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: neutral50),
                    ),
                    Text(
                      'Masuk ${GateFormat.time(item.checkInAt)}',
                      style: TextStyle(fontSize: 12, color: neutral50),
                    ),
                  ],
                ),
              ),
              if (canCheckOut)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Keluar',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: primaryColor),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
