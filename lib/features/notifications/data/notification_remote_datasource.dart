import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/notification_model.dart';

class NotificationRemoteDatasource {
  final ApiClient _apiClient;

  NotificationRemoteDatasource(this._apiClient);

  Future<List<NotificationModel>> fetchNotifications({int page = 0, int size = 30}) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    final content = (response.data['content'] as List<dynamic>);
    return content
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final response = await _apiClient.dio.get('/notifications/unread-count');
    return (response.data['count'] as int?) ?? 0;
  }

  Future<void> markRead(String id) async {
    await _apiClient.dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _apiClient.dio.patch('/notifications/read-all');
  }
}
