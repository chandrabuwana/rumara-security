import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../visitor_gate/data/gate_response.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';

class CctvPlayer extends StatefulWidget {
  const CctvPlayer({
    super.key,
    required this.repository,
    required this.camera,
    this.sd = false,
    this.muted = true,
    this.startAt,
    this.compact = false,
  });

  final CctvMonitoringRepository repository;
  final CctvCameraItem camera;
  final bool sd;
  final bool muted;
  final DateTime? startAt;
  final bool compact;

  @override
  State<CctvPlayer> createState() => _CctvPlayerState();
}

class _CctvPlayerState extends State<CctvPlayer> {
  VideoPlayerController? _controller;
  CctvStreamSession? _session;
  Timer? _renew;
  String? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_start);
  }

  @override
  void didUpdateWidget(covariant CctvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.id != widget.camera.id ||
        oldWidget.sd != widget.sd ||
        oldWidget.startAt != widget.startAt) {
      _start();
    } else if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _start() async {
    if (!mounted) return;
    final generation = ++_generation;
    _renew?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!widget.camera.isOnline && widget.startAt == null) {
      setState(() {
        _loading = false;
        _error = 'Kamera sedang offline';
      });
      return;
    }
    try {
      final session = await widget.repository.startStream(
        widget.camera.id,
        sd: widget.sd,
        startAt: widget.startAt,
      );
      if (!mounted || generation != _generation) {
        unawaited(widget.repository.endStream(session.sessionId));
        return;
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(session.url),
        formatHint: VideoFormat.hls,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        unawaited(widget.repository.endStream(session.sessionId));
        return;
      }
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      controller.addListener(_onPlayerChanged);
      final previous = _controller;
      final previousSession = _session;
      setState(() {
        _controller = controller;
        _session = session;
        _loading = false;
      });
      previous?.removeListener(_onPlayerChanged);
      await previous?.dispose();
      if (previousSession != null) {
        unawaited(widget.repository.endStream(previousSession.sessionId));
      }
      _scheduleRenew(session);
    } on GateApiException catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Tayangan gagal dimuat. Sinyal mungkin lemah.';
        });
      }
    }
  }

  void _scheduleRenew(CctvStreamSession session) {
    final expiresAt = session.expiresAt;
    if (widget.startAt != null || expiresAt == null) return;
    final wait =
        expiresAt.difference(DateTime.now()) - const Duration(seconds: 20);
    if (wait.inSeconds < 10) return;
    _renew = Timer(wait, () {
      if (mounted) _start();
    });
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.value.hasError && _error == null) {
      setState(() => _error = 'Tayangan terputus.');
    }
  }

  @override
  void dispose() {
    _generation++;
    _renew?.cancel();
    final controller = _controller;
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    final session = _session;
    if (session != null)
      unawaited(widget.repository.endStream(session.sessionId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final thumbnail = widget.camera.thumbnailUrl;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null &&
              controller.value.isInitialized &&
              _error == null)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else if (thumbnail != null)
            Opacity(
              opacity: 0.45,
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white,
                      size: widget.compact ? 24 : 36,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 11 : 13,
                      ),
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _start,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
