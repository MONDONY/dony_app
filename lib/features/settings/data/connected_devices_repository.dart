import 'package:dony/features/settings/data/connected_devices_datasource.dart';
import 'package:dony/features/settings/data/models/device_model.dart';

class ConnectedDevicesRepository {
  final ConnectedDevicesDatasource _datasource;
  const ConnectedDevicesRepository(this._datasource);

  Future<List<DeviceModel>> fetchDevices() => _datasource.fetchDevices();
  Future<void> revokeDevice(String deviceId) =>
      _datasource.revokeDevice(deviceId);
  Future<void> revokeOthers() => _datasource.revokeOthers();

  /// Vérifie si l'appareil courant est encore enregistré côté serveur.
  /// Retourne `true` s'il est encore enregistré OU en cas d'erreur (fail-safe :
  /// on ne déconnecte jamais sur une simple erreur réseau).
  /// Retourne `false` UNIQUEMENT si le serveur répond et qu'aucun appareil
  /// n'a isCurrent == true (= cet appareil a été révoqué).
  Future<bool> isCurrentDeviceRegistered() async {
    try {
      final devices = await _datasource.fetchDevices();
      return devices.any((d) => d.isCurrent);
    } catch (_) {
      return true; // fail-safe
    }
  }
}
