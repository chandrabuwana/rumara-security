import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/colors.dart';
import '../../../laporan_kejadian/presentation/pages/incident_report_form_page.dart';
import '../../../visitor_gate/presentation/widgets/gate_widgets.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';
import '../cubit/cctv_live_cubit.dart';
import '../widgets/cctv_player.dart';

class CctvLivePage extends StatelessWidget {
  const CctvLivePage({
    super.key,
    required this.repository,
    required this.camera,
    required this.canHandle,
    this.emergency,
  });

  final CctvMonitoringRepository repository;
  final CctvCameraItem camera;
  final CctvEmergencyItem? emergency;
  final bool canHandle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CctvLiveCubit(repository, camera, emergency: emergency)..loadEvents(),
      child: _CctvLiveView(
          repository: repository, camera: camera, canHandle: canHandle),
    );
  }
}

class _CctvLiveView extends StatefulWidget {
  const _CctvLiveView({
    required this.repository,
    required this.camera,
    required this.canHandle,
  });

  final CctvMonitoringRepository repository;
  final CctvCameraItem camera;
  final bool canHandle;

  @override
  State<_CctvLiveView> createState() => _CctvLiveViewState();
}

class _CctvLiveViewState extends State<_CctvLiveView> {
  bool _sd = false;
  bool _muted = true;
  DateTime? _playbackAt;

  Future<void> _fullscreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvFullscreenPage(
          repository: widget.repository,
          camera: widget.camera,
          sd: _sd,
          startAt: _playbackAt,
        ),
      ),
    );
  }

  Future<void> _report() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => IncidentReportFormPage.wrapped(null)),
    );
  }

  void _showSnapshot(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Foto tersimpan, pratinjau belum tersedia.'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Foto tersimpan di rekaman kamera.')),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    return BlocConsumer<CctvLiveCubit, CctvLiveState>(
      listenWhen: (previous, current) =>
          previous.snapshotUrl != current.snapshotUrl ||
          previous.message != current.message,
      listener: (context, state) {
        final url = state.snapshotUrl;
        if (url != null) _showSnapshot(url);
        if (state.message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        final cubit = context.read<CctvLiveCubit>();
        final emergency = state.emergency;
        return Scaffold(
          backgroundColor: bgColor,
          body: Column(
            children: [
              GateHeader(
                title: camera.name,
                subtitle: [camera.location, camera.groupLabel]
                    .whereType<String>()
                    .join(' · '),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CctvPlayer(
                      repository: widget.repository,
                      camera: camera,
                      sd: _sd,
                      muted: _muted,
                      startAt: _playbackAt,
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Row(
                        children: [
                          _Badge(
                            label: _playbackAt == null ? 'LIVE' : 'REKAMAN',
                            color:
                                _playbackAt == null ? errorColor : primaryColor,
                          ),
                          const SizedBox(width: 6),
                          _Badge(
                              label: _sd ? 'SD' : 'HD', color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GateCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Control(
                            icon: Icons.photo_camera_outlined,
                            label: 'Foto',
                            busy: state.snapshotting,
                            onTap: camera.capSnapshot && camera.isOnline
                                ? cubit.snapshot
                                : null,
                          ),
                          _Control(
                            icon: _sd ? Icons.hd_outlined : Icons.sd_outlined,
                            label: _sd ? 'Mode HD' : 'Mode SD',
                            onTap: () => setState(() => _sd = !_sd),
                          ),
                          if (camera.capAudio)
                            _Control(
                              icon: _muted
                                  ? Icons.volume_off_outlined
                                  : Icons.volume_up_outlined,
                              label: _muted ? 'Suara' : 'Senyap',
                              onTap: () => setState(() => _muted = !_muted),
                            ),
                          if (_playbackAt != null)
                            _Control(
                              icon: Icons.live_tv_outlined,
                              label: 'Ke live',
                              onTap: () => setState(() => _playbackAt = null),
                            ),
                          _Control(
                            icon: Icons.fullscreen,
                            label: 'Layar penuh',
                            onTap: _fullscreen,
                          ),
                        ],
                      ),
                    ),
                    if (emergency != null) ...[
                      const SizedBox(height: 12),
                      GateBanner(
                        icon: Icons.sos,
                        title: state.handled
                            ? 'Panggilan sudah ditangani'
                            : 'Panggilan darurat aktif',
                        message: [
                          if (emergency.unitNumber != null)
                            'Unit ${emergency.unitNumber}',
                          if (emergency.reporterName != null)
                            emergency.reporterName!,
                          'Pukul ${GateFormat.time(emergency.dispatchedAt)}',
                        ].join(' · '),
                        color: state.handled ? successColor : errorColor,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Kejadian di kamera ini',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: neutral90,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.eventsLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Belum ada kejadian tercatat.',
                          style: TextStyle(color: neutral50),
                        ),
                      )
                    else
                      ...state.events.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GateCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.motion_photos_on_outlined,
                                    color: gateWarningColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.typeLabel ?? 'Kejadian',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: neutral90,
                                        ),
                                      ),
                                      Text(
                                        GateFormat.dateTime(event.occurredAt),
                                        style: TextStyle(
                                            fontSize: 12, color: neutral50),
                                      ),
                                    ],
                                  ),
                                ),
                                if (camera.capPlayback &&
                                    event.occurredAt != null)
                                  TextButton.icon(
                                    onPressed: () => setState(
                                      () => _playbackAt =
                                          event.occurredAt!.subtract(
                                        const Duration(seconds: 10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Putar'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (emergency != null &&
                          widget.canHandle &&
                          !state.handled) ...[
                        Expanded(
                          child: GateButton(
                            label: 'Tandai ditangani',
                            tone: GateButtonTone.danger,
                            loading: state.handling,
                            onPressed: cubit.handleEmergency,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: GateButton(
                          label: 'Laporan Kejadian',
                          icon: Icons.report_outlined,
                          outlined: emergency != null &&
                              widget.canHandle &&
                              !state.handled,
                          onPressed: _report,
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
}

class CctvFullscreenPage extends StatefulWidget {
  const CctvFullscreenPage({
    super.key,
    required this.repository,
    required this.camera,
    this.sd = false,
    this.startAt,
  });

  final CctvMonitoringRepository repository;
  final CctvCameraItem camera;
  final bool sd;
  final DateTime? startAt;

  @override
  State<CctvFullscreenPage> createState() => _CctvFullscreenPageState();
}

class _CctvFullscreenPageState extends State<CctvFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CctvPlayer(
            repository: widget.repository,
            camera: widget.camera,
            sd: widget.sd,
            startAt: widget.startAt,
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Positioned(
            top: 28,
            left: 64,
            child: Text(
              widget.camera.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final color = enabled ? primaryColor : neutral30;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor),
                  )
                : Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
