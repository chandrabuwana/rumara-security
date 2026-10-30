import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/di/injection.dart';
import '../../../visitor_gate/data/gate_access_service.dart';
import '../../../visitor_gate/presentation/widgets/gate_widgets.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';
import '../cubit/cctv_monitoring_cubit.dart';
import 'cctv_live_page.dart';
import 'cctv_multi_view_page.dart';

class CctvMonitoringPage extends StatelessWidget {
  const CctvMonitoringPage({super.key, required this.access});

  final GateAccess access;

  static Future<void> open(BuildContext context, GateAccess access) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CctvMonitoringPage(access: access)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = CctvMonitoringRepository(getIt<Dio>());
    return RepositoryProvider.value(
      value: repository,
      child: BlocProvider(
        create: (_) => CctvMonitoringCubit(repository)
          ..load()
          ..startAutoRefresh(),
        child: _CctvMonitoringView(access: access),
      ),
    );
  }
}

class _CctvMonitoringView extends StatelessWidget {
  const _CctvMonitoringView({required this.access});

  final GateAccess access;

  Future<void> _openCamera(
    BuildContext context,
    CctvCameraItem camera, {
    CctvEmergencyItem? emergency,
  }) async {
    final repository = context.read<CctvMonitoringRepository>();
    final cubit = context.read<CctvMonitoringCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvLivePage(
          repository: repository,
          camera: camera,
          emergency: emergency,
          canHandle: access.cctvUpdate,
        ),
      ),
    );
    await cubit.load(silent: true);
  }

  Future<void> _openMultiView(
      BuildContext context, CctvMonitoringState state) async {
    final repository = context.read<CctvMonitoringRepository>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvMultiViewPage(
          repository: repository,
          cameras: state.cameras,
          canHandle: access.cctvUpdate,
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, CctvEmergencyItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<CctvMonitoringCubit>().accept(item.code);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Panggilan darurat ditandai ditangani.')),
    );
  }

  CctvCameraItem? _cameraOf(CctvMonitoringState state, String? id) {
    if (id == null) return null;
    for (final camera in state.cameras) {
      if (camera.id == id) return camera;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CctvMonitoringCubit, CctvMonitoringState>(
      builder: (context, state) {
        final warnings =
            state.emergencies.length + state.recentDetections.length;
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              GateHeader(
                title: 'CCTV Monitoring',
                subtitle: '${state.cameras.length} kamera area umum',
                trailing: IconButton(
                  tooltip: 'Multi-View Pos',
                  onPressed: state.cameras.isEmpty
                      ? null
                      : () => _openMultiView(context, state),
                  icon:
                      const Icon(Icons.grid_view_rounded, color: Colors.white),
                ),
                child: Row(
                  children: [
                    _HeaderStat(
                        label: 'Online',
                        value: state.onlineCount,
                        color: successColor),
                    const SizedBox(width: 8),
                    _HeaderStat(
                        label: 'Offline',
                        value: state.offlineCount,
                        color: errorColor),
                    const SizedBox(width: 8),
                    _HeaderStat(
                        label: 'Peringatan',
                        value: warnings,
                        color: gateWarningColor),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CctvMonitoringState state) {
    final cubit = context.read<CctvMonitoringCubit>();
    if (state.forbidden) {
      return const GateStateView(
        icon: Icons.lock_outline,
        title: 'Tidak ada akses kamera',
        message:
            'Akun Anda belum diberi akses CCTV Monitoring. Hubungi admin residence.',
      );
    }
    if (state.loading && state.cameras.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.cameras.isEmpty) {
      return GateStateView(
        icon: Icons.cloud_off_outlined,
        title: 'Kamera gagal dimuat',
        message: state.error,
        actionLabel: 'Coba lagi',
        onAction: cubit.load,
      );
    }
    final cameras = state.visibleCameras;
    return RefreshIndicator(
      onRefresh: () => cubit.load(silent: true),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ...state.emergencies.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EmergencyCard(
                      item: item,
                      accepting: state.accepting == item.code,
                      canHandle: access.cctvUpdate,
                      onView: _cameraOf(state, item.cameraId) == null
                          ? null
                          : () => _openCamera(
                                context,
                                _cameraOf(state, item.cameraId)!,
                                emergency: item,
                              ),
                      onHandle: () => _accept(context, item),
                    ),
                  ),
                ),
                ...state.recentDetections.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetectionCard(
                      event: event,
                      onTap: _cameraOf(state, event.cameraId) == null
                          ? null
                          : () => _openCamera(
                              context, _cameraOf(state, event.cameraId)!),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua (${state.cameras.length})',
                        selected: state.filter == CctvMonitoringState.all,
                        onTap: () => cubit.setFilter(CctvMonitoringState.all),
                      ),
                      ...state.groups.map(
                        (group) => _FilterChip(
                          label:
                              '$group (${state.cameras.where((camera) => camera.groupLabel == group).length})',
                          selected: state.filter == group,
                          onTap: () => cubit.setFilter(group),
                        ),
                      ),
                      _FilterChip(
                        label: 'Offline (${state.offlineCount})',
                        selected: state.filter == CctvMonitoringState.offline,
                        onTap: () =>
                            cubit.setFilter(CctvMonitoringState.offline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (cameras.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: GateStateView(
                icon: Icons.videocam_off_outlined,
                title: 'Belum ada kamera',
                message:
                    'Kamera area umum yang diatur di Web Admin akan tampil di sini.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final camera = cameras[index];
                    return _CameraTile(
                      camera: camera,
                      motion: state.hasMotion(camera.id),
                      onTap: () => _openCamera(context, camera),
                    );
                  },
                  childCount: cameras.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.item,
    required this.accepting,
    required this.canHandle,
    required this.onView,
    required this.onHandle,
  });

  final CctvEmergencyItem item;
  final bool accepting;
  final bool canHandle;
  final VoidCallback? onView;
  final VoidCallback onHandle;

  @override
  Widget build(BuildContext context) {
    final color = errorColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sos, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Panggilan darurat',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                GateFormat.time(item.dispatchedAt),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (item.unitNumber != null) 'Unit ${item.unitNumber}',
              if (item.reporterName != null) item.reporterName!,
              if (item.category != null) item.category!,
            ].join(' · '),
            style: TextStyle(fontWeight: FontWeight.w600, color: neutral90),
          ),
          if (item.cameraName != null || item.location != null)
            Text(
              'Kamera terdekat: ${item.cameraName ?? item.location}',
              style: TextStyle(fontSize: 12, color: neutral70),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onView != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Lihat kamera'),
                    style: OutlinedButton.styleFrom(foregroundColor: color),
                  ),
                ),
              if (onView != null && canHandle) const SizedBox(width: 8),
              if (canHandle)
                Expanded(
                  child: ElevatedButton(
                    onPressed: accepting ? null : onHandle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: accepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Tandai ditangani'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({required this.event, required this.onTap});

  final CctvEventItem event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = gateWarningColor;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.motion_photos_on_outlined, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.typeLabel ?? 'Deteksi kejadian',
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      event.cameraName ?? event.location ?? '-',
                      style: TextStyle(fontSize: 12, color: neutral70),
                    ),
                  ],
                ),
              ),
              Text(
                GateFormat.time(event.occurredAt),
                style: TextStyle(fontSize: 12, color: neutral70),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: neutral50),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: primaryColor,
        labelStyle: TextStyle(
          color: selected ? Colors.white : neutral90,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        showCheckmark: false,
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile(
      {required this.camera, required this.motion, required this.onTap});

  final CctvCameraItem camera;
  final bool motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = camera.thumbnailUrl;
    final online = camera.isOnline;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: motion ? Border.all(color: gateWarningColor, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: neutral90,
                    child: thumbnail == null
                        ? const Icon(Icons.videocam_outlined,
                            color: Colors.white54, size: 32)
                        : Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            color: online
                                ? null
                                : Colors.black.withValues(alpha: 0.5),
                            colorBlendMode: online ? null : BlendMode.darken,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.videocam_outlined,
                              color: Colors.white54,
                              size: 32,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: online ? errorColor : neutral70,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        online ? 'LIVE' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: neutral90,
                    ),
                  ),
                  Text(
                    online
                        ? (camera.location ?? camera.groupLabel ?? '-')
                        : 'Terakhir ${GateFormat.time(camera.lastSeenAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: neutral50),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
