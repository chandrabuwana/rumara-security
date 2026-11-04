import '../../visitor_gate/data/gate_response.dart';

class CctvCameraItem {
  const CctvCameraItem({
    required this.id,
    required this.name,
    this.code,
    this.location,
    this.groupLabel,
    this.status,
    this.lastSeenAt,
    this.thumbnailUrl,
    this.capLive = false,
    this.capSnapshot = false,
    this.capPlayback = false,
    this.capAudio = false,
  });

  factory CctvCameraItem.fromJson(Map<String, dynamic> json) {
    return CctvCameraItem(
      id: GateJson.text(json, 'Id') ?? '',
      name: GateJson.text(json, 'Name') ?? '-',
      code: GateJson.text(json, 'Code'),
      location: GateJson.text(json, 'LocationLabel'),
      groupLabel: GateJson.text(json, 'GroupLabel'),
      status: GateJson.text(json, 'Status'),
      lastSeenAt: GateJson.date(json, 'LastSeenAt'),
      thumbnailUrl: GateJson.text(json, 'ThumbnailUrl'),
      capLive: GateJson.flag(json, 'CapLive'),
      capSnapshot: GateJson.flag(json, 'CapSnapshot'),
      capPlayback: GateJson.flag(json, 'CapPlayback'),
      capAudio: GateJson.flag(json, 'CapAudio'),
    );
  }

  final String id;
  final String name;
  final String? code;
  final String? location;
  final String? groupLabel;
  final String? status;
  final DateTime? lastSeenAt;
  final String? thumbnailUrl;
  final bool capLive;
  final bool capSnapshot;
  final bool capPlayback;
  final bool capAudio;

  bool get isOnline => (status ?? '').toUpperCase() == 'ONLINE';
}

class CctvEventItem {
  const CctvEventItem({
    required this.code,
    required this.cameraId,
    this.type,
    this.typeLabel,
    this.cameraName,
    this.location,
    this.occurredAt,
    this.thumbnailUrl,
  });

  factory CctvEventItem.fromJson(Map<String, dynamic> json) {
    return CctvEventItem(
      code: GateJson.text(json, 'Code') ?? '',
      cameraId: GateJson.text(json, 'CameraId') ?? '',
      type: GateJson.text(json, 'Type'),
      typeLabel: GateJson.text(json, 'TypeLabel'),
      cameraName: GateJson.text(json, 'CameraName'),
      location: GateJson.text(json, 'LocationLabel'),
      occurredAt: GateJson.date(json, 'OccurredAt'),
      thumbnailUrl: GateJson.text(json, 'ThumbnailUrl'),
    );
  }

  final String code;
  final String cameraId;
  final String? type;
  final String? typeLabel;
  final String? cameraName;
  final String? location;
  final DateTime? occurredAt;
  final String? thumbnailUrl;

  bool get isDetection => (type ?? '').toUpperCase() != 'CAMERA_OFFLINE';
}

class CctvSummaryInfo {
  const CctvSummaryInfo({
    this.total = 0,
    this.online = 0,
    this.offline = 0,
    this.pendingEmergencies = 0,
    this.eventsToday = 0,
    this.recentEvents = const [],
  });

  factory CctvSummaryInfo.fromJson(Map<String, dynamic>? json) {
    return CctvSummaryInfo(
      total: GateJson.integer(json, 'TotalCameras'),
      online: GateJson.integer(json, 'OnlineCameras'),
      offline: GateJson.integer(json, 'OfflineCameras'),
      pendingEmergencies: GateJson.integer(json, 'PendingEmergencies'),
      eventsToday: GateJson.integer(json, 'EventsToday'),
      recentEvents: GateJson.list(json, 'RecentEvents')
          .map(CctvEventItem.fromJson)
          .toList(),
    );
  }

  final int total;
  final int online;
  final int offline;
  final int pendingEmergencies;
  final int eventsToday;
  final List<CctvEventItem> recentEvents;
}

class CctvEmergencyItem {
  const CctvEmergencyItem({
    required this.code,
    this.cameraId,
    this.cameraName,
    this.location,
    this.unitNumber,
    this.reporterName,
    this.reporterPhone,
    this.category,
    this.dispatchedAt,
    this.thumbnailUrl,
  });

  factory CctvEmergencyItem.fromJson(Map<String, dynamic> json) {
    return CctvEmergencyItem(
      code: GateJson.text(json, 'Code') ?? '',
      cameraId: GateJson.text(json, 'CameraId'),
      cameraName: GateJson.text(json, 'CameraName'),
      location: GateJson.text(json, 'LocationLabel'),
      unitNumber: GateJson.text(json, 'UnitNumber'),
      reporterName: GateJson.text(json, 'ReporterName'),
      reporterPhone: GateJson.text(json, 'ReporterPhone'),
      category: GateJson.text(json, 'ReportCategory'),
      dispatchedAt: GateJson.date(json, 'DispatchedAt'),
      thumbnailUrl: GateJson.text(json, 'ThumbnailUrl'),
    );
  }

  final String code;
  final String? cameraId;
  final String? cameraName;
  final String? location;
  final String? unitNumber;
  final String? reporterName;
  final String? reporterPhone;
  final String? category;
  final DateTime? dispatchedAt;
  final String? thumbnailUrl;
}

class CctvStreamSession {
  const CctvStreamSession({
    required this.sessionId,
    required this.url,
    this.expiresAt,
  });

  factory CctvStreamSession.fromJson(Map<String, dynamic>? json) {
    return CctvStreamSession(
      sessionId: GateJson.text(json, 'SessionId') ?? '',
      url: GateJson.text(json, 'Url') ?? '',
      expiresAt: GateJson.date(json, 'ExpiresAt'),
    );
  }

  final String sessionId;
  final String url;
  final DateTime? expiresAt;
}
