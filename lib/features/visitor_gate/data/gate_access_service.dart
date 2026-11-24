import 'package:dio/dio.dart';

import 'gate_response.dart';

class GateAccess {
  const GateAccess({
    this.visitorView = false,
    this.visitorCreate = false,
    this.visitorUpdate = false,
    this.cctvView = false,
    this.cctvUpdate = false,
    this.newsCreate = false,
  });

  final bool visitorView;
  final bool visitorCreate;
  final bool visitorUpdate;
  final bool cctvView;
  final bool cctvUpdate;
  final bool newsCreate;
}

class GateAccessService {
  GateAccessService(this._dio);

  static const String visitorPage = 'FASILITAS_VISITOR';
  static const String cctvPage = 'CCTV_MONITORING';
  static const String newsUrl = '/news';

  final Dio _dio;

  Future<GateAccess> load() async {
    final body = await GateResponse.run(() => _dio.get('/RoleAccess/my-menu'));
    final pages = <String, Map<String, dynamic>>{};
    final urls = <String, Map<String, dynamic>>{};
    for (final item in GateJson.list(body, 'List')) {
      final code = GateJson.text(item, 'PageCode')?.toUpperCase();
      if (code != null) pages[code] = item;
      final url = GateJson.text(item, 'PageUrl')?.toLowerCase();
      if (url != null) urls[url] = item;
    }
    bool can(String page, String key) => GateJson.flag(pages[page], key);
    bool canUrl(String url, String key) => GateJson.flag(urls[url], key);
    return GateAccess(
      visitorView: can(visitorPage, 'CanView'),
      visitorCreate: can(visitorPage, 'CanCreate'),
      visitorUpdate: can(visitorPage, 'CanUpdate'),
      cctvView: can(cctvPage, 'CanView'),
      cctvUpdate: can(cctvPage, 'CanUpdate'),
      newsCreate: canUrl(newsUrl, 'CanView') && canUrl(newsUrl, 'CanCreate'),
    );
  }
}
