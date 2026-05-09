import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';

class TrackingRepository {
  final ApiClient _apiClient;

  TrackingRepository(this._apiClient);

  Future<QrCodeModel> getQrCode(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/qr-code');
    return QrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TrackingSearchModel> searchByTrackingNumber(String number) async {
    final response = await _apiClient.dio
        .get('/tracking/search', queryParameters: {'number': number});
    return TrackingSearchModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TrackingEventModel> postScan({
    required String bidId,
    required String eventType,
    double? gpsLat,
    double? gpsLon,
    String? photoUrl,
    DateTime? offlineTimestamp,
  }) async {
    final response = await _apiClient.dio.post('/tracking/events', data: {
      'bidId': bidId,
      'eventType': eventType,
      if (gpsLat != null) 'gpsLat': gpsLat,
      if (gpsLon != null) 'gpsLon': gpsLon,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (offlineTimestamp != null) 'offlineTimestamp': offlineTimestamp.toUtc().toIso8601String(),
    });
    return TrackingEventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TrackingEventModel>> getEvents(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/events');
    final list = response.data as List<dynamic>;
    return list.map((e) => TrackingEventModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> uploadTrackingPhoto(String bidId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'scan.jpg'),
      'bidId': bidId,
    });
    final response = await _apiClient.dio.post('/storage/upload/tracking', data: formData);
    return (response.data as Map<String, dynamic>)['key'] as String;
  }

  Future<({String? code, DateTime? expiresAt})> getConfirmationCode(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/confirmation-code');
    final data = response.data as Map<String, dynamic>;
    final rawExpiry = data['expiresAt'] as String?;
    return (
      code: data['confirmationCode'] as String?,
      expiresAt: rawExpiry != null ? DateTime.parse(rawExpiry) : null,
    );
  }

  Future<({String? code, DateTime? expiresAt})> refreshCode(String bidId) async {
    final response = await _apiClient.dio.post('/tracking/$bidId/refresh-code');
    final data = response.data as Map<String, dynamic>;
    final rawExpiry = data['expiresAt'] as String?;
    return (
      code: data['confirmationCode'] as String?,
      expiresAt: rawExpiry != null ? DateTime.parse(rawExpiry) : null,
    );
  }

  Future<TrackingEventModel> confirmDelivery({
    required String bidId,
    required String code,
  }) async {
    final response = await _apiClient.dio.post(
      '/tracking/$bidId/confirm-delivery',
      data: {'confirmationCode': code},
    );
    return TrackingEventModel.fromJson(response.data as Map<String, dynamic>);
  }
}
