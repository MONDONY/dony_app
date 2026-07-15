import 'package:dony/features/disputes/data/datasources/dispute_remote_datasource.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

class DisputeRepository {
  final DisputeRemoteDatasource _remote;
  DisputeRepository(this._remote);

  Future<List<DisputeModel>> getMyDisputes() => _remote.getMyDisputes();
}
