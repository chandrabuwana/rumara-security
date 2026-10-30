import 'package:dio/dio.dart';

import 'gate_response.dart';
import 'visitor_gate_models.dart';

class VisitorGateRepository {
  VisitorGateRepository(this._dio);

  final Dio _dio;

  static const String defaultAccessNote =
      'Akses default tanpa persetujuan penghuni. Identitas sudah diperiksa petugas.';
  static const String cancelNote = 'Dibatalkan petugas di pos.';

  Future<VisitorSummary> summary() async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/summary', data: <String, dynamic>{}),
    );
    return VisitorSummary.fromJson(GateJson.object(body, 'Data'));
  }

  Future<List<VisitorGateItem>> inside() async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/list', data: {
        'Filter': [
          {'Field': 'kind', 'Search': 'VISIT'},
          {'Field': 'status', 'Search': 'INSIDE'},
        ],
        'Sort': {'Field': 'date', 'Type': 1},
        'Start': 1,
        'Length': 200,
      }),
    );
    return GateJson.list(body, 'List')
        .map(VisitorGateItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<VisitorScanResult> scan(String code) async {
    final value = code.trim();
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/scan', data: {'Code': value}),
    );
    return VisitorScanResult.fromJson(
        GateJson.object(body, 'Data') ?? {}, value);
  }

  Future<VisitorVisitRecord> checkInCode(String code, int guestCount) async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/check-in', data: {
        'Code': code,
        'GuestCount': guestCount,
      }),
    );
    return VisitorVisitRecord.fromJson(GateJson.object(body, 'Data'));
  }

  Future<VisitorVisitRecord> checkInWalkIn(
      String requestId, int guestCount) async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/check-in', data: {
        'WalkInRequestId': requestId,
        'GuestCount': guestCount,
      }),
    );
    return VisitorVisitRecord.fromJson(GateJson.object(body, 'Data'));
  }

  Future<VisitorVisitRecord> checkOut(String visitId) async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/check-out', data: {'VisitId': visitId}),
    );
    return VisitorVisitRecord.fromJson(GateJson.object(body, 'Data'));
  }

  Future<VisitorGateOptions> options() async {
    final body = await GateResponse.run(
      () => _dio.get('/Visitor/security-options'),
    );
    return VisitorGateOptions.fromJson(GateJson.object(body, 'Data'));
  }

  Future<List<VisitorUnitChoice>> units(String query) async {
    final body = await GateResponse.run(
      () => _dio.get('/Visitor/units', queryParameters: {'q': query.trim()}),
    );
    return GateJson.asList(GateJson.value(body, 'Data'))
        .map(VisitorUnitChoice.fromJson)
        .where((item) => item.unitId.isNotEmpty)
        .toList();
  }

  Future<WalkInTicket> createWalkIn(WalkInDraft draft) async {
    final body = await GateResponse.run(
      () => _dio.post('/Visitor/walk-in', data: draft.toJson()),
    );
    return WalkInTicket.fromJson(GateJson.object(body, 'Data'));
  }

  Future<WalkInStatus> walkInStatus(String requestId) async {
    final body = await GateResponse.run(
      () => _dio.get('/Visitor/get/$requestId'),
    );
    return WalkInStatus.fromJson(GateJson.object(body, 'Data'));
  }

  Future<void> decideWalkIn(
    String requestId, {
    required bool approve,
    required String note,
  }) async {
    await GateResponse.run(
      () => _dio.post('/Visitor/decision', data: {
        'RequestId': requestId,
        'Decision': approve ? 'APPROVE' : 'REJECT',
        'Note': note,
      }),
    );
  }
}
