import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/notification_prefs_dto.dart';

class NotificationPrefsRemoteDatasource {
  final ApiClient _api;
  const NotificationPrefsRemoteDatasource(this._api);

  Future<NotificationPrefsDto> fetchPrefs() async {
    final resp = await _api.dio.get('/notifications/preferences');
    return NotificationPrefsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> updatePrefs(NotificationPrefsDto dto) async {
    await _api.dio.put('/notifications/preferences', data: dto.toJson());
  }
}
