import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';

class ContentCategoryDatasource {
  final ApiClient _client;

  ContentCategoryDatasource(this._client);

  Future<List<ContentCategory>> getContentCategories() async {
    final response = await _client.dio.get('/config/content-categories');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => ContentCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
