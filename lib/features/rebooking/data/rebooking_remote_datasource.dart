import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/rebooking/data/rebooking_repository.dart';

class RebookingRemoteDatasource implements RebookingRepository {
  final ApiClient _apiClient;

  RebookingRemoteDatasource(this._apiClient);

  @override
  Future<List<PastBookingItem>> getPastBookings() async {
    final response = await _apiClient.dio.get('/senders/me/past-bookings');
    return (response.data as List)
        .map((j) => PastBookingItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RebookResult> rebook(String pastBidId) async {
    final response = await _apiClient.dio.post('/bookings/rebook/$pastBidId');
    return RebookResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> subscribeToTraveler(String travelerId) async {
    await _apiClient.dio.post('/travelers/$travelerId/notify-when-available');
  }
}
