import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';

class PriceGridDatasource {
  final ApiClient _apiClient;

  PriceGridDatasource(this._apiClient);

  Future<List<PriceGridItemModel>> getItems() async {
    final response = await _apiClient.dio.get('/travelers/me/price-grid');
    return (response.data as List)
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
    return PriceGridItemModel.fromJson(response.data as Map<String, dynamic>);
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
    return PriceGridItemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteItem(String itemId) =>
      _apiClient.dio.delete('/travelers/me/price-grid/items/$itemId');

  Future<List<PriceGridItemModel>> reorder(List<String> orderedIds) async {
    final response = await _apiClient.dio.put(
      '/travelers/me/price-grid/reorder',
      data: orderedIds,
    );
    return (response.data as List)
        .map((e) => PriceGridItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
