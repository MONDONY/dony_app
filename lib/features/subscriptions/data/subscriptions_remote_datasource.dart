import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';

class SubscriptionsRemoteDatasource implements SubscriptionsRepository {
  final ApiClient _apiClient;
  SubscriptionsRemoteDatasource(this._apiClient);

  @override
  Future<List<SubscriptionItem>> getMySubscriptions() async {
    final r = await _apiClient.dio.get('/me/subscriptions');
    return (r.data as List)
        .map((j) => SubscriptionItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> subscribe(String travelerId) async {
    await _apiClient.dio.post('/travelers/$travelerId/subscribe');
  }

  @override
  Future<void> unsubscribe(String travelerId) async {
    await _apiClient.dio.delete('/travelers/$travelerId/subscribe');
  }

  @override
  Future<SubscriptionStatus> setPush(String travelerId, bool enabled) async {
    final r = await _apiClient.dio.put(
      '/travelers/$travelerId/subscribe/push',
      data: {'enabled': enabled},
    );
    return SubscriptionStatus.fromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<SubscriptionStatus> getStatus(String travelerId) async {
    final r = await _apiClient.dio.get('/travelers/$travelerId/subscription');
    return SubscriptionStatus.fromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<void> markSeen(String travelerId) async {
    await _apiClient.dio.post('/me/subscriptions/$travelerId/mark-seen');
  }

  @override
  Future<List<TravelerAnnouncement>> getTravelerAnnouncements(
    String travelerId,
  ) async {
    final r = await _apiClient.dio.get('/travelers/$travelerId/announcements');
    return (r.data as List)
        .map((j) => TravelerAnnouncement.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
