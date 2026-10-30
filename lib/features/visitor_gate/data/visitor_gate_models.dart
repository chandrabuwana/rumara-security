import 'gate_response.dart';

enum VisitorScanAction { checkIn, checkOut, invalid }

class VisitorTimelineEntry {
  const VisitorTimelineEntry({
    required this.event,
    this.at,
    this.by,
    this.note,
  });

  factory VisitorTimelineEntry.fromJson(Map<String, dynamic> json) {
    return VisitorTimelineEntry(
      event: GateJson.text(json, 'Event') ?? '',
      at: GateJson.date(json, 'At'),
      by: GateJson.text(json, 'By'),
      note: GateJson.text(json, 'Note'),
    );
  }

  final String event;
  final DateTime? at;
  final String? by;
  final String? note;

  String get label {
    switch (event.toUpperCase()) {
      case 'CHECK_IN':
        return 'Masuk';
      case 'OVERRIDE_CHECK_IN':
        return 'Masuk (manual)';
      case 'CHECK_OUT':
        return 'Keluar';
      case 'OVERRIDE_CHECK_OUT':
        return 'Keluar (manual)';
      case 'AUTO_CHECK_OUT':
        return 'Keluar otomatis';
      case 'WALKIN_REQUESTED':
        return 'Permintaan dikirim ke penghuni';
      case 'WALKIN_APPROVED':
        return 'Disetujui penghuni';
      case 'WALKIN_REJECTED':
        return 'Ditolak penghuni';
      case 'WALKIN_EXPIRED':
        return 'Permintaan kedaluwarsa';
      case 'OVERRIDE_DECISION':
        return 'Keputusan petugas';
      default:
        return event.replaceAll('_', ' ').toLowerCase();
    }
  }
}

List<VisitorTimelineEntry> _timeline(Map<String, dynamic> json) =>
    GateJson.list(json, 'Timeline').map(VisitorTimelineEntry.fromJson).toList();

class VisitorScanResult {
  const VisitorScanResult({
    required this.action,
    required this.code,
    this.reason,
    this.kind,
    this.referenceId,
    this.visitId,
    this.name,
    this.visitorType,
    this.phone,
    this.guestCount = 1,
    this.unit,
    this.schedule,
    this.validFrom,
    this.validUntil,
    this.vehicleType,
    this.plateNumber,
    this.securityNote,
    this.invitedBy,
    this.residentPhone,
    this.checkInAt,
    this.durationMinutes,
    this.entryGate,
    this.verifiedBy,
    this.overdue = false,
    this.timeline = const [],
  });

  factory VisitorScanResult.fromJson(Map<String, dynamic> json, String code) {
    final action = (GateJson.text(json, 'Action') ?? '').toUpperCase();
    return VisitorScanResult(
      action: switch (action) {
        'CHECK_IN' => VisitorScanAction.checkIn,
        'CHECK_OUT' => VisitorScanAction.checkOut,
        _ => VisitorScanAction.invalid,
      },
      code: GateJson.text(json, 'Code') ?? code,
      reason: GateJson.text(json, 'Reason'),
      kind: GateJson.text(json, 'Kind'),
      referenceId: GateJson.text(json, 'ReferenceId'),
      visitId: GateJson.text(json, 'VisitId'),
      name: GateJson.text(json, 'Name'),
      visitorType: GateJson.text(json, 'VisitorType'),
      phone: GateJson.text(json, 'Phone'),
      guestCount: GateJson.integer(json, 'GuestCount', fallback: 1),
      unit: GateJson.text(json, 'Unit'),
      schedule: GateJson.text(json, 'Schedule'),
      validFrom: GateJson.date(json, 'ValidFrom'),
      validUntil: GateJson.date(json, 'ValidUntil'),
      vehicleType: GateJson.text(json, 'VehicleType'),
      plateNumber: GateJson.text(json, 'PlateNumber'),
      securityNote: GateJson.text(json, 'SecurityNote'),
      invitedBy: GateJson.text(json, 'InvitedBy'),
      residentPhone: GateJson.text(json, 'ResidentPhone'),
      checkInAt: GateJson.date(json, 'CheckInAt'),
      durationMinutes: GateJson.integerOrNull(json, 'DurationMinutes'),
      entryGate: GateJson.text(json, 'EntryGate'),
      verifiedBy: GateJson.text(json, 'VerifiedBy'),
      overdue: GateJson.flag(json, 'Overdue'),
      timeline: _timeline(json),
    );
  }

  final VisitorScanAction action;
  final String code;
  final String? reason;
  final String? kind;
  final String? referenceId;
  final String? visitId;
  final String? name;
  final String? visitorType;
  final String? phone;
  final int guestCount;
  final String? unit;
  final String? schedule;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? vehicleType;
  final String? plateNumber;
  final String? securityNote;
  final String? invitedBy;
  final String? residentPhone;
  final DateTime? checkInAt;
  final int? durationMinutes;
  final String? entryGate;
  final String? verifiedBy;
  final bool overdue;
  final List<VisitorTimelineEntry> timeline;

