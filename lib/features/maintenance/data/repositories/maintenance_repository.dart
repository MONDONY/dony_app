import 'package:dony/features/maintenance/data/datasources/maintenance_live_datasource.dart';
import 'package:dony/features/maintenance/data/datasources/maintenance_remote_datasource.dart';
import 'package:dony/features/maintenance/data/models/maintenance_status.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._remote, this._live);

  final MaintenanceRemoteDatasource _remote;
  final MaintenanceLiveDatasource _live;

  /// État faisant foi (exemption comprise).
  Future<MaintenanceStatus> fetchStatus() => _remote.fetchStatus();

  /// Signal temps réel : à chaque émission, relire [fetchStatus].
  Stream<bool> watchEnabled() => _live.watchEnabled();
}
