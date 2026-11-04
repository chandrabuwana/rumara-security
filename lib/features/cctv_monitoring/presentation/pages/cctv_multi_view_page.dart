import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/colors.dart';
import '../../../visitor_gate/presentation/widgets/gate_widgets.dart';
import '../../data/cctv_monitoring_models.dart';
import '../../data/cctv_monitoring_repository.dart';
import '../widgets/cctv_player.dart';
import 'cctv_live_page.dart';

class CctvMultiViewPage extends StatefulWidget {
  const CctvMultiViewPage({
    super.key,
    required this.repository,
    required this.cameras,
    required this.canHandle,
  });

  final CctvMonitoringRepository repository;
  final List<CctvCameraItem> cameras;
  final bool canHandle;

  @override
  State<CctvMultiViewPage> createState() => _CctvMultiViewPageState();
}

class _MultiViewPage {
  const _MultiViewPage(this.title, this.cameras);

  final String title;
  final List<CctvCameraItem> cameras;
}

class _CctvMultiViewPageState extends State<CctvMultiViewPage> {
  late final List<_MultiViewPage> _pages = _buildPages();
  final PageController _controller = PageController();
  int _index = 0;
  bool _muted = true;
  bool _immersive = false;

  List<_MultiViewPage> _buildPages() {
    final groups = <String, List<CctvCameraItem>>{};
    for (final camera in widget.cameras) {
      groups.putIfAbsent(camera.groupLabel ?? 'Lainnya', () => []).add(camera);
    }
    final pages = <_MultiViewPage>[];
    groups.forEach((title, cameras) {
      for (var start = 0; start < cameras.length; start += 4) {
        final end = start + 4 > cameras.length ? cameras.length : start + 4;
        final suffix = cameras.length > 4 ? ' (${start ~/ 4 + 1})' : '';
        pages.add(_MultiViewPage('$title$suffix', cameras.sublist(start, end)));
      }
    });
    return pages;
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_immersive)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _open(CctvCameraItem camera) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvLivePage(
          repository: widget.repository,
          camera: camera,
          canHandle: widget.canHandle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _pages.isEmpty ? 'Multi-View Pos' : _pages[_index].title;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!_immersive)
            GateHeader(
              title: 'Multi-View Pos',
              subtitle: title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _muted ? 'Aktifkan suara' : 'Senyapkan semua',
                    onPressed: () => setState(() => _muted = !_muted),
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Layar penuh',
                    onPressed: _toggleImmersive,
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _pages.isEmpty
                ? const GateStateView(
                    icon: Icons.videocam_off_outlined,
                    title: 'Belum ada kamera',
                  )
                : PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return GridView.builder(
                        padding: const EdgeInsets.all(4),
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: _immersive ? 16 / 9 : 4 / 3,
                        ),
                        itemCount: page.cameras.length,
                        itemBuilder: (context, cell) {
                          final camera = page.cameras[cell];
                          return GestureDetector(
                            onTap: () => _open(camera),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CctvPlayer(
                                  repository: widget.repository,
                                  camera: camera,
                                  sd: true,
                                  muted: _muted,
                                  compact: true,
                                ),
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  right: 6,
                                  child: Text(
                                    camera.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      shadows: [Shadow(blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_pages.length > 1)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      width: index == _index ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _index ? primaryAccent : Colors.white38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_immersive)
            SafeArea(
              top: false,
              child: TextButton.icon(
                onPressed: _toggleImmersive,
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                label: const Text('Keluar layar penuh',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
