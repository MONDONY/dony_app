import 'package:dony/features/trip_templates/data/datasources/trip_template_datasource.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';

class TripTemplateRepository {
  const TripTemplateRepository(this._datasource);

  final TripTemplateDatasource _datasource;

  Future<List<TripTemplate>> getAll() => _datasource.getAll();
  Future<TripTemplate> create(Map<String, dynamic> data) =>
      _datasource.create(data);
  Future<TripTemplate> update(String id, Map<String, dynamic> data) =>
      _datasource.update(id, data);
  Future<void> delete(String id) => _datasource.delete(id);
}
