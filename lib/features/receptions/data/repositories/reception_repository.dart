import 'package:dony/features/receptions/data/datasources/reception_remote_datasource.dart';
import 'package:dony/features/receptions/data/models/reception.dart';

class ReceptionRepository {
  ReceptionRepository(this._datasource);

  final ReceptionRemoteDatasource _datasource;

  Future<List<Reception>> getReceptions() => _datasource.fetchReceptions();

  Future<Reception> getReception(String bidId) =>
      _datasource.fetchReception(bidId);

  Future<Reception> confirm(String bidId) => _datasource.confirm(bidId);

  Future<void> decline(String bidId) => _datasource.decline(bidId);
}
