import 'package:dio/dio.dart';

import '../../visitor_gate/data/gate_response.dart';

class InfoCategory {
  const InfoCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory InfoCategory.fromJson(Map<String, dynamic> json) {
    return InfoCategory(
      id: GateJson.integer(json, 'Id'),
      name: GateJson.text(json, 'Name') ?? '-',
    );
  }
}

class InfoDraft {
  const InfoDraft({
    required this.categoryId,
    required this.title,
    required this.content,
    this.photoBase64,
    this.startDate,
    this.endDate,
  });

  final int categoryId;
  final String title;
  final String content;
  final String? photoBase64;
  final DateTime? startDate;
  final DateTime? endDate;
}

class InfoCreateRepository {
  InfoCreateRepository(this._dio);

  final Dio _dio;

  Future<List<InfoCategory>> categories() async {
    final body = await GateResponse.run(
      () => _dio.post('/NewsCategory/list', data: {
        'Filter': [
          {'Field': 'active', 'Search': 'true'},
        ],
        'Sort': {'Field': 'name', 'Type': 0},
        'Start': 1,
        'Length': 100,
      }),
    );
    return GateJson.list(body, 'List')
        .map(InfoCategory.fromJson)
        .where((item) => item.id > 0)
        .toList();
  }

  Future<void> submit(InfoDraft draft) async {
    final photo = draft.photoBase64;
    await GateResponse.run(
      () => _dio.post('/News/add', data: {
        'Title': draft.title,
        'Content': draft.content,
        'IdCategory': draft.categoryId,
        if (photo != null && photo.isNotEmpty)
          'FotoUrl': 'data:image/jpeg;base64,$photo',
        if (draft.startDate != null)
          'StartDate': draft.startDate!.toIso8601String(),
        if (draft.endDate != null) 'EndDate': draft.endDate!.toIso8601String(),
      }),
    );
  }
}
