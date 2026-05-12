import 'package:dony/features/pickup_addresses/data/datasources/pickup_address_datasource.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';

class PickupAddressRepository {
  final PickupAddressDatasource _datasource;

  PickupAddressRepository(this._datasource);

  Future<List<PickupAddress>> getAll() => _datasource.getAll();

  Future<PickupAddress> create(Map<String, dynamic> data) =>
      _datasource.create(data);

  Future<PickupAddress> update(String id, Map<String, dynamic> data) =>
      _datasource.update(id, data);

  Future<PickupAddress> setDefault(String id) => _datasource.setDefault(id);

  Future<void> delete(String id) => _datasource.delete(id);
}
