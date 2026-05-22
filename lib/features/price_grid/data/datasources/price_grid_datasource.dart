import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';

class PriceGridDatasource {
  final ApiClient _apiClient;

  PriceGridDatasource(this._apiClient);

  Future<List<PriceGridItemModel>> getItems() async {
    final response = await _apiClient.dio.get('/travelers/me/price-grid');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Expected List from API');
    }
    return data
        .map((e) => PriceGridItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PriceGridItemModel> addItem({
    required String label,
    required double unitPriceNet,
  }) async {
    final response = await _apiClient.dio.post(
      '/travelers/me/price-grid/items',
      data: {'label': label, 'unitPriceNet': unitPriceNet},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected Map from API');
    }
    return PriceGridItemModel.fromJson(data);
  }

  Future<PriceGridItemModel> updateItem({
    required String itemId,
    required String label,
    required double unitPriceNet,
  }) async {
    final response = await _apiClient.dio.put(
      '/travelers/me/price-grid/items/$itemId',
      data: {'label': label, 'unitPriceNet': unitPriceNet},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected Map from API');
    }
    return PriceGridItemModel.fromJson(data);
  }

  Future<void> deleteItem(String itemId) =>
      _apiClient.dio.delete('/travelers/me/price-grid/items/$itemId');

  Future<List<PriceGridItemModel>> reorder(List<String> orderedIds) async {
    final response = await _apiClient.dio.put(
      '/travelers/me/price-grid/reorder',
      data: orderedIds,
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Expected List from API');
    }
    return data
        .map((e) => PriceGridItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
