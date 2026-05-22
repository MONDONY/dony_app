import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/device_model.dart';

class ConnectedDevicesDatasource {
  final ApiClient _apiClient;
  const ConnectedDevicesDatasource(this._apiClient);

  Future<List<DeviceModel>> fetchDevices() async {
    final response = await _apiClient.dio.get('/users/me/devices');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeDevice(String deviceId) async {
    await _apiClient.dio.delete('/users/me/devices/$deviceId');
  }

  Future<void> revokeOthers() async {
    await _apiClient.dio.delete('/users/me/devices/others');
  }
}
