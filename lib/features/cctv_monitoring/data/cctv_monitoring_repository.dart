import 'package:dio/dio.dart';

import '../../visitor_gate/data/gate_response.dart';
import 'cctv_monitoring_models.dart';

class CctvMonitoringRepository {
  CctvMonitoringRepository(this._dio);

  final Dio _dio;

  static const String _base = '/admin/cctv';

  Map<String, dynamic> _paging(List<Map<String, String>> filters,
          {int length = 50}) =>
      {
        'Filter': filters,
        'Sort': {'Field': 'default', 'Type': 0},
        'Start': 1,
        'Length': length,
      };

  Future<CctvSummaryInfo> summary() async {
    final body = await GateResponse.run(() => _dio.get('$_base/summary'));
    return CctvSummaryInfo.fromJson(GateJson.object(body, 'Data'));
  }

  Future<List<CctvCameraItem>> cameras() async {
    final body = await GateResponse.run(
      () => _dio.post(
        '$_base/monitoring/cameras',
        data: _paging([
          {'Field': 'viewer', 'Search': 'me'},
        ], length: 500),
      ),
    );
    return GateJson.list(body, 'List')
        .map(CctvCameraItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<CctvEmergencyItem>> pendingEmergencies() async {
    final body = await GateResponse.run(
      () => _dio.post(
        '$_base/emergency-calls/list',
        data: _paging([
          {'Field': 'status', 'Search': 'PENDING'},
        ], length: 20),
      ),
    );
    return GateJson.list(body, 'List')
        .map(CctvEmergencyItem.fromJson)
        .where((item) => item.code.isNotEmpty)
        .toList();
  }

  Future<void> acceptEmergency(String code, String officerUserId) async {
    await GateResponse.run(
      () => _dio.put(
        '$_base/emergency-calls/$code/accept',
        data: {'OfficerUserId': officerUserId},
      ),
    );
  }

  Future<List<CctvEventItem>> cameraEvents(String cameraId) async {
    final body = await GateResponse.run(
      () => _dio.post(
        '$_base/events/list',
        data: _paging([
          {'Field': 'cameraid', 'Search': cameraId},
        ], length: 20),
      ),
    );
    return GateJson.list(body, 'List').map(CctvEventItem.fromJson).toList();
  }

  Future<CctvStreamSession> startStream(
    String cameraId, {
    bool sd = false,
    DateTime? startAt,
  }) async {
    final body = await GateResponse.run(
      () => _dio.post(
        '$_base/cameras/$cameraId/stream-sessions',
        data: {
          'Quality': sd ? 'SD' : 'HD',
          if (startAt != null) 'StartAt': startAt.toIso8601String(),
        },
      ),
    );
    final session = CctvStreamSession.fromJson(GateJson.object(body, 'Data'));
    if (session.url.isEmpty) {
      throw const GateApiException('Tautan tayangan tidak tersedia.');
    }
    return session;
  }

  Future<void> endStream(String sessionId) async {
    if (sessionId.isEmpty) return;
    try {
      await _dio.delete('$_base/stream-sessions/$sessionId');
    } on DioException {
      return;
    }
  }

  Future<String> snapshot(String cameraId) async {
    final body = await GateResponse.run(
      () => _dio.post('$_base/cameras/$cameraId/snapshots'),
    );
    final url = GateJson.text(body, 'Data');
    if (url == null) throw const GateApiException('Foto gagal diambil.');
    return url;
  }
}
