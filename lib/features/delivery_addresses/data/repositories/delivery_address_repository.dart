import 'package:dony/features/delivery_addresses/data/datasources/delivery_address_datasource.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';

class DeliveryAddressRepository {
  const DeliveryAddressRepository(this._datasource);

  final DeliveryAddressDatasource _datasource;

  Future<List<DeliveryAddress>> getAll() => _datasource.getAll();
  Future<DeliveryAddress> create(Map<String, dynamic> data) => _datasource.create(data);
  Future<DeliveryAddress> update(String id, Map<String, dynamic> data) =>
      _datasource.update(id, data);
  Future<DeliveryAddress> setDefault(String id) => _datasource.setDefault(id);
  Future<void> delete(String id) => _datasource.delete(id);
}
