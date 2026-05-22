import 'package:dony/features/settings/data/connected_devices_datasource.dart';
import 'package:dony/features/settings/data/models/device_model.dart';

class ConnectedDevicesRepository {
  final ConnectedDevicesDatasource _datasource;
  const ConnectedDevicesRepository(this._datasource);

  Future<List<DeviceModel>> fetchDevices() => _datasource.fetchDevices();
  Future<void> revokeDevice(String deviceId) => _datasource.revokeDevice(deviceId);
  Future<void> revokeOthers() => _datasource.revokeOthers();
}
