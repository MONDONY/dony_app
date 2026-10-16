import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/maintenance/data/models/maintenance_status.dart';

/// `GET /config/maintenance` : jamais bloquée par la maintenance côté back,
/// et `exempt` dit si le compte connecté passe malgré tout.
class MaintenanceRemoteDatasource {
  MaintenanceRemoteDatasource(this._client);

  final ApiClient _client;

  Future<MaintenanceStatus> fetchStatus() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/config/maintenance',
      // Le cubit revérifie lui-même toutes les 30 s : pas de retry empilé.
      options: Options(extra: const {'skipTransientRetry': true}),
    );
    return MaintenanceStatus.fromJson(response.data ?? const {});
  }
}
