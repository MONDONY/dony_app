import 'package:dony/core/network/api_client.dart';

class NotificationPrefsDatasource {
  final ApiClient _apiClient;
  const NotificationPrefsDatasource(this._apiClient);

  Future<void> syncPrefs(Map<String, bool> prefs) async {
    await _apiClient.dio.put(
      '/notifications/preferences',
      data: {
        'pushActivityBids':         prefs['push_activity_bids'] ?? true,
        'pushActivityNegotiations': prefs['push_activity_negotiations'] ?? true,
        'pushMessages':             prefs['push_messages'] ?? true,
        'pushTripReminder':         prefs['push_trip_reminder'] ?? true,
        'pushPromo':                prefs['push_promo'] ?? false,
      },
    );
  }
}