  String get kindLabel {
    switch ((kind ?? '').toUpperCase()) {
      case 'INVITATION':
        return 'Undangan';
      case 'RECURRING':
        return 'Akses rutin';
      case 'DELIVERY':
        return 'Delivery';
      case 'WALKIN':
        return 'Walk-in';
      default:
        return 'Kunjungan';
    }
  }
}

class VisitorSummary {
  const VisitorSummary({
    this.expected = 0,
    this.inside = 0,
    this.out = 0,
    this.pending = 0,
  });

  factory VisitorSummary.fromJson(Map<String, dynamic>? json) {
    return VisitorSummary(
      expected: GateJson.integer(json, 'ExpectedToday'),
      inside: GateJson.integer(json, 'Inside'),
      out: GateJson.integer(json, 'OutToday'),
      pending: GateJson.integer(json, 'Pending'),
    );
  }

  final int expected;
  final int inside;
  final int out;
  final int pending;
}

class VisitorGateItem {
  const VisitorGateItem({
    required this.id,
    required this.name,
    this.kind,
    this.visitorType,
    this.unit,
    this.schedule,
    this.status,
    this.source,
    this.checkInAt,
    this.guestCount = 1,
    this.plateNumber,
  });

  factory VisitorGateItem.fromJson(Map<String, dynamic> json) {
    return VisitorGateItem(
      id: GateJson.text(json, 'Id') ?? '',
      name: GateJson.text(json, 'VisitorName') ?? '-',
      kind: GateJson.text(json, 'Kind'),
      visitorType: GateJson.text(json, 'VisitorType'),
      unit: GateJson.text(json, 'Unit'),
      schedule: GateJson.text(json, 'Schedule'),
      status: GateJson.text(json, 'Status'),
      source: GateJson.text(json, 'Source'),
      checkInAt: GateJson.date(json, 'CheckInAt'),
      guestCount: GateJson.integer(json, 'GuestCount', fallback: 1),
      plateNumber: GateJson.text(json, 'PlateNumber'),
    );
  }

  final String id;
  final String name;
  final String? kind;
  final String? visitorType;
  final String? unit;
  final String? schedule;
  final String? status;
  final String? source;
  final DateTime? checkInAt;
  final int guestCount;
  final String? plateNumber;

  bool isOverdue(DateTime now) {
    final checkIn = checkInAt;
    final range = schedule;
    if (checkIn == null || range == null || !range.contains('-')) return false;
    final parts = range.split('-').last.trim().split(':');
    if (parts.length < 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    final end =
        DateTime(checkIn.year, checkIn.month, checkIn.day, hour, minute);
    return now.isAfter(end);
  }
}

class VisitorVisitRecord {
  const VisitorVisitRecord({
    required this.visitId,
    this.name,
    this.unit,
    this.status,
    this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
    this.guestCount = 1,
    this.verifiedBy,
    this.timeline = const [],
  });

  factory VisitorVisitRecord.fromJson(Map<String, dynamic>? json) {
    final guest = GateJson.object(json, 'Guest');
    return VisitorVisitRecord(
      visitId: GateJson.text(json, 'VisitId') ?? '',
      name: GateJson.text(guest, 'Name'),
      unit: GateJson.text(json, 'Unit'),
      status: GateJson.text(json, 'Status'),
      checkInAt: GateJson.date(json, 'CheckInAt'),
      checkOutAt: GateJson.date(json, 'CheckOutAt'),
      durationMinutes: GateJson.integerOrNull(json, 'DurationMinutes'),
      guestCount: GateJson.integer(guest, 'GuestCount', fallback: 1),
      verifiedBy: GateJson.text(json, 'VerifiedBy'),
      timeline: json == null ? const [] : _timeline(json),
    );
  }

  final String visitId;
  final String? name;
  final String? unit;
  final String? status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;
  final int guestCount;
  final String? verifiedBy;
  final List<VisitorTimelineEntry> timeline;
}

class VisitorOption {
  const VisitorOption({required this.code, required this.label});

  factory VisitorOption.fromJson(Map<String, dynamic> json) {
    final code = GateJson.text(json, 'Code') ?? '';
    return VisitorOption(
        code: code, label: GateJson.text(json, 'Label') ?? code);
  }

  final String code;
  final String label;
}

class VisitorGateOptions {
  const VisitorGateOptions({
    this.visitorTypes = const [],
    this.walkInWaitSeconds = 60,
    this.photoRequired = true,
  });

  factory VisitorGateOptions.fromJson(Map<String, dynamic>? json) {
    final wait = GateJson.integer(json, 'WalkInWaitSeconds');
    return VisitorGateOptions(
      visitorTypes: GateJson.list(json, 'VisitorTypes')
          .map(VisitorOption.fromJson)
          .where((item) => item.code.isNotEmpty)
          .toList(),
      walkInWaitSeconds: wait > 0 ? wait : 60,
      photoRequired: json == null || GateJson.flag(json, 'WalkInPhotoRequired'),
    );
  }

