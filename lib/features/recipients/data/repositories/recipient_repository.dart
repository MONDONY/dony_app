import 'package:dony/features/recipients/data/datasources/recipient_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';

class RecipientRepository {
  final RecipientDatasource _datasource;

  RecipientRepository(this._datasource);

  Future<List<Recipient>> getAll() => _datasource.getAll();

  Future<Recipient> create(Map<String, dynamic> data) =>
      _datasource.create(data);

  Future<Recipient> update(String id, Map<String, dynamic> data) =>
      _datasource.update(id, data);

  Future<void> delete(String id) => _datasource.delete(id);
}
