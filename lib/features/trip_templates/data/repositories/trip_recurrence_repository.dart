import 'package:dony/features/trip_templates/data/datasources/trip_recurrence_datasource.dart';
import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';

class TripRecurrenceRepository {
  const TripRecurrenceRepository(this._datasource);

  final TripRecurrenceDatasource _datasource;

  Future<List<TripRecurrence>> getAll() => _datasource.getAll();
  Future<TripRecurrence> create(Map<String, dynamic> data) =>
      _datasource.create(data);
  Future<TripRecurrence> update(String id, Map<String, dynamic> data) =>
      _datasource.update(id, data);
  Future<void> delete(String id) => _datasource.delete(id);
}