  final List<VisitorOption> visitorTypes;
  final int walkInWaitSeconds;
  final bool photoRequired;
}

class VisitorUnitChoice {
  const VisitorUnitChoice({
    required this.unitId,
    required this.label,
    this.residentName,
    this.accountCount = 0,
  });

  factory VisitorUnitChoice.fromJson(Map<String, dynamic> json) {
    return VisitorUnitChoice(
      unitId: GateJson.text(json, 'UnitId') ?? '',
      label: GateJson.text(json, 'Label') ?? '-',
      residentName: GateJson.text(json, 'ResidentName'),
      accountCount: GateJson.integer(json, 'AccountCount'),
    );
  }

  final String unitId;
  final String label;
  final String? residentName;
  final int accountCount;
}

class WalkInDraft {
  const WalkInDraft({
    required this.unitId,
    required this.name,
    required this.phone,
    required this.guestCount,
    required this.photoBase64,
    required this.photoMimeType,
    this.visitorType,
    this.plateNumber,
    this.purpose,
  });

  final String unitId;
  final String name;
  final String phone;
  final int guestCount;
  final String photoBase64;
  final String photoMimeType;
  final String? visitorType;
  final String? plateNumber;
  final String? purpose;

  Map<String, dynamic> toJson() => {
        'UnitId': unitId,
        'Name': name,
        'Phone': phone,
        'GuestCount': guestCount,
        'VisitorType': visitorType,
        'PlateNumber': plateNumber,
        'Purpose': purpose,
        'PhotoBase64': photoBase64,
        'PhotoMimeType': photoMimeType,
      };
}

class WalkInTicket {
  const WalkInTicket({
    required this.requestId,
    required this.name,
    this.phone,
    this.photoUrl,
    this.unitLabel,
    this.visitorType,
    this.purpose,
    this.plateNumber,
    this.guestCount = 1,
    this.requestedAt,
    this.waitSeconds = 60,
  });

  factory WalkInTicket.fromJson(Map<String, dynamic>? json) {
    final visitor = GateJson.object(json, 'Visitor');
    final vehicle = GateJson.object(json, 'Vehicle');
    final destination = GateJson.object(json, 'Destination');
    final wait = GateJson.integer(json, 'WaitSeconds');
    return WalkInTicket(
      requestId: GateJson.text(json, 'RequestId') ?? '',
      name: GateJson.text(visitor, 'Name') ?? '-',
      phone: GateJson.text(visitor, 'Phone'),
      photoUrl: GateJson.text(visitor, 'PhotoUrl'),
      unitLabel: GateJson.text(destination, 'Label'),
      visitorType: GateJson.text(json, 'VisitorType'),
      purpose: GateJson.text(json, 'Purpose'),
      plateNumber: GateJson.text(vehicle, 'PlateNumber'),
      guestCount: GateJson.integer(json, 'GuestCount', fallback: 1),
      requestedAt: GateJson.date(json, 'RequestedAt'),
      waitSeconds: wait > 0 ? wait : 60,
    );
  }

  final String requestId;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? unitLabel;
  final String? visitorType;
  final String? purpose;
  final String? plateNumber;
  final int guestCount;
  final DateTime? requestedAt;
  final int waitSeconds;
}

enum WalkInDecisionState { waiting, approved, rejected, expired }

class WalkInStatus {
  const WalkInStatus({
    required this.state,
    this.note,
    this.decidedBy,
    this.decidedAt,
    this.defaultAccess = false,
  });

  factory WalkInStatus.fromJson(Map<String, dynamic>? json) {
    final status = (GateJson.text(json, 'Status') ?? '').toUpperCase();
    final timeline =
        json == null ? const <VisitorTimelineEntry>[] : _timeline(json);
    final decision = timeline.lastWhere(
      (entry) => const {
        'WALKIN_APPROVED',
        'WALKIN_REJECTED',
        'OVERRIDE_DECISION'
      }.contains(entry.event.toUpperCase()),
      orElse: () => const VisitorTimelineEntry(event: ''),
    );
    return WalkInStatus(
      state: switch (status) {
        'ACCESS_GRANTED' => WalkInDecisionState.approved,
        'REJECTED' => WalkInDecisionState.rejected,
        'EXPIRED' => WalkInDecisionState.expired,
        _ => WalkInDecisionState.waiting,
      },
      note: GateJson.text(json, 'SecurityNote'),
      decidedBy: decision.by,
      decidedAt: decision.at,
      defaultAccess: decision.event.toUpperCase() == 'OVERRIDE_DECISION',
    );
  }

  final WalkInDecisionState state;
  final String? note;
  final String? decidedBy;
  final DateTime? decidedAt;
  final bool defaultAccess;
}
