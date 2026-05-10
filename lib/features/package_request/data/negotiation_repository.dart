import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';

class NegotiationRepository {
  const NegotiationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NegotiationThread> start({
    required String packageRequestId,
    required double proposedPriceEur,
    required DateTime travelerTravelDate,
    required double travelerAvailableKg,
    String? travelerAnnouncementId,
    String? body,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations',
      data: {
        'packageRequestId': packageRequestId,
        'proposedPriceEur': proposedPriceEur,
        'travelerTravelDate': travelerTravelDate.toIso8601String().substring(0, 10),
        'travelerAvailableKg': travelerAvailableKg,
        if (travelerAnnouncementId != null) 'travelerAnnouncementId': travelerAnnouncementId,
        if (body != null) 'body': body,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<List<NegotiationThread>> findMine() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/negotiations/me');
    return (response.data ?? <dynamic>[])
        .map((e) => NegotiationThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NegotiationThread> getById(String id) async {
    final response =
        await _apiClient.dio.get<Map<String, dynamic>>('/negotiations/$id');
    return NegotiationThread.fromJson(response.data!);
  }

  Future<NegotiationThread> counter(
    String id, {
    required double proposedPriceEur,
    String? body,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/counter',
      data: {
        'proposedPriceEur': proposedPriceEur,
        if (body != null) 'body': body,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<NegotiationThread> accept(String id, {String? body}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/accept',
      data: {if (body != null) 'body': body},
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<void> reject(String id, {String? reason}) async {
    await _apiClient.dio.post<void>(
      '/negotiations/$id/reject',
      data: {if (reason != null) 'reason': reason},
    );
  }
}
