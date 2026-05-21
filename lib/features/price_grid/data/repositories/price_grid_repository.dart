import 'package:dony/features/price_grid/data/datasources/price_grid_datasource.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';

class PriceGridRepository {
  final PriceGridDatasource _datasource;

  PriceGridRepository(this._datasource);

  Future<List<PriceGridItemModel>> getItems() => _datasource.getItems();

  Future<PriceGridItemModel> addItem({
    required String label,
    required double unitPriceNet,
  }) =>
      _datasource.addItem(label: label, unitPriceNet: unitPriceNet);

  Future<PriceGridItemModel> updateItem({
    required String itemId,
    required String label,
    required double unitPriceNet,
  }) =>
      _datasource.updateItem(itemId: itemId, label: label, unitPriceNet: unitPriceNet);

  Future<void> deleteItem(String itemId) => _datasource.deleteItem(itemId);

  Future<List<PriceGridItemModel>> reorder(List<String> orderedIds) =>
      _datasource.reorder(orderedIds);
}
