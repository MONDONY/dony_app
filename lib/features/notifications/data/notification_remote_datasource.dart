import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/data/notification_model.dart';

class NotificationRemoteDatasource {
  final ApiClient _apiClient;

  NotificationRemoteDatasource(this._apiClient);

  /// Liste historique, toutes catégories, sans agrégation.
  Future<List<NotificationModel>> fetchNotifications({
    int page = 0,
    int size = 30,
  }) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    return _content(response.data);
  }

  /// Le feed du sheet : tout sauf les annonces plateforme, les groupes non
  /// lus repliés en une ligne à partir de trois (`count`, `notificationIds`).
  Future<List<NotificationModel>> fetchFeed({
    int page = 0,
    int size = 30,
  }) async {
    final response = await _apiClient.dio.get(
      '/notifications/feed',
      queryParameters: {'page': page, 'size': size},
    );
    return _content(response.data);
  }

  /// La boîte « Annonces Yadony » : uniquement les annonces plateforme.
  Future<List<NotificationModel>> fetchAnnouncements({
    int page = 0,
    int size = 30,
  }) async {
    final response = await _apiClient.dio.get(
      '/notifications/annonces',
      queryParameters: {'page': page, 'size': size},
    );
    return _content(response.data);
  }

  /// La carte en tête de sheet : non-lus et dernière annonce.
  Future<AnnouncementsSummary> fetchAnnouncementsSummary() async {
    final response = await _apiClient.dio.get(
      '/notifications/annonces/summary',
    );
    return AnnouncementsSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Une notification seule avec son texte complet (écran de détail).
  Future<NotificationDetail> fetchDetail(String id) async {
    final response = await _apiClient.dio.get('/notifications/$id');
    return NotificationDetail.fromJson(response.data as Map<String, dynamic>);
  }

  List<NotificationModel> _content(dynamic data) {
    final content =
        ((data as Map<String, dynamic>)['content'] as List<dynamic>);
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

  /// Lit d'un coup toutes les non-lues d'un groupe (ligne agrégée du feed).
  Future<void> markGroupRead(String groupKey) async {
    await _apiClient.dio.patch(
      '/notifications/groups/read',
      queryParameters: {'groupKey': groupKey},
    );
  }

  Future<void> markAllRead() async {
    await _apiClient.dio.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _apiClient.dio.delete('/notifications/$id');
  }

  Future<void> ack(String id) async {
    await _apiClient.dio.post('/notifications/$id/ack');
  }
}
