import 'package:dio/dio.dart';

class GateApiException implements Exception {
  const GateApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

class GateJson {
  const GateJson._();

  static dynamic value(Map<String, dynamic>? map, String key) {
    if (map == null) return null;
    if (map.containsKey(key)) return map[key];
    final camel = key[0].toLowerCase() + key.substring(1);
    return map[camel];
  }

  static String? text(Map<String, dynamic>? map, String key) {
    final raw = value(map, key);
    if (raw == null) return null;
    final result = raw.toString().trim();
    return result.isEmpty ? null : result;
  }

  static int integer(Map<String, dynamic>? map, String key,
      {int fallback = 0}) {
    final raw = value(map, key);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static int? integerOrNull(Map<String, dynamic>? map, String key) {
    final raw = value(map, key);
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static bool flag(Map<String, dynamic>? map, String key) {
    final raw = value(map, key);
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == 'true';
  }

  static DateTime? date(Map<String, dynamic>? map, String key) {
    final raw = text(map, key);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static Map<String, dynamic>? object(Map<String, dynamic>? map, String key) {
    final raw = value(map, key);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static List<Map<String, dynamic>> list(
      Map<String, dynamic>? map, String key) {
    final raw = value(map, key);
    return asList(raw);
  }

  static List<Map<String, dynamic>> asList(dynamic raw) {
    if (raw is Map) {
      final nested = raw['Items'] ?? raw['items'] ?? raw['List'] ?? raw['list'];
      return asList(nested);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class GateResponse {
  const GateResponse._();

  static Future<Map<String, dynamic>> run(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return _unwrap(await call());
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) return _unwrap(response);
      throw const GateApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  static Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final raw = response.data;
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final message = GateJson.text(map, 'Message');
    if (status == 401) {
      throw GateApiException(
        'Sesi Anda berakhir, silakan masuk ulang.',
        statusCode: status,
      );
    }
    if (status == 403) {
      throw GateApiException(
        message ?? 'Anda tidak memiliki akses ke fitur ini.',
        statusCode: status,
      );
    }
    if (status >= 400 || GateJson.value(map, 'Succeeded') == false) {
      throw GateApiException(
        message ?? 'Permintaan gagal diproses.',
        statusCode: status,
      );
    }
    return map;
  }
}
